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
- Left-click toggles the panel and right-click quits. When color sampling or
  font grabbing begins, the panel tucks away so the source surface is visible;
  color-cancel restores a previously visible panel before the loupe is removed,
  and font picking restores the panel when the pick finishes. The sampled app
  keeps focus; the color loupe is the brief exception that activates Picker to
  consume its own keyboard controls.
- `./build.sh` owns the bundle’s `LSUIElement` and signing-related Info.plist
  generation; preserve that path.
