# Contributing

## How the code is split
Each business module lives in **two mirrored folders**, and one person owns both:

```
backend/app/modules/<module>/     FastAPI: models, schemas, service, router, tests, README, DEVLOG
frontend/lib/modules/<module>/    Flutter: data (API calls), state, screens, widgets
```

`backend/app/main.py` and `frontend/lib/app.dart` are the only files that know the
full module list. Everything shared lives in `backend/app/core/` and `frontend/lib/core/`
plus `frontend/lib/design/` (the design system).

## Module boundary rules
1. **Only write your own tables.** To *change* another module's data, call its
   `service` (e.g. allocation calls `trips_service.route_seat_capacity`, boarding calls
   `alloc_service.get_active`). Importing another module's `models` is allowed for
   **read-only** joins and enums (e.g. `TripStatus`). Never `session.add()` or mutate
   another module's rows. Never import another module's `router`.
2. **React to other modules through events.** Publish with
   `await events.publish(session, "Thing Happened", {...})`. Subscribe in your
   module's `register(app)`. Handlers open their own `SessionLocal()`.
3. **Services never import FastAPI.** They raise `app.core.errors` exceptions.
   Routers are thin: validate, call the service, commit.
4. **Every table belongs to exactly one module.** Other modules reference it by
   FK (string `"table.id"`) and read it through that module's service.
5. **Routers commit, services flush.** That keeps multi-step operations atomic.

## Adding a module
1. Copy `docs/MODULE_TEMPLATE/*` into the new backend module folder.
2. Create `models.py / schemas.py / service.py / router.py / __init__.py` (export `router`, optional `register`).
3. Add the module to `MODULES` in `backend/app/main.py` and its models to `backend/app/db_models.py`.
4. `alembic revision --autogenerate -m "<module>: <change>"` → review → `alembic upgrade head`.
5. Add the frontend folder and wire its screens into the role shell in `frontend/lib/app.dart`.

## Branches & PRs
- Branch names: `<module>/<short-description>`, e.g. `boarding/manual-override`.
- One PR per feature. A PR must include:
  - [ ] tests for the service logic (`pytest app/modules/<module>`)
  - [ ] a new entry at the top of the module's `DEVLOG.md`
  - [ ] README updated if endpoints/events/tables changed
  - [ ] a migration if models changed
  - [ ] `flutter analyze` clean for frontend changes
- Get a review from one person in **another** module. Boundary mistakes are easier to spot from outside.

## Documentation rules
- `README.md` = the module's current reference (what it is *now*).
- `DEVLOG.md` = the history (what changed, when, and **why**). Newest first.
- Write the DEVLOG entry when you finish the work, not at the end of the sprint.

## Design rules (frontend)
Read `frontend/lib/design/README.md` before building screens. Short version: use the
design-system widgets (`RouteBadge`, `LineDiagram`, `DepartureRow`, `SeatBlocks`,
`StatusPlate`, `SignageHeader`), use only colours from `TransitColors`, and add no
rounded shadowed cards, gradients or stock Material look.
