---
kind: project-overlay
extends: delivery-workflow
project: Picker
precedence: project
---

# Picker delivery overlay

- Use `./build.sh` for the release app bundle and `./build.sh debug` for the
  debug bundle; do not use plain `swift build` for day-to-day verification.
- Run `swift format lint --configuration .swift-format --recursive Sources`.
- `build.sh` assembles `build/Picker.app`, generates the required Info.plist,
  and preserves the project’s code-signing path. Do not bypass it when
  validating Liquid Glass or Screen Recording behavior.
- Picker has no automated test target; report the relevant manual menu-bar,
  Screen Recording, Accessibility/AX, and persistence gates when applicable.
- Do not merge a protected-branch change before reviewer approval and checks.
