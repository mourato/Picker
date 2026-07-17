---
name: testing-xctest
description: XCTest guidance for Picker — color math, store encode/decode, and FontLoader routing when a test target exists.
---

# Testing (XCTest)

Use when adding or changing automated tests. The upstream package currently has **no** test target — verify by build + manual runs until tests are introduced.

## When Adding Tests

- Prefer pure logic first: YIQ/contrast helpers, HEX/RGB/HSL conversions, store duplicate/cap/reorder rules, Find URL routing.
- Keep UI/AppKit lifecycle (status item, event tap, AX) as manual checks unless a seam is introduced.
- Use fakes for `UserDefaults` / file URL registration boundaries so `--demo` semantics stay testable.
- Mark UI-touching tests `@MainActor` when they construct views or main-actor types.

## Structure

- Mirror source names under a future `Tests/PickerTests/` (or package test target) once added.
- One behavior per test name; assert observable outcomes, not private implementation details.

## Until a Test Target Exists

- Document manual verification in the PR for touched flows.
- Do not claim merge-ready automated coverage that is not wired in `Package.swift`.

## Related

- Persistence rules → `data-persistence`
- Delivery gates → `delivery-workflow`
