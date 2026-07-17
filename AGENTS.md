# AGENTS.md — Picker Development Guide

## Identity

Picker is a native macOS menu-bar **color and font** picker: magnified-pixel sampling (HEX / RGB / HSL), Grab Font via Accessibility, Liquid Glass panel, and saved palette/font lists. Zero third-party dependencies; SwiftUI + AppKit; single Swift package.

## Core Values & Precedence

1. **Correct sampling** — exact pixel, exact text run; never steal focus from the sampled app.
2. **Predictable menu-bar UX** — left-click panel, right-click quit; panel stays open while sampling.
3. **Native feel** — Liquid Glass, design tokens, system accessibility settings.
4. **Safe persistence** — palette/fonts in UserDefaults; `--demo` never writes real stores.
5. **Small surface** — one package, no dependency creep.

If a tradeoff is required, choose **correctness and focus-preserving behavior** over short-term convenience.

## Command Surface

- `./build.sh` — release build + assemble `build/Picker.app` + codesign (default)
- `./build.sh debug` — debug build of the app bundle
- `open build/Picker.app` — launch menu-bar agent
- `build/Picker.app/Contents/MacOS/Picker --demo` — seeded UI, in-memory only, no outside-click dismiss
- `swift format --in-place --configuration .swift-format --recursive Sources`
- `swift format lint --configuration .swift-format --recursive Sources`

Do **not** use plain `swift build` for day-to-day verification. The Info.plist (`LSUIElement`, macOS 26) and signing are required for glass and the loupe.

## Hard Requirements

- macOS 26+ (Liquid Glass / `glassEffect`, `NSColorSampler`). No older-OS fallback.
- Grab Font needs Accessibility permission (tied to code-signing identity).
- Chrome/Chromium font grab also needs Automation + “Allow JavaScript from Apple Events”.

## Deliberate Design (do not “fix” on sight)

- Non-activating `NSPanel` + `NSStatusItem`, **not** `MenuBarExtra` — panel must stay open during sampling.
- Ink contrast uses **YIQ** perceived brightness, not WCAG relative luminance alone.
- Vertical mouse wheel scrolls the palette strip horizontally (`WheelHScroll`).

## Execution Policy

- Prefer CLI-first verification: `./build.sh` then run the app (use `--demo` for UI iteration).
- Keep changes small; one logical change per commit.
- There is no automated test target yet — verify by build + manual menu-bar checks.
- When UI/logic/assets become unused, remove them in the same change with search evidence.
- Model identifiers belong only in global agent configuration; do not put them in this repo’s skills or docs.

## SwiftUI Preview Policy

- Any new Swift file that renders interface (`View`, `NSViewRepresentable`, `NSViewControllerRepresentable`) should include at least one `#Preview` when practical for isolated UI.
- Prefer exercising the full panel with `--demo` when previews cannot host AppKit status-item/panel lifecycle.

## Skills

Use [`.agents/SKILLS_INDEX.md`](.agents/SKILLS_INDEX.md) as the local taxonomy and routing registry.

Global skills use the `global:<name>` form and must not be copied into `.agents/skills/`:

- `global:improve` — read-only audits and implementation plans
- `global:thermo-nuclear-code-quality-review` — strict reviews

Load the project-only profile [`.agents/review-profiles/thermo-picker.md`](.agents/review-profiles/thermo-picker.md) with the global thermo review.

`delivery-workflow` owns validation commands, risk lanes, and Git evidence. Domain skills own Picker technical invariants.

Primary local skills:

- `delivery-workflow`
- `macos-app-engineering`
- `menubar`
- `accessibility-audit`
- `apple-design`
- `swift-conventions`
- `code-quality`
