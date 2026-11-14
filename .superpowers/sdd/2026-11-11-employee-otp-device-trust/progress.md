# SDD ledger — plan: docs/superpowers/plans/2026-11-11-employee-otp-device-trust.md

Pre-flight: auth contract producer/consumer is AuthRepository → SupabaseAuthRepository/FakeAuthRepository → staff controllers/screens; all implementations/callers identified by rg. Database task consumes x-fore-device-token set by repository and validates via helper used by _require_staff/app_staff_id.
Ruling: Stay on existing `luong-dang-chu-quan` working tree — it is not main and contains extensive user changes that an isolated clean worktree would omit; preserve all existing changes and avoid worktree creation.
Ruling: SDD helper scripts require execution denied by this Windows harness and `task-done` is absent; track task/test evidence in this ledger manually without altering helper scripts.

Verification update (2026-11-11):
- Fixed Flutter Material/ink assertion for the member revocation confirmation checkbox in `lib/features/settings/presentation/team_screens.dart`.
- Focused test passed: `flutter test test/features/settings/team_hub_screen_test.dart --reporter expanded` (exit 0).
- Full suite passed: `flutter test --reporter expanded` (389 tests, exit 0).
- `flutter analyze --no-pub` completed with exit 1 because 48 analyzer INFO diagnostics remain (no errors or warnings reported); these are mostly pre-existing style/deprecation/context diagnostics across inventory/menu/settings and tests.
- SQL integration and source-vs-rebuild drift checks remain unexecuted locally: PostgreSQL/Docker CLI was unavailable earlier; no remote SQL was executed.
- Follow-up environment check: Docker CLI exists but `docker info` cannot connect to the Docker Desktop Linux engine; host `psql`, `pg_dump`, and Supabase CLI are absent. Database install/test scripts therefore remain unverified here.
