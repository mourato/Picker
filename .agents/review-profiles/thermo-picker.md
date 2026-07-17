# Picker Thermo Review Profile

This is a project-only supplement to `global:thermo-nuclear-code-quality-review`.
It contains no generic review checklist and no model configuration.

## Project invariants

- Preserve exact sampling, focus-preserving panel behavior, and safe persistence before convenience.
- Treat `NSStatusItem` ownership, left-click / right-click semantics, non-activating `NSPanel` (not `MenuBarExtra`), and sampling/font-pick overlays as product-critical. Load `.agents/skills/menubar/SKILL.md` when a diff touches those paths.
- Do not replace YIQ ink contrast with WCAG luminance alone without an explicit product decision.
- Keep `--demo` from writing real UserDefaults stores (`persistenceEnabled = false`).
- Prefer `./build.sh` over plain `swift build` for acceptance; Info.plist + codesign matter for glass and the loupe.
- Accessibility permission and stable signing identity matter for Grab Font — call out ad-hoc resign regressions.
- Do not accept orphaned UI, helpers, or assets; prove removals with search and runtime path.
- There is no automated test gate yet; require documented manual verification for menu-bar, sampling, and Grab Font flows when those surfaces change.

## Routing boundary

Use `.agents/skills/delivery-workflow/SKILL.md` for commands, validation depth, and Git evidence. Use the narrowest domain skill for technical behavior. This profile only adds Picker-specific acceptance criteria to the global thermo review.
