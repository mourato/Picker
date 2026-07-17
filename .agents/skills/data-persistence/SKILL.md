---
name: data-persistence
description: Palette and font-list persistence for Picker — UserDefaults JSON keys, caps, duplicate rules, and --demo isolation.
---

# Data Persistence

Use when changing saved colors, saved fonts, UserDefaults keys, migration, or demo seeding.

## Invariants

- Colors: JSON under `picker.pickedColors.v1`, capped at **60**; consecutive duplicate samples via `add` **update** rather than append. Multi-pick loupe sessions use `appendAlways` (1:1 with each click) and restore a pre-session snapshot via `replaceAll` on cancel.
- Fonts: JSON under `picker.pickedFonts.v1`, capped at **60**; re-grabbing a family **moves it to the front**.
- `--demo` sets `persistenceEnabled = false` on both stores so seeded data never touches real user data.
- Prefer additive schema evolution (new fields with defaults) over silent key renames; bump the `.vN` suffix when breaking.

## Checklist

- Does a normal run still round-trip palette/fonts across relaunch?
- Does `--demo` leave real UserDefaults unchanged?
- Are caps and duplicate/reorder rules preserved?
- Is decoding resilient to partially corrupted JSON (fail soft, do not crash the panel)?

## Validation

- Run without `--demo`, add items, quit, relaunch.
- Run with `--demo`, quit, relaunch normal — confirm real stores untouched.

## Related

- UI binding → `macos-app-engineering`
- Tests for encode/decode → `testing-xctest`
