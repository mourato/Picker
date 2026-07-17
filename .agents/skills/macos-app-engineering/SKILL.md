---
name: macos-app-engineering
description: macOS SwiftUI/AppKit implementation for Picker — panel hosting, lifecycle, glass, sampling bridges, and previews.
---

# macOS App Engineering

## When to Use

Ordinary SwiftUI or AppKit work: panel content, AppKit bridges, lifecycle, Liquid Glass surfaces, or preview coverage.

## Responsibilities

- Menu-bar agent lifecycle (`LSUIElement`, no Dock).
- `NSPanel` + `NSHostingController` ownership and sizing.
- SwiftUI ↔ AppKit boundaries (`NSColorSampler`, overlays, event taps).
- Design-system reuse from `DesignSystem.swift`.
- Main-actor coordination for UI state.

## Platform Rules

- One clear owner for the status item and the floating panel.
- Cross SwiftUI/AppKit at a thin adapter; do not leak AppKit into every view file.
- Keep the panel non-activating so sampling does not steal focus.
- Prefer platform APIs already in use (`NSColorSampler`, `glassEffect`) over custom reimplementations.
- Respect Reduce Motion, Reduce Transparency, and Increase Contrast when touching materials or motion.

## Picker Focus

- Color path: loupe sampling → formats (HEX/RGB/HSL) → copy affordances → palette strip.
- Font path: Grab Font overlay → specimen / Find → saved fonts strip.
- Section switch (Colors / Fonts) should keep layout stable — sliding pill, no label reflow.

## Preview Expectations

- Add `#Preview` for new isolated SwiftUI views when practical.
- Full status-item/panel flows: verify with `./build.sh` and `--demo`.

## Related

- Menu-bar contracts → `menubar`
- Motion / glass feel → `apple-design`
- AX / contrast → `accessibility-audit`
