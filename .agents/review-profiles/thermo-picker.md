# Picker Thermo Review Profile

This is a project-only supplement to `global:thermo-nuclear-code-quality-review`.
It contains no generic review checklist and no model configuration.

## Project invariants

- Preserve exact sampling, focus-preserving panel behavior, and safe persistence before convenience.
- Treat `NSStatusItem` ownership, left-click / right-click semantics, non-activating `NSPanel` (not `MenuBarExtra`), and sampling/font-pick overlays as product-critical. Load `global:menubar` and then `.agents/overlays/menubar.md` when a diff touches those paths.
- Do not replace YIQ ink contrast with WCAG luminance alone without an explicit product decision.
- Keep `--demo` from writing real UserDefaults stores (`persistenceEnabled = false`).
- Prefer `./build.sh` over plain `swift build` for acceptance; Info.plist + codesign matter for glass and the loupe.
- Accessibility permission and stable signing identity matter for Grab Font — call out ad-hoc resign regressions.
- Do not accept orphaned UI, helpers, or assets; prove removals with search and runtime path.
- There is no automated test gate yet; require documented manual verification for menu-bar, sampling, and Grab Font flows when those surfaces change.

## Routing boundary

Use the narrowest relevant skill for each change. For every migrated global
skill, load the global skill first and then its Picker overlay:

- `global:accessibility-audit` → `.agents/overlays/accessibility-audit.md`
- `global:apple-design` → `.agents/overlays/apple-design.md`
- `global:code-quality` → `.agents/overlays/code-quality.md`
- `global:delivery-workflow` → `.agents/overlays/delivery-workflow.md`
- `global:macos-app-engineering` → `.agents/overlays/macos-app-engineering.md`
- `global:menubar` → `.agents/overlays/menubar.md`
- `global:swift-conventions` → `.agents/overlays/swift-conventions.md`

Retain and route the project-only specialists when their ownership is
relevant: `data-persistence` → `.agents/skills/data-persistence/SKILL.md`,
`debugging-diagnostics` → `.agents/skills/debugging-diagnostics/SKILL.md`,
`documentation` → `.agents/skills/documentation/SKILL.md`,
`localization` → `.agents/skills/localization/SKILL.md`,
`swift-concurrency-expert` →
`.agents/skills/swift-concurrency-expert/SKILL.md`, and `testing-xctest` →
`.agents/skills/testing-xctest/SKILL.md`.

This profile only adds Picker-specific acceptance criteria to the global thermo
review.
