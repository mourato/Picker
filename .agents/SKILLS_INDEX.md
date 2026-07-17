# Skills Index

Skill registry for Picker.

The catalog is organized by responsibility so agents trigger the narrowest useful skill instead of loading overlapping guidance.

| Skill | Location | Use When |
| ----- | -------- | -------- |
| `delivery-workflow` | `.agents/skills/delivery-workflow/` | Build/run commands, verification scope, signing, Git/PR evidence, merge readiness |
| `macos-app-engineering` | `.agents/skills/macos-app-engineering/` | SwiftUI/AppKit panel UI, lifecycle, `NSHostingController`, glass, previews |
| `menubar` | `.agents/skills/menubar/` | `NSStatusItem`, click behavior, non-activating `NSPanel`, no Dock |
| `apple-design` | `.agents/skills/apple-design/` | Liquid Glass, motion/spacing tokens, materials, reduced motion/transparency |
| `accessibility-audit` | `.agents/skills/accessibility-audit/` | Contrast ink, VoiceOver labels, AX Grab Font, overlay invisibility, permissions |
| `data-persistence` | `.agents/skills/data-persistence/` | Palette/font JSON in UserDefaults, caps, `--demo` non-persist, schema keys |
| `swift-conventions` | `.agents/skills/swift-conventions/` | Swift style, naming, `swift-format`, file layout under `Sources/Picker/` |
| `swift-concurrency-expert` | `.agents/skills/swift-concurrency-expert/` | MainActor UI, async font load, Sendable across sampling boundaries |
| `code-quality` | `.agents/skills/code-quality/` | Refactors, dedup, dead-code removal, keep the single package coherent |
| `debugging-diagnostics` | `.agents/skills/debugging-diagnostics/` | Crashes, AX/Chrome failures, FontLoader network, event-tap issues |
| `testing-xctest` | `.agents/skills/testing-xctest/` | Adding XCTest coverage for color math, stores, FontLoader routing |
| `localization` | `.agents/skills/localization/` | User-facing strings, tooltips, accessible copy |
| `documentation` | `.agents/skills/documentation/` | README, AGENTS.md (CLAUDE.md symlink), MARK comments in sources |
| `global:improve` | `~/.codex/skills/improve/` | Read-only audits and self-contained implementation plans |
| `global:thermo-nuclear-code-quality-review` | `~/.codex/skills/thermo-nuclear-code-quality-review/` | Strict reviews; load `.agents/review-profiles/thermo-picker.md` |

## Catalog Notes

- `menubar` stays separate because status-item + non-activating panel behavior is product-critical and must not be replaced with `MenuBarExtra`.
- `accessibility-audit` owns Grab Font AX contracts and YIQ ink; `apple-design` owns visual feel of glass and motion.
- `data-persistence` owns `picker.pickedColors.v1` / `picker.pickedFonts.v1` and demo isolation.
- `delivery-workflow` owns `./build.sh`, signing identity vs ad-hoc, and manual verification — not domain rules.
- Global skills are external; do not duplicate them under `.agents/skills/`.

## Suggested Routing

| Task | Start With | Add When Needed |
| ---- | ---------- | --------------- |
| Ordinary panel / UI change | `macos-app-engineering` | `menubar`, `apple-design`, `accessibility-audit` |
| Status item / panel lifecycle | `menubar` | `macos-app-engineering` |
| Color sampling / formats / contrast | `macos-app-engineering` | `accessibility-audit`, `testing-xctest` |
| Grab Font / AX / Chrome | `accessibility-audit` | `debugging-diagnostics`, `menubar` |
| Palette or font store | `data-persistence` | `testing-xctest`, `debugging-diagnostics` |
| FontLoader / Find links | `macos-app-engineering` | `debugging-diagnostics`, `swift-concurrency-expert` |
| Concurrency / isolation | `swift-concurrency-expert` | `macos-app-engineering` |
| Refactor / cleanup | `code-quality` | `swift-conventions` |
| Build, sign, ship checks | `delivery-workflow` | `menubar` for manual gates |
| Code review | `global:thermo-nuclear-code-quality-review` + thermo-picker profile | domain skills touched by the diff |
| Planning / audit | `global:improve` | none; plans only |
