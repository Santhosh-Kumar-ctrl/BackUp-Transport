# core: shared infrastructure

Not a business module. Everything every module needs, and nothing module-specific.

| File | What it gives you |
|---|---|
| `config.py` | `settings` (env vars / `backend/.env`): DB URLs, JWT, thresholds, timezone |
| `db.py` | async `engine`, `SessionLocal`, `get_session` FastAPI dependency |
| `models.py` | `Base` (with constraint naming convention), `TimestampMixin`, `str_enum()` |
| `roles.py` | `Role` enum: student, driver, admin, security, parent |
| `security.py` | bcrypt hashing, `sign()/verify()` JWTs with a `typ` claim, access/refresh tokens |
| `deps.py` | `current_principal`, `require_roles(...)` → `Principal(id, role)` decoded from the token (no DB hit) |
| `errors.py` | `NotFound`, `Conflict`, `Forbidden`, `Unauthorized`, `InvalidState` → JSON `{detail, code}` |
| `events.py` | Domain event bus + `domain_events` table (see below) |
| `realtime.py` | WebSocket hub at `/ws?token=…` (user / role / topic channels) |
| `tasks.py` | `tasks.every(seconds, name, fn)` periodic jobs, started by the app lifespan |
| `timeutil.py` | `now_utc()`, `today_local()`, `local_to_utc(date, time)`, `minutes_between()` |

## Event bus contract
```python
await events.publish(session, "TripStarted", {...}, aggregate=("trip", trip.id), actor_id=p.id)
await session.commit()   # row written to domain_events; subscribers run AFTER commit
```
- The payload is normalised to JSON (datetimes → ISO strings) **before** subscribers see it,
  so handlers read exactly what history reads.
- Rolled-back transactions dispatch nothing.
- Each handler runs in its own task and opens its own `SessionLocal()`. A failing handler is
  logged and never affects the publisher or other handlers.
- `await events.drain()` waits for all handler cascades (used by tests).

## WebSocket protocol
```
connect   ws://host:8000/ws?token=<access token>
send      {"action":"subscribe","topic":"route:3"}   {"action":"ping"}
receive   {"type":"notification"|"ops"|"boarding"|"pong", "data":{...}}
```
In-memory, single process. To scale to several workers, back `Hub` with Redis pub/sub.

## Timezone
Schedules are college-local wall-clock times (`TIMEZONE`, default `Asia/Kolkata`).
All timestamps are stored as UTC `timestamptz`.
