---
kind: project-overlay
extends: macos-app-engineering
project: Picker
precedence: project
---

# Picker macOS engineering overlay

- Picker targets macOS 26+ with real Liquid Glass and no older-OS fallback.
- Its single status-item owner pairs an `NSStatusItem` with a non-activating,
  borderless `NSPanel`, not `MenuBarExtra`, so sampling preserves source focus.
- Pick a Color uses Screen Recording and freeze-loupe sampling; Grab Font uses
  a click-through AX-invisible overlay with Accessibility and Chrome Automation
  permissions.
- The `--demo` path uses in-memory data and does not write real stores.
