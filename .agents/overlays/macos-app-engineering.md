---
kind: project-overlay
extends: macos-app-engineering
project: Picker
precedence: project
---

# Picker macOS engineering overlay

- Target macOS 26+ with real Liquid Glass and no older-OS fallback.
- Keep one explicit owner for the `NSStatusItem` and the non-activating,
  borderless `NSPanel`; use this pair rather than `MenuBarExtra` so sampling
  does not steal focus.
- Pick a Color uses Screen Recording permission and freeze-loupe sampling;
  Grab Font uses a click-through AX-invisible overlay and Accessibility (plus
  Chrome Automation) permission.
- Keep SwiftUI/AppKit bridges thin and preserve the existing `--demo` path,
  which uses in-memory data and does not write real stores.
