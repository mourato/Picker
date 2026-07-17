---
name: swift-conventions
description: Swift coding conventions for Picker — naming, swift-format, type safety, and Sources/Picker layout.
---

# Swift Conventions

Use when editing Swift under `Sources/Picker/`.

## Rules

- Prefer descriptive names and small focused types or functions.
- Use early returns; keep control flow shallow.
- Avoid force unwraps unless failure is truly impossible and localized.
- Match `.swift-format` (4-space indent, 100-column).
- Keep the single-package layout discoverable: shell/UI/model/fonts stay in clearly named files (`App.swift`, `PanelView.swift`, `Model.swift`, `Fonts.swift`, `FontPicker.swift`, `FontLoader.swift`, `DesignSystem.swift`, `ColorSampler.swift`).

## Tooling

```bash
swift format --in-place --configuration .swift-format --recursive Sources
swift format lint --configuration .swift-format --recursive Sources
```

## Repository Conventions

- No third-party packages without an explicit product decision.
- UI-rendering files should include `#Preview` when isolation is practical.
- Prefer extending existing types over parallel “V2” helpers.
