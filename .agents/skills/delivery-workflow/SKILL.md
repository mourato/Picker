---
name: delivery-workflow
description: Delivery and verification workflow for Picker — ./build.sh, signing, manual menu-bar gates, and Git evidence.
---

# Delivery Workflow

## When to Use

Build/run failures, choosing verification depth, assessing merge readiness, or Git/PR evidence.

## Command Routing

| Command | Purpose |
| ------- | ------- |
| `./build.sh` | Release app bundle under `build/Picker.app` + codesign |
| `./build.sh debug` | Debug app bundle |
| `open build/Picker.app` | Launch menu-bar agent |
| `build/Picker.app/Contents/MacOS/Picker --demo` | Seeded UI, in-memory stores, sticky panel |
| `swift format lint --configuration .swift-format --recursive Sources` | Format check |
| `swift format --in-place --configuration .swift-format --recursive Sources` | Format fix |

Do **not** treat plain `swift build` as sufficient acceptance — Info.plist and signing are required for glass and the loupe.

## Signing Note

`build.sh` prefers `Prisma Local Code Signing` (override with `PICKER_CODE_SIGN_IDENTITY`), otherwise ad-hoc. Accessibility grants follow the signing identity — stable signing avoids re-prompting every rebuild.

## Validation Scope

### Merge Gate (current)

1. `swift format lint --configuration .swift-format --recursive Sources`
2. `./build.sh`
3. Manual smoke appropriate to the diff (below)

### Scope Matrix

- Pure refactor: build + open panel once (`--demo` OK).
- Panel / design / section switch: `--demo` UI pass + Reduce Motion glance if motion changed.
- Color sampling / formats / contrast: pick a color; verify HEX/RGB/HSL copy and ink on a saturated swatch.
- Grab Font / AX: grant path or toast; grab in Safari and, if touched, Chrome prerequisites.
- Persistence: relaunch without `--demo`; confirm `--demo` does not write real stores.
- FontLoader / Find: grab a missing face; confirm specimen or graceful fallback and Find destination.

## Git Evidence

- Prefer granular commits (one logical change).
- Summarize what was built and which manual checks ran.
- Do not commit secrets or personal palette dumps.

## Related

- Domain behavior → narrowest skill in `.agents/SKILLS_INDEX.md`
- Strict review → `global:thermo-nuclear-code-quality-review` + `.agents/review-profiles/thermo-picker.md`
