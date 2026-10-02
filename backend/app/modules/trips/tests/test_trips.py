from datetime import datetime, time, timedelta

from sqlalchemy import update

from app.core.db import SessionLocal
from app.core.roles import Role
from app.core.timeutil import local_tz, now_utc
from app.modules.trips.models import Trip, TripStopEvent
from app.modules.trips.service import close_stale_trips


def _mins(a: str, b: str) -> int:
    return round((datetime.fromisoformat(a) - datetime.fromisoformat(b)).total_seconds() / 60)


async def test_generate_is_idempotent_and_plans_stop_times(world):
    route = await world.route(n_stops=4, gap_min=10)
    bus = await world.bus()
    driver = await world.user(Role.DRIVER)
    sched = await world.schedule(route, bus, driver, departure=time(7, 30))

    first = (await world.post("/trips/generate", {})).json()
    again = (await world.post("/trips/generate", {})).json()
    assert first["created"] == 1 and again["created"] == 0 and again["existing"] == 1

    trip = await world.todays_trip(sched)
    stops = trip["stops"]
    assert [s["stop_name"] for s in stops][-1] == "Campus"
    assert [_mins(s["scheduled_at"], trip["scheduled_departure"]) for s in stops] == [0, 10, 20, 30]


async def test_drop_trip_runs_route_in_reverse(world):
    route = await world.route(n_stops=3, gap_min=15)
    sched = await world.schedule(route, await world.bus(), await world.user(Role.DRIVER),
                                 direction="drop", departure=time(16, 30))
    trip = await world.todays_trip(sched)
    assert trip["stops"][0]["stop_name"] == "Campus"
    assert [_mins(s["scheduled_at"], trip["scheduled_departure"]) for s in trip["stops"]] == [0, 15, 30]


async def test_driver_workflow_start_arrive_end(world):
    w = await world.running_trip(n_stops=3)
    trip, driver = w["trip"], w["driver"]
    assert trip["status"] == "in_progress"
    assert trip["stops"][0]["arrived_at"] is not None  # leaving stop 1 = start
    assert trip["next_stop"]["sequence"] == 2

    trip = (await world.post(f"/trips/{trip['id']}/stops/2/arrive", who=driver)).json()
    assert trip["next_stop"]["sequence"] == 3
    again = await world.post(f"/trips/{trip['id']}/stops/2/arrive", who=driver, expect=409)
    assert again.json()["code"] == "already_arrived"

    trip = (await world.post(f"/trips/{trip['id']}/end", who=driver)).json()
    assert trip["status"] == "completed"
    assert trip["stops"][-1]["arrived_at"] is not None


async def test_only_assigned_driver_operates(world):
    route = await world.route()
    sched = await world.schedule(route, await world.bus(), await world.user(Role.DRIVER))
    trip = await world.todays_trip(sched)
    other = await world.user(Role.DRIVER)
    await world.post(f"/trips/{trip['id']}/start", who=other, expect=403)


async def test_out_of_order_and_state_rules(world):
    w = await world.running_trip(n_stops=4)
    tid, driver = w["trip"]["id"], w["driver"]
    await world.post(f"/trips/{tid}/stops/3/arrive", who=driver)  # skipping stop 2 is allowed
    r = await world.post(f"/trips/{tid}/stops/2/arrive", who=driver, expect=422)
    assert r.json()["code"] == "out_of_order"
    r = await world.post(f"/trips/{tid}/start", who=driver, expect=422)
    assert r.json()["code"] == "bad_trip_state"


async def test_driver_cannot_run_two_trips(world):
    route = await world.route()
    bus1, bus2 = await world.bus(), await world.bus()
    driver = await world.user(Role.DRIVER)
    s1 = await world.schedule(route, bus1, driver)
    s2 = await world.schedule(route, bus2, driver, departure=time(23, 0))
    t1, t2 = await world.todays_trip(s1), await world.todays_trip(s2)
    await world.post(f"/trips/{t1['id']}/start", who=driver)
    r = await world.post(f"/trips/{t2['id']}/start", who=driver, expect=409)
    assert r.json()["code"] == "already_running"


async def test_simulated_timestamps_only_for_admin(world):
    route = await world.route()
    driver = await world.user(Role.DRIVER)
    sched = await world.schedule(route, await world.bus(), driver)
    trip = await world.todays_trip(sched)
    late = world.at(trip["scheduled_departure"], 12)
    await world.post(f"/trips/{trip['id']}/start", {"started_at": late}, who=driver, expect=403)
    started = (await world.post(f"/trips/{trip['id']}/start", {"started_at": late})).json()
    assert started["current_delay_min"] == 12


async def test_cancel_trip(world):
    route = await world.route()
    sched = await world.schedule(route, await world.bus(), await world.user(Role.DRIVER))
    trip = await world.todays_trip(sched)
    r = (await world.post(f"/trips/{trip['id']}/cancel", {"reason": "Bus breakdown"})).json()
    assert r["status"] == "cancelled" and r["cancel_reason"] == "Bus breakdown"


async def test_schedule_requires_driver_role(world):
    route = await world.route()
    student = await world.user(Role.STUDENT)
    body = {"route_id": route["id"], "bus_id": (await world.bus())["id"], "driver_id": student["id"],
            "direction": "pickup", "departure_time": "07:30:00"}
    r = await world.post("/schedules", body, expect=422)
    assert r.json()["code"] == "wrong_role"


async def _age_trip(trip_id: int, hours: int) -> None:
    """Move a trip and all its times `hours` into the past, as if it ran on an earlier day."""
    h = timedelta(hours=hours)
    async with SessionLocal() as s:
        await s.execute(update(Trip).where(Trip.id == trip_id).values(
            service_date=(now_utc() - h).astimezone(local_tz()).date(),
            scheduled_departure=Trip.scheduled_departure - h, started_at=Trip.started_at - h))
        await s.execute(update(TripStopEvent).where(TripStopEvent.trip_id == trip_id).values(
            scheduled_at=TripStopEvent.scheduled_at - h, arrived_at=TripStopEvent.arrived_at - h))
        await s.commit()


async def test_trip_left_running_on_an_earlier_day_is_closed_and_unblocks_the_driver(world):
    w = await world.running_trip(n_stops=3)
    old, driver = w["trip"], w["driver"]
    await world.post(f"/trips/{old['id']}/stops/2/arrive", who=driver)
    await _age_trip(old["id"], 48)  # the driver never tapped End, two days ago

    s2 = await world.schedule(w["route"], w["bus"], driver, departure=time(23, 59))
    new = await world.todays_trip(s2)
    started = (await world.post(f"/trips/{new['id']}/start", who=driver)).json()
    assert started["status"] == "in_progress"

    closed = (await world.get(f"/trips/{old['id']}")).json()
    assert closed["status"] == "completed"
    assert closed["ended_at"] == closed["stops"][1]["arrived_at"]  # ends at its last activity
    assert closed["stops"][-1]["arrived_at"] is None  # the terminus is not made up
    ev = (await world.get("/history/events", type=["TripEnded"], aggregate_id=old["id"])).json()
    assert ev[0]["payload"]["auto_closed"] is True and ev[0]["payload"]["skipped_stops"] == [3]


async def test_late_run_crossing_midnight_is_not_closed(world):
    w = await world.running_trip(n_stops=3)
    tid = w["trip"]["id"]
    await _age_trip(tid, 24)
    await world.post(f"/trips/{tid}/stops/2/arrive", who=w["driver"])  # still checking in stops
    async with SessionLocal() as s:
        assert await close_stale_trips(s) == []
    assert (await world.get(f"/trips/{tid}")).json()["status"] == "in_progress"
