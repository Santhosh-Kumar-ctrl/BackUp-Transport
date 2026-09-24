# <Module name>

> One sentence: what this module is responsible for.

| | |
|---|---|
| **Owner** | <name> |
| **Backend** | `backend/app/modules/<name>/` |
| **Frontend** | `frontend/lib/modules/<name>/` |
| **Status** | planned / in progress / done |

## Responsibilities
- What it does
- What it deliberately does **not** do (and which module does)

## Data model
| Table | Column | Type | Notes |
|---|---|---|---|

## API
| Method | Path | Role | Purpose |
|---|---|---|---|

Request/response shapes are in `schemas.py` and at `/docs` (OpenAPI) when the API runs.

## Events
**Emits**

| Event | When | Payload keys |
|---|---|---|

**Consumes**

| Event | Why |
|---|---|

## Public service API (for other modules)
Functions other modules may call from `service.py`.

## Frontend screens
| Screen | Role | File |
|---|---|---|

## How to test
```bash
cd backend && .venv/Scripts/python -m pytest app/modules/<name> -q
```

## Extension notes (P1 / Team B)
