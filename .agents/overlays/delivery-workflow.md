---
kind: project-overlay
extends: delivery-workflow
project: Picker
precedence: project
---

# Picker delivery overlay

- `./build.sh` is the authoritative app-bundle path; `./build.sh debug`
  assembles the debug bundle.
- The script generates Picker’s `Info.plist` and preserves its code-signing
  path, which is required for Liquid Glass and Screen Recording behavior.
- Picker has no automated test target; applicable manual gates cover the
  menu-bar, Screen Recording, Accessibility/AX, and persistence flows.
