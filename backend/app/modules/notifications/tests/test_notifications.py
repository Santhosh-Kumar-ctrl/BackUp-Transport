from app.core.roles import Role


async def test_inbox_unread_and_mark_read(world):
    route = await world.route()
    student = await world.user(Role.STUDENT)
    await world.allocate(student, route, 0)
    await world.delete(f"/allocations/students/{student['id']}")

    inbox = await world.inbox(student)
    assert [n["type"] for n in inbox] == ["AllocationEnded", "StudentAllocated"]
    assert (await world.get("/notifications/unread-count", who=student)).json() == {"unread": 2}

    left = (await world.post(f"/notifications/{inbox[0]['id']}/read", who=student)).json()
    assert left == {"unread": 1}
    await world.post(f"/notifications/{inbox[0]['id']}/read", who=student, expect=404)
    assert (await world.post("/notifications/read-all", who=student)).json() == {"unread": 0}


async def test_users_only_see_their_own(world):
    route = await world.route()
    a, b = await world.user(Role.STUDENT), await world.user(Role.STUDENT)
    await world.allocate(a, route, 0)
    assert await world.inbox(b) == []
    note = (await world.inbox(a))[0]
    await world.post(f"/notifications/{note['id']}/read", who=b, expect=404)


async def test_trip_start_tells_allocated_students(world):
    route = await world.route()
    driver = await world.user(Role.DRIVER)
    sched = await world.schedule(route, await world.bus(), driver)
    student = await world.user(Role.STUDENT)
    await world.allocate(student, route, 1)
    trip = await world.todays_trip(sched)
    await world.post(f"/trips/{trip['id']}/start", who=driver)
    started = next(n for n in await world.inbox(student) if n["type"] == "TripStarted")
    assert "Scheduled at your stop" in started["body"]
