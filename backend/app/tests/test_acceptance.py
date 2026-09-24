"""Day-30 acceptance scenario (P0 subset), end to end through the API.

1. Administrator assigns student and route
2. Driver starts trip
3. Student boards (scans the driver's QR) and attendance records
4. Delay is simulated
5. System detects impact and notifies users
6. Administrator sees it on the live board (corrective recommendation = Team B's agent, P1)
"""

from app.core.roles import Role


async def test_day30_acceptance(world):
    # 1. admin sets up the route and assigns students
    route = await world.route(n_stops=4, gap_min=10, code="14")
    bus = await world.bus(capacity=40)
    driver = await world.user(Role.DRIVER, "Kumar")
    sched = await world.schedule(route, bus, driver)
    rider = await world.user(Role.STUDENT, "Divya")
    waiting = await world.user(Role.STUDENT, "Arjun")
    await world.allocate(rider, route, 0)
    await world.allocate(waiting, route, 2)

    # 2. driver starts the trip
    trip = await world.todays_trip(sched)
    trip = (await world.post(f"/trips/{trip['id']}/start", who=driver)).json()
    assert trip["status"] == "in_progress"

    # 3. rider scans the QR on the driver's phone
    receipt = (await world.board(rider, trip["id"], driver)).json()
    assert receipt["allocation_match"] and receipt["route_code"] == "14"
    roster = (await world.get(f"/boarding/trips/{trip['id']}/roster", who=driver)).json()
    assert roster["boarded_count"] == 1

    # 4. delay simulated: bus reaches stop 2 twelve minutes late
    stop2 = trip["stops"][1]
    await world.post(f"/trips/{trip['id']}/stops/2/arrive", {"arrived_at": world.at(stop2["scheduled_at"], 12)})

    # 5. the waiting student and admin are notified; the rider is not
    waiting_inbox = await world.inbox(waiting)
    assert any(n["type"] == "TripDelayed" and "12 min late" in n["title"] for n in waiting_inbox)
    assert not any(n["type"] == "TripDelayed" for n in await world.inbox(rider))
    assert any(n["type"] == "TripDelayed" for n in await world.inbox(world.admin))

    # 6. admin live board reflects the delay; student home shows the new expected time
    board = (await world.get("/dashboard/admin")).json()
    row = next(r for r in board["board"] if r["trip_id"] == trip["id"])
    assert row["delay_min"] == 12 and row["boarded"] == 1
    student_home = (await world.get("/dashboard/student", who=waiting)).json()
    assert student_home["trips"][0]["delay_min"] == 12

    # trip ends -> attendance finalised; history has the whole story
    await world.post(f"/trips/{trip['id']}/end", who=driver)
    att = {a["student_id"]: a["status"] for a in (await world.get("/history/attendance")).json()}
    assert att == {rider["id"]: "present", waiting["id"]: "absent"}
    types = [e["type"] for e in (await world.get(f"/history/trips/{trip['id']}/timeline")).json()]
    assert types.index("TripStarted") < types.index("StudentBoarded") < types.index("TripDelayed") \
        < types.index("TripEnded") < types.index("AttendanceFinalized")
