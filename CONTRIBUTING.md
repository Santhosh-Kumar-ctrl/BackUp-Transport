# Contributing to Transit

Thanks for helping build the college transport platform. This guide takes you from a fresh
clone to a merged pull request.

The rules for how the code is organised (module ownership, events, who may write which table)
are in [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md). Read that too before your first change:
it's short, and PRs that break those rules get sent back.

## Before you start
- **Look for an existing issue** for what you want to do, or open one. For anything bigger than
  a small fix, say how you plan to do it before you write code. It saves rework.
- **Find the module it belongs to.** Each module has an owner and a README; the table in the
  [main README](README.md#modules-p0) lists them. Changes that touch another person's module
  need their review.

## 1. Get the code running
**Team members** with write access: clone the repo.
```powershell
git clone https://github.com/Santhosh-Kumar-ctrl/Transport-System-Final.git
cd Transport-System-Final
```
**Everyone else:** fork the repo on GitHub, clone your fork, and add this repo as `upstream`
so you can stay up to date:
```powershell
git clone https://github.com/<your-username>/Transport-System-Final.git
cd Transport-System-Final
git remote add upstream https://github.com/Santhosh-Kumar-ctrl/Transport-System-Final.git
```

Then follow [Quick start in the README](README.md#quick-start) to set up Postgres, the
backend and the app. You need Docker Desktop, Python 3.11+ and Flutter 3.35+. When you're
done, http://localhost:8000/health should answer and you should be able to log in to the app.
[RUN.md](RUN.md) shows how to see live tracking working with the bus simulator.

## 2. Create a branch
Never work directly on `main`. Start from an up-to-date `main` and name the branch after the
module and the change:
```powershell
git checkout main
git pull                    # forks: git pull upstream main
git checkout -b boarding/manual-override
```
Format: `<module>/<short-description>`, lowercase with hyphens. One branch per feature or fix.

## 3. Make your change
**Where code goes.** Each module has a backend folder and a frontend folder:
```
backend/app/modules/<module>/     models, schemas, service, router, tests, README.md, DEVLOG.md
frontend/lib/modules/<module>/    data (API calls), state, screens, widgets
```
Shared code lives in `backend/app/core/`, `frontend/lib/core/` and `frontend/lib/design/`.
Change shared code only when several modules need it, and say so in your PR.

**Database changes.** If you change a model, create a migration and review what it generated
before applying it:
```powershell
cd backend
.venv\Scripts\activate
alembic revision --autogenerate -m "<module>: <change>"
alembic upgrade head
```
Also update [docs/DATABASE.md](docs/DATABASE.md) to match.

**Screens.** Read [frontend/lib/design/README.md](frontend/lib/design/README.md) first, and build
with the design-system widgets and `TransitColors`, not stock Material styling.

**Docs.** Every change updates its module's docs:
- `README.md`: what the module does *now*. Update it if endpoints, events, tables or settings
  changed.
- `DEVLOG.md`: add an entry at the top saying what changed, the date, and **why**.

**Settings.** New settings go in `backend/app/core/config.py` with a safe default. If someone
running the project would need to change it, add it to `.env.example` too.

## 4. Test it
Run all of these before you open a PR. Docker Desktop must be running.
```powershell
# Backend
cd backend
.venv\Scripts\python -m pytest -q                    # everything
.venv\Scripts\python -m pytest app/modules/trips -q  # just one module while you work

# Frontend
cd ..\frontend
flutter analyze                                       # must say "No issues found"
flutter test
dart format --line-length 120 lib test                # the code style used in this repo
```
The backend tests use a separate `transit_test` database, so they never touch your dev data.

**Add tests with your change.** Backend tests sit next to the code in
`backend/app/modules/<module>/tests/` and build their data through the real API with the
`world` fixture in `backend/app/conftest.py`. Copy the style of the existing tests there. A bug
fix should come with a test that fails without the fix.

**If you touched trips, tracking, boarding or attendance,** also run the end-to-end simulation.
It drives a bus along each route and checks attendance afterwards. See
[Check the whole flow end to end](RUN.md#check-the-whole-flow-end-to-end).

**If you changed a screen,** run the app and try the change as each role it affects (student,
driver, admin). The demo logins are in the README.

## 5. Commit
Start each commit message with the module, followed by what the commit does:
```
trips: auto-close trips left running past their service day
boarding: let drivers board a student by roll number
```
Small commits that each do one thing are easier to review than one big one.

**Never commit:**
- `backend/.env` or any file with real passwords, keys or tokens. Use `.env.example` with
  placeholder values instead.
- `backend/.venv/`, `frontend/build/` or other generated files. `.gitignore` already covers
  these; check `git status` before you commit anyway.

## 6. Open a pull request
```powershell
git push -u origin boarding/manual-override
```
Then open a pull request into `main` on GitHub. In the description, say what changed and why,
how you tested it, and link the issue (e.g. `Closes #12`). Add screenshots for screen changes.

Before asking for review, check:
- [ ] backend tests pass and `flutter analyze` is clean
- [ ] new tests cover the change
- [ ] the module's `DEVLOG.md` has a new entry, and its `README.md` is up to date
- [ ] a migration is included if models changed, and `docs/DATABASE.md` matches
- [ ] no secrets or generated files are in the diff

**Review.** Ask someone from a *different* module to review: boundary mistakes are easier to
spot from outside. Answer review comments with new commits rather than force-pushing, so the
reviewer can see what changed. A maintainer merges once the review is approved.

## Reporting bugs
Open an issue with:
- what you did, step by step, and which account you were logged in as;
- what you expected, and what happened instead;
- any error message, the API log from the terminal running `uvicorn`, or a screenshot;
- whether it was in the browser or on Android.

If the bug is a security problem (for example, a way to see another student's data or to log in
without a password), don't open a public issue. Contact the maintainer directly instead.

## Questions
Ask in the issue you're working on, or open a new one. If you're unsure which module something
belongs to, ask before you start: that's the most common source of rework.
