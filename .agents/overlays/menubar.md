---
kind: project-overlay
extends: menubar
project: Picker
precedence: project
---

# Picker menu-bar overlay

- Picker is a menu-bar-only app (`LSUIElement = true`) with one owned
  `NSStatusItem` and one non-activating `NSPanel`; do not introduce
  `MenuBarExtra` or a regular activating main window.
- Left-click toggles the panel and right-click quits. The panel remains open
  while sampling or font grabbing runs, and the sampled app keeps focus.
- `./build.sh` owns the bundle’s `LSUIElement` and signing-related Info.plist
  generation; preserve that path.
