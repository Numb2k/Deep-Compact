# Session Handoff — todo-api-29ab6c34
Written: 2026-01-15
Archive: ~/.claude/session-state/todo-api-29ab6c34/archive/ — older snapshots; grep here when asked about older work not covered below

## Mission
Build a small REST API for todo lists (CRUD, auth, pagination). Goal now: finish pagination and add tests.

## Key Decisions
- SQLite (better-sqlite3) instead of Postgres: single-file deploy, fewer than 1k users expected.
- Session token in an httpOnly cookie, not localStorage (XSS exposure).
- Soft delete with a `deleted_at` column; hard delete only from an admin script.
- Rejected: GraphQL. Three resources do not justify the extra layer.

## Files & Code State
- `~/code/todo-api/src/server.ts` — Express app, mounts /todos and /auth.
- `~/code/todo-api/src/db.ts` — better-sqlite3 setup, migrations run on boot.
- `~/code/todo-api/src/auth.ts` — login/logout, cookie handling.
- `~/code/todo-api/src/routes.ts` — NEW, cursor pagination for GET /todos.
- `~/code/todo-api/tests/todos.test.ts` — CRUD tests, pagination tests still missing.

## Commands & Environment
- `npm i better-sqlite3 express` done; Node 22.
- `npm test` passes 9/9.

## Errors & Resolutions
- `SQLITE_BUSY` under parallel tests -> enabled WAL mode in `db.ts`.
- Cookie not sent in tests -> supertest agent keeps cookies, use one agent per test file.

## Open Threads
- Pagination tests (next/prev cursor edge cases).
- Rate limiting: undecided (ask the user).

## User Constraints & Preferences
- No new dependencies without asking.
- Short answers, code first.

## Immediate Next Step
Write pagination tests in `tests/todos.test.ts` for empty page, last page, and an invalid cursor.

## Git State
Branch: main
Last commit: c59bb040c493a4d27617e66aed60826dc2f6b343 Add todo CRUD endpoints
Upstream: none (no remote tracking branch)
Working tree (porcelain, first 200 lines):
?? src/routes.ts
