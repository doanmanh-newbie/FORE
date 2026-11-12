# Repository Hygiene and Maintainability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove avoidable repository bloat and reduce the risk of accidental config exposure while improving the maintainability of the largest active Dart modules.

**Architecture:** Stop bundling unused owner dashboard SVGs while preserving the files, untrack the ignored local `env.json` without deleting the developer's copy, and split only active oversized modules behind compatible exports.

**Tech Stack:** Flutter/Dart, Git, `pubspec.yaml`, `flutter analyze`, Flutter tests.

**Spec:** `docs/superpowers/specs/2026-11-11-fore-audit-remediation-design.md`

## Global Constraints

- Preserve all existing working-tree changes, especially the modified legacy menu screen and untracked assets; do not reset/revert/delete or commit.
- Leave all source SVG files on disk; only remove unused asset declarations from the app bundle.
- Keep local `env.json` contents untouched; it is ignored and must not be printed.
- The only deliberate index mutation in this plan is untracking `env.json`; do not stage unrelated files.
- Split files without changing public imports or runtime behavior.

## Review Focus

- An asset may be referenced indirectly; search Dart, tests, and pubspec before removing its bundle declaration.
- A public class may be consumed outside its current folder; verify all imports before moving declarations.
- Splitting a model file can break extension/type exports; add compatibility exports and run all analyzer/tests.
- Git index and local `env.json` must be checked independently after untracking.
- Current user edits must be inspected before touching files with existing diffs.

---

### Task 1: Remove unused assets from the Flutter bundle

**Files:**
- Modify: `pubspec.yaml`
- Test: `test/assets_configuration_test.dart` (or existing configuration test)

**Interfaces:**
- No application API changes; bundle must exclude `assets/owner_dashboard/file1/` through `file10/` if there are no source references.

- [ ] Search all `lib/`, `test/`, and `pubspec.yaml` references to the asset paths and assert no active use exists.
- [ ] Remove only the ten unused asset declarations and assert the files remain on disk.
- [ ] Run `flutter pub get`, `flutter analyze`, and relevant widget tests; compare web build asset output size only if a build is already part of normal local verification.

### Task 2: Untrack local env.json without removing it

**Files:**
- Modify Git index only: `env.json`
- Verify: `.gitignore`

**Interfaces:**
- Local `env.json` remains present and ignored; Git no longer tracks it; `.env.example` remains the documented safe template.

- [ ] Verify only key names (never values) in `env.json`, check `.gitignore`, and confirm the file is tracked before action.
- [ ] Remove only `env.json` from the index using cached removal; do not stage any other path.
- [ ] Verify the local file still exists, `git check-ignore env.json` succeeds, and `git ls-files --error-unmatch env.json` fails as expected.

### Task 3: Split active oversized inventory/menu files compatibly

**Files:**
- Modify: `lib/features/inventory/domain/kho_models.dart`
- Create: focused inventory model files within `lib/features/inventory/domain/`
- Modify: `lib/features/owner/menu/menu_extras_views.dart`
- Create: focused menu view files within `lib/features/owner/menu/`
- Test: affected inventory/menu tests; add import/export compatibility assertions if needed

**Interfaces:**
- Preserve existing import paths through export-only facade files until all call sites are migrated; preserve public type names and constructors.
- Do not touch the modified, unreferenced legacy `owner_menu_management_screen.dart` in this task.

- [ ] List public declarations and all call sites for the selected active files; compare their current diffs before moving code.
- [ ] Move one cohesive group at a time, keeping behavior and error handling unchanged; retain facade exports.
- [ ] Run focused tests after each split, then `flutter analyze` and `flutter test`.

## Handoff Limits

- No source asset files are deleted.
- The existing legacy owner menu implementation is preserved even if unreferenced; remove only after a separate review confirms no local work would be lost.
