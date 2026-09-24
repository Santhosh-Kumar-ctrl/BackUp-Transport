# auth: dev log

## 2026-09-24: Flutter screens
**Built**
- Login screen (sign-blue station sign + route-colour band), session persisted in shared_preferences,
  JWT refresh-on-401 in the Dio client, role-guarded routing (`app.dart`), admin People screen
  (filter by role, search, add person, deactivate).

**Decisions (and why)**
- **Router redirect is the single role guard**, so every role stays inside its own area.
- **Security staff reuse the admin shell** with only Live board / Reports / Alerts visible. Their
  backend permissions are read-only, so write screens would only 403.
- Tokens live in shared_preferences (localStorage on web). Move to flutter_secure_storage on Android
  before production.

## 2026-09-24: P0 auth module
**Built**
- `users` + `student_profiles` + `driver_profiles`, JWT login/refresh/me, admin user CRUD.
- `core/deps.py` `require_roles()` used by every other module.

**Decisions (and why)**
- **No DB hit per request.** The access token carries `sub` + `role`, which keeps every request cheap.
  Trade-off: deactivation takes effect when the access token expires; refresh is blocked immediately.
- **Profiles as separate 1:1 tables**, not nullable columns on `users`. That keeps role-specific
  fields out of the way and lets Team B add e.g. a parent profile without a wide table.
- **Enums stored as VARCHAR + CHECK** (`str_enum`), not native PG enums, because adding a role
  later is a one-line migration instead of `ALTER TYPE`.
- **Emails lower-cased on write and login**, so `Priya@College.edu` and `priya@college.edu` are one account.
- **`.test` emails are rejected** by `email-validator` (reserved TLD). Tests use `college.edu`.
- Both profile relationships are always assigned on create (even `None`). Otherwise reading
  `user.student` on a fresh object triggers an async lazy-load error.

**Issues / next**
- Password reset is admin-only (PATCH password). Self-service reset needs an email channel (P1).
