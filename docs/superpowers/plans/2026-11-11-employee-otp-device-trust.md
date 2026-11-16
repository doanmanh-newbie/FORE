# Employee OTP and Trusted Device Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace deterministic employee credentials with verified email/SMS OTP and require a one-time OTP again when the trusted device expires after 60 days or changes.

**Architecture:** Keep owner email/password authentication unchanged. Add OTP request/verify methods to the existing auth repository, persist a random device secret with platform secure storage, send it through a Supabase client header, and enforce the matching 60-day hash record in database helpers before employee data access.

**Tech Stack:** Flutter/Dart, `supabase_flutter`, `flutter_secure_storage`, PostgreSQL/Supabase, Flutter unit/widget tests and SQL tests.

**Spec:** `docs/superpowers/specs/2026-11-11-fore-audit-remediation-design.md`

## Global Constraints

- Preserve all existing working-tree changes; do not reset, revert, stage unrelated files, or commit.
- Do not delete Auth users, memberships, shifts, or business history.
- Do not run SQL against the remote Supabase project.
- A device is trusted for exactly 60 days; expiry or missing local secret requires OTP.
- Owners retain the existing email/password flow; only employee authorization is gated by device trust.
- Never persist the device secret in PostgreSQL, logs, or user metadata; persist only its SHA-256 digest server-side.
- Existing synthetic phone identities are not verified contacts; explain the owner-led re-invite transition without deleting old records.

## Review Focus

- An unverified email/phone or unknown account must not receive a session or reveal account existence; test login with `shouldCreateUser: false` and generic UI feedback.
- Invalid, expired, resent, or rate-limited OTP must leave the user unauthenticated and expose a retryable localized state.
- A valid OTP must register a device-bound trust secret, while password-only staff sessions cannot register one.
- A missing, wrong, expired, or other-session device secret must block employee RPC/RLS access; an owner session must continue to work.
- Secure-storage failure or browser profile change must fail closed into OTP recovery without leaking the secret.

---

### Task 1: Replace deterministic employee credential API with OTP contracts

**Files:**
- Modify: `lib/features/auth/domain/auth_repository.dart`
- Modify: `lib/features/auth/application/staff_login_controller.dart`
- Modify: `lib/features/auth/application/staff_register_controller.dart`
- Test: `test/staff_auth_test.dart`
- Modify: `test/support/fake_auth_repository.dart`

**Interfaces:**
- Produce `Future<void> requestStaffOtp(StaffContact contact, {required bool createUser, String? fullName, DateTime? birthDate})` and `Future<AuthUser> verifyStaffOtp(StaffContact contact, String token)` on `AuthRepository`.
- Controllers expose `otpRequested`, `verifyOtp(String token)`, and `resendOtp()`; an initial submit requests a code and never reports sign-in success.
- Remove `signInStaff`, deterministic credential methods, and demo-contact metadata from the production interface.

- [ ] Write tests that login requests OTP without creating accounts; registration requests OTP with account creation; verification success advances the session; invalid input and errors remain visible.
- [ ] Run `flutter test test/staff_auth_test.dart` and confirm the new contract tests fail before implementation.
- [ ] Implement the controller/repository interface transition and update the fake repository to model challenge and verification states.
- [ ] Run `flutter test test/staff_auth_test.dart` and confirm the contract tests pass.

### Task 2: Implement Supabase OTP, device secret storage, and session gate

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/features/auth/data/supabase_auth_repository.dart`
- Create: `lib/features/auth/data/staff_device_trust_store.dart`
- Modify: `lib/main.dart`
- Modify: `lib/features/auth/application/session_controller.dart`
- Modify: `lib/features/auth/presentation/staff_login_panel.dart`
- Modify: `lib/features/auth/presentation/staff_register_screen.dart`
- Test: `test/features/auth/staff_device_trust_store_test.dart`
- Test: `test/session_controller_test.dart`
- Test: `test/staff_auth_test.dart`

**Interfaces:**
- `StaffDeviceTrustStore` provides `Future<String?> readSecret(String userId)`, `Future<String> createSecret(String userId)`, and `Future<void> clearSecret(String userId)`.
- `AuthRepository.validateStaffDeviceTrust()` returns `true` only when server accepts the local proof; `SessionController` validates staff sessions before fetching tenant data and signs out locally on a missing/expired/mismatched proof.
- `SupabaseAuthRepository` requests/validates OTP and registers current session trust only after verification; staff challenge data (full name/date of birth) is retained only for the duration of the screen flow.

- [ ] Add tests for secure-store persistence, account separation, cleared storage, OTP expiry/error/resend states, and the 60-day-expired/new-device session route.
- [ ] Run the focused tests and verify failure before implementation.
- [ ] Implement email/phone `signInWithOtp` and `verifyOTP`; login uses `shouldCreateUser: false`, registration uses `true`, and registration metadata never fabricates verified contacts.
- [ ] Generate device secrets with `Random.secure`, store them in `flutter_secure_storage`, and apply `x-fore-device-token` to `SupabaseClient` before protected data calls.
- [ ] Implement startup validation and 60-day trust registration; if storage or validation fails, clear the staff session and return to OTP flow. Keep owner password login unaffected.
- [ ] Add the OTP-entry/loading/resend/countdown/error states to the existing staff screens with accessible labels and disable duplicate submissions.
- [ ] Run focused tests, then `flutter analyze` and `flutter test`.

### Task 3: Enforce device trust and verified contacts in SQL

**Files:**
- Modify: `database/04_membership_sessions.sql`
- Create or modify: `database/tests/41_staff_device_trust.sql`
- Modify: `README.md` or the existing Supabase setup guide (select one canonical guide after checking current content)

**Interfaces:**
- Add `register_staff_device(p_secret text)` and `validate_staff_device()` server functions; persist `(user_id, session_id, secret_hash, expires_at)` and never return the hash.
- Replace `_my_verified_contacts()` to use only Supabase Auth confirmed `email` / `phone`; remove `demo_email` and `demo_phone` matching.
- Employee authorization helper must require a matching unexpired device row; owner paths must retain existing behavior.

- [ ] Add SQL assertions for OTP-authenticated registration, password-only rejection, correct-device access, wrong/missing/expired device rejection, session mismatch, and owner access.
- [ ] Run the SQL tests against a local disposable/test database and record the exact command/result; do not target remote Supabase.
- [ ] Implement narrowly granted RPCs, RLS/helper enforcement and Auth-method checks based on verified JWT claims; use `digest(p_secret, 'sha256')` for the stored value.
- [ ] Document required Supabase email token-template and SMS provider setup, plus the non-destructive re-invite path for existing synthetic phone accounts.
- [ ] Re-run SQL tests and `tool/check_install_drift.sh` against the local rebuild.

## Handoff Limits

- Real OTP delivery depends on Supabase email/SMS configuration and cannot be asserted from local unit tests.
- This plan does not run a remote migration or mutate production/test project data.
