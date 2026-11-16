# Database Integrity and Drift Checks Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the database integrity and install-drift gaps found in the static audit without altering existing business data.

**Architecture:** Strengthen inventory tenant relationships with composite same-shop foreign keys, index the audit feed access pattern, and compare a normalized schema-only catalog representation for generated rebuild versus install modules.

**Tech Stack:** PostgreSQL, SQL shell scripts, `psql`/local test database, Flutter repository RPC conventions.

**Spec:** `docs/superpowers/specs/2026-11-11-fore-audit-remediation-design.md`

## Global Constraints

- Preserve all existing working-tree changes and data; do not reset, revert, stage unrelated files, or commit.
- Do not execute SQL against the remote Supabase project.
- Constraints must be idempotent for a clean rebuild and must not change stored quantities/statuses.
- Do not mask schema drift by comparing unstable object order or environment-specific owner metadata.

## Review Focus

- Existing data can violate newly added tenant constraints; preflight must report offending rows and avoid destructive cleanup.
- Two records can share UUIDs across shops; tests must prove cross-shop references are rejected.
- Audit history ordering uses the same timestamp and ID ordering as the index.
- Drift checks must detect changes in policies, grants, triggers, constraints, indexes, tables, and function definitions.
- A clean generated rebuild and the install modules must normalize to the same schema result.

---

### Task 1: Add audit-feed index and inventory tenant constraints

**Files:**
- Modify: `database/01_foundation.sql`
- Modify: `database/07_inventory.sql`
- Test: `database/tests/41_inventory_tenant_constraints.sql`

**Interfaces:**
- Audit index: `audit_log(shop_id, at DESC, id DESC)`.
- Add parent unique keys as needed and composite FKs for shop-scoped relations, including order lines, stock lots, cost events, stocktakes, stocktake lines, actor/shop pairs and lot/order-line links.

- [ ] Write SQL assertions showing valid same-shop links succeed and cross-shop links fail for each new relation.
- [ ] Run assertions against a disposable local test database and confirm the cross-shop cases fail before adding constraints.
- [ ] Add preflight queries that raise a clear exception listing constraint name and conflicting row IDs when existing data violates a proposed FK.
- [ ] Add idempotent unique keys/FKs and audit index to source SQL without updating business records.
- [ ] Run SQL tests and clean rebuild; inspect `EXPLAIN` for the audit-feed predicate/order to ensure the index is usable.

### Task 2: Compare complete schema catalog in install drift check

**Files:**
- Modify: `tool/check_install_drift.sh`
- Modify: related SQL normalization/helper scripts under `tool/` only if required
- Test: `database/tests/42_install_drift_check.sh`

**Interfaces:**
- Drift checker exits `0` only when source install modules and generated rebuild have equivalent normalized schema catalog; exits nonzero and reports first category/object differences otherwise.
- Compared categories: tables/columns, constraints, indexes, RLS flags/policies, grants, triggers, functions.

- [ ] Add a test fixture where each catalog category differs and assert the checker reports nonzero with the category/object name.
- [ ] Add the no-drift fixture and assert exit code `0`.
- [ ] Replace function-only hash comparison with deterministic schema-only dumps/catalog queries that exclude data and unstable ownership metadata.
- [ ] Run `bash tool/check_install_drift.sh` on a clean local disposable database, then rerun the drift test script.

## Handoff Limits

- The check is only as complete as the local PostgreSQL client/catalog version; remote production schema is not queried.
- If preflight detects inconsistent historical data, report the rows and leave them unchanged for explicit remediation.
