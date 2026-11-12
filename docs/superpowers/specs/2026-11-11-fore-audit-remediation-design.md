# Fore audit remediation design

## Intent

Complete the actionable findings from the 2026-11-11 static audit and make employee sign-in match the owner's requested flow: verify once with OTP, trust that device for 60 days, and require OTP on a different device/browser. Keep tenant data and the existing Supabase project; do not reset or execute SQL against the remote project.

## Goals

- Remove the deterministic employee password login and stop matching invitations from unverified user metadata.
- Require a verified email OTP or phone SMS OTP for employee authentication.
- Keep an authenticated device trusted for 60 days; after expiry or on a new device/browser, require another OTP.
- Enforce trusted-device validity at the database boundary, not only by hiding routes in Flutter.
- Close the schema and tooling findings: same-shop foreign keys for inventory relations, audit log index, and full schema drift comparison.
- Stop bundling unused dashboard SVGs and split the worst oversized source files without changing behavior.
- Preserve all unrelated working-tree changes and all business data.

## Non-goals

- No reset, seed, or remote database execution.
- No migration/deletion of Auth users by automation.
- No React rewrite or new server service; retain Flutter + Supabase.
- No full visual redesign in this remediation.

## Approaches considered

1. Keep demo login only in debug builds and use verified email/password for production. Smallest, but phone-only staff cannot use the released app.
2. OTP authentication with a per-device trust record and 60-day expiry. This matches the requested experience and supports both email and phone. It requires email OTP/SMS provider setup in Supabase.
3. OTP on every launch or request. Simpler to enforce but contradicts the requested two-month remembered-device behavior and creates unnecessary friction.

**Selected: approach 2**, with a device-bound random secret stored locally and only its hash stored server-side. Every authenticated database request carries the device proof; database helpers reject missing, expired, or mismatched proof. On OTP verification the server registers the current Supabase session for 60 days. Owners retain their existing login flow; employee sessions are gated.

## Authentication and trusted-device flow

1. Employee enters verified email or phone. Login requests OTP with account creation disabled; registration may create an account and store name/date-of-birth metadata without storing an unverified contact alias.
2. Email OTP uses a code template; phone OTP uses SMS. The employee enters the code and the app calls Supabase OTP verification.
3. The app generates a random device secret and stores it with the platform secure-storage mechanism. It sends the secret over TLS to a narrowly scoped RPC; the database checks the JWT authentication method, current user and session, stores only a SHA-256 hash, and sets expiry to `now() + 60 days`.
4. On startup, the app loads the device secret and sets a Supabase client header before any authenticated data request. A server RPC validates user + session + device-secret hash + expiry. If validation fails, the app signs out that local session and returns to OTP login.
5. Database authorization helpers used by RLS and RPCs reject an employee session without a valid device record. A new device has no secret, so it cannot read/write tenant data until it completes OTP.
6. Owners continue to authenticate with their existing email/password flow. The device-trust requirement applies to `staff.role = 'staff'` only.

The trust secret is not a substitute for OTP: it is issued only after OTP verification and expires after 60 days. If secure storage is unavailable or cleared, the expected recovery is another OTP. Web requires HTTPS (localhost is supported for development). A copied full browser profile or a compromised device remains outside the guarantee; no browser application can protect secrets from same-origin malicious script execution.

## Existing account transition

- Do not delete users or memberships automatically.
- Existing email accounts can use OTP only if the mailbox is real and the user can verify it.
- Old phone-only demo accounts use synthetic email identities and cannot prove their phone number. The owner must deactivate the old demo membership, invite the employee's real phone/email, and have the employee register/verify again. Keep the old rows and history intact.
- Provide this migration instruction in the app/setup guide; do not silently treat old `demo_phone` / `demo_email` metadata as verified.

## Database and tooling changes

- Add a trusted-device table and narrowly granted RPCs to the existing session/auth module. Add an authorization helper and wire it into employee membership/RLS checks. Hash the device secret in PostgreSQL; never store it in plaintext.
- Restrict trusted-device registration to a JWT whose Auth Methods Reference indicates OTP/sign-up verification; reject password-only employee sessions.
- In `database/07_inventory.sql`, add idempotent same-shop composite constraints for order lines, stock lots, cost events, stocktakes, actors, and their parent records. Add required parent `(shop_id,id)` unique keys where missing. Do not change stored quantities or statuses.
- In `database/01_foundation.sql`, add the `(shop_id, at DESC, id DESC)` audit-log index used by `audit_feed`.
- Expand `tool/check_install_drift.sh` to compare schema-only dumps/catalog definitions, including tables, policies/RLS, grants, triggers, constraints, indexes and functions between source modules and the generated rebuild.
- Remove unused owner-dashboard asset directories from `pubspec.yaml`; leave the files on disk.
- Split the largest inventory/menu model and view files into focused files while preserving public imports. Keep the currently modified, unreferenced legacy owner menu screen until its local diff is reviewed, so unrelated user work is not discarded.
- Stop tracking `env.json` while leaving the developer's working file in place; keep `.env.example`/a safe template as the shareable configuration path. This requires a staged deletion in Git because Git already tracks the ignored file; do not commit it.

## UI and performance

- Add OTP-entry, resend/countdown, error, loading, expired-device and recovery states to the existing staff login/register screens using existing Flutter design components.
- Keep existing skeleton, error and retry states in the owner and inventory screens.
- Remove unused bundled assets; do not add a React layer. Re-render and bundle-size claims require Flutter build measurement, not React tooling.

## Verification

- Unit/widget tests: OTP request/verify states, invalid/expired code, retry/resend, persistence for a trusted device, expiry at 60 days, and new-device/no-secret routing.
- SQL tests: valid session + valid device can access; missing/wrong/expired device cannot; password-only registration cannot create trust; same-shop foreign keys reject cross-shop references.
- Run `flutter analyze`, `flutter test`, SQL module tests and the expanded drift checker against local test databases.
- Do not claim real Supabase end-to-end success until the project has Email OTP enabled with a suitable mail configuration and Phone OTP enabled with an SMS provider. Do not run any migration against the remote project.

## Calls left to the builder

- Use the current Supabase/Dart packages and existing repository/controller/widget patterns.
- Keep the user's chosen OTP and 60-day behavior exact.
- Do not stage, commit, reset, or revert unrelated changes. The `env.json` untrack is the one intentional staged Git change required by this design.
