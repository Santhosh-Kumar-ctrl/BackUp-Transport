from app.core.roles import Role


async def test_login_me_and_refresh(world, client):
    student = await world.user(Role.STUDENT, "Sam Student")
    me = (await world.get("/auth/me", who=student)).json()
    assert me["full_name"] == "Sam Student"
    assert me["student"]["roll_no"].startswith("R")

    login = (await client.post("/auth/login", json={"email": student["email"], "password": "password123"})).json()
    refreshed = await client.post("/auth/refresh", json={"refresh_token": login["refresh_token"]})
    assert refreshed.status_code == 200
    assert refreshed.json()["user"]["id"] == student["id"]


async def test_bad_password_and_wrong_token_type(world, client):
    student = await world.user(Role.STUDENT)
    r = await client.post("/auth/login", json={"email": student["email"], "password": "nope-nope"})
    assert r.status_code == 401 and r.json()["code"] == "bad_credentials"
    # a refresh token must not work as an access token
    login = (await client.post("/auth/login", json={"email": student["email"], "password": "password123"})).json()
    r = await client.get("/auth/me", headers={"Authorization": f"Bearer {login['refresh_token']}"})
    assert r.status_code == 401


async def test_admin_creates_users_with_profiles(world):
    r = await world.post("/users", {"email": "new@college.edu", "password": "password123",
                                    "full_name": "New Student", "role": "student"}, expect=422)
    assert "student profile is required" in r.text

    created = (await world.post("/users", {
        "email": "New@College.edu", "password": "password123", "full_name": "New Student",
        "role": "student", "student": {"roll_no": "21CS001", "department": "CSE", "year": 3},
    }, expect=201)).json()
    assert created["email"] == "new@college.edu"

    dup = await world.post("/users", {
        "email": "other@college.edu", "password": "password123", "full_name": "Dup",
        "role": "student", "student": {"roll_no": "21CS001"},
    }, expect=409)
    assert dup.json()["code"] == "roll_no_taken"

    students = (await world.get("/users", role="student", q="21cs")).json()
    assert [u["id"] for u in students] == [created["id"]]


async def test_only_admin_manages_users(world):
    driver = await world.user(Role.DRIVER)
    await world.get("/users", who=driver, expect=403)


async def test_deactivated_user_cannot_log_in(world, client):
    student = await world.user(Role.STUDENT)
    r = await client.patch(f"/users/{student['id']}", json={"is_active": False}, headers=world.admin["headers"])
    assert r.status_code == 200
    r = await client.post("/auth/login", json={"email": student["email"], "password": "password123"})
    assert r.status_code == 401 and r.json()["code"] == "inactive"
