# AGENTS.md — Picker Development Guide

## Identity

Picker is a native macOS menu-bar **color and font** picker: freeze-loupe pixel sampling (HEX / RGB / HSL / HSB), Grab Font via Accessibility, Liquid Glass panel, and saved palette/font lists. Zero third-party dependencies; SwiftUI + AppKit; single Swift package.

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

Do **not** use plain `swift build` for day-to-day verification. `build.sh` also generates `Contents/Info.plist` (`LSUIElement = true` for menu-bar-only, `LSMinimumSystemVersion = 26.0`, Screen Recording + Apple Events usage strings) and codesigns with `Prisma Local Code Signing` when available (otherwise ad-hoc). The Info.plist and signing are required for Liquid Glass and Screen Recording permission to work.

`--demo` seeds 10 swatches, disables persistence, and keeps the panel open without dismiss-on-outside-click — use it for fast UI iteration without touching the real palette.

## Hard Requirements

- macOS 26+ (Liquid Glass / `glassEffect`, ScreenCaptureKit freeze loupe). No older-OS fallback.
- Pick a Color needs Screen Recording permission (tied to code-signing identity).
- Grab Font needs Accessibility permission (tied to code-signing identity).
- Chrome/Chromium font grab also needs Automation + “Allow JavaScript from Apple Events”.

## Deliberate Design (do not “fix” on sight)

- **Non-activating `NSPanel` + `NSStatusItem`, not `MenuBarExtra`.** `FloatingPanel` sets `canBecomeMain = false` and a non-activating style so the panel doesn't steal focus from the app being sampled. `MenuBarExtra` would close on sample.
- **Freeze loupe, not `NSColorSampler`.** The system sampler cannot show a configurable HEX/HSL/HSB label. `ColorSampler` captures each display once (ScreenCaptureKit), paints an opaque overlay, and samples the frozen bitmap so the loupe label can follow `AppSettings.colorDisplayFormat`. One overlay window per frozen `NSScreen` (not a single union window).
- **YIQ contrast math, not WCAG luminance alone.** Ink color is chosen by perceived brightness (`0.299·R + 0.587·G + 0.114·B`), which keeps white text legible on saturated reds/blues where WCAG relative luminance gets it wrong.
- **Wheel-to-horizontal palette scroll.** `WheelHScroll` intercepts the vertical mouse wheel to scroll the palette row horizontally; trackpad swipes pass through.

## Persistence

Stores persist to `UserDefaults`: colors under `picker.pickedColors.v1` (capped at 60; consecutive duplicate samples from normal `add` update rather than append — multi-pick loupe sessions use `appendAlways` so each click is kept), fonts under `picker.pickedFonts.v1` (re-grabbing a family moves it to the front), display format under `picker.colorDisplayFormat.v1`, clipboard format under `picker.clipboardFormat.v1` (palette chip copy + loupe commit; independent of loupe/hero `colorDisplayFormat`), loupe zoom under `picker.loupeMagnification.v1`, freeze scope under `picker.freezeScope.v1` (`allDisplays` / `cursorDisplay`), pixel grid under `picker.showPixelGrid.v1`, pick shortcut under `picker.pickShortcut.keyCode.v1` / `.modifiers.v1`. Open-at-login is owned by `SMAppService.mainApp` (System Settings), not UserDefaults. The `--demo` path sets `persistenceEnabled = false` on stores/settings so seeded data never touches the user's real saved items.

Deep ownership of caps, schema keys, and demo isolation → skill `data-persistence`.

## Color Loupe

"Pick a Color" (panel button or global hotkey, default **⌃⌥C** via Carbon `RegisterEventHotKey`) gates on **Screen Recording** (`CGPreflightScreenCaptureAccess` / `CGRequestScreenCaptureAccess`) before hiding the panel — toast + System Settings deep link on deny. On grant: freeze displays per `AppSettings.freezeScope` (default all connected displays, or only the display under the cursor), excluding Picker’s own windows; show one loupe overlay window per frozen `NSScreen`, then tuck the panel away under it. **Shift+click** captures a color into the session (palette via `appendAlways` + floating capture shelf) without ending; a final **click** (no Shift) commits the session, copies every captured color to the clipboard as one line per color in `AppSettings.clipboardFormat` (independent of loupe/hero `colorDisplayFormat`), and leaves the panel closed. A single click without Shift is a one-color session. Esc / right-click cancels and restores the pre-session palette snapshot (so duplicate-collapse and the 60-cap cannot orphan older swatches); if the panel was open when sampling started, it is revealed *before* removing the overlay so the live desktop never flashes. The capture shelf is a click-through glass strip at the bottom of the display under the cursor (`CaptureShelfController`). The app activates briefly so Esc / − / = / ⌘− / ⌘= are delivered and consumed. Loupe zoom defaults to 12× (range 4…32; pixel grid from 8× when `AppSettings.showPixelGrid` is on, default on); loupe radius defaults to 72pt (48…160).

## Grab Font

The panel has a Colors/Fonts section switch. macOS has no system font loupe, so "Grab Font" (`FontPicker.swift`) overlays a full-screen, **click-through, accessibility-invisible** window and installs a **`CGEventTap`** (`.cgSessionEventTap`, `.headInsertEventTap`) that *consumes* mouse-moved + click events before any app sees them — so the page beneath stays inert (a hover-dropdown won't open, a link won't follow on click). Consuming moves at the session tap does **not** freeze the cursor, and there is **no `NSApp.activate`** so the source app isn't force-deselected.

Reading: a **system-wide** `AXUIElementCopyElementAtPosition` (the overlay is AX-invisible so the hit test reads *through* it — a per-application query only reaches `AXWebArea`/`AXScrollArea` and can't descend into web content) returns the element under the point, then a descent (`AXChildren` + `AXFrame` containment) resolves to the deepest **`AXStaticText`** leaf. This is robust for any text anywhere, including items in an already-open dropdown, and means the highlight hugs the actual text run, never a surrounding div. Font comes from WebKit/Blink text-marker attrs (`AXTextMarkerRangeForUIElement` → `AXAttributedStringForTextMarkerRange`), char-range fallback for native text.

The overlay draws a crosshair, a box around the text, and a live "family · size" label. Click text → grab; click non-text / Esc / right-click → close.

- Requires **Accessibility permission** — prompts on first use via `AXIsProcessTrustedWithOptions`; until granted, "Grab Font" shows a toast. The grant is tied to the binary's code signature, so rebuild+reinstall needs re-granting. (When run from a terminal that already holds Accessibility, the binary inherits it — handy for verifying without granting the bundle.)
- The fonts side shows a live specimen rendered in the family (`Font.custom`) and a Google Fonts "Find" link; fonts not installed locally are saved by name with an "approx." note.
- The Colors/Fonts `SectionSwitch` slides a single pill; the labels are pinned in fixed slots and only crossfade color — they never reflow.

Deep ownership of AX contracts and YIQ ink → skill `accessibility-audit`.

## Formatting

Code is formatted with Apple's `swift-format` (bundled with the toolchain) against `.swift-format` (4-space indent, 100-col). Format in place after edits; lint with the check-only command in Command Surface.

## Execution Policy

- Prefer CLI-first verification: `./build.sh` then run the app (use `--demo` for UI iteration).
- Keep changes small; one logical change per commit.
- There is no automated test target yet — verify by build + manual menu-bar checks.
- When UI/logic/assets become unused, remove them in the same change with search evidence.
- Model identifiers belong only in global agent configuration; do not put them in this repo’s skills or docs.
- Global pick shortcut default is **⌃⌥C** (`GlobalHotKey` / Carbon); loupe zoom is `AppSettings.loupeMagnification` (4…32, −/= during capture).

## SwiftUI Preview Policy

- Any new Swift file that renders interface (`View`, `NSViewRepresentable`, `NSViewControllerRepresentable`) should include at least one `#Preview` when practical for isolated UI.
- Prefer exercising the full panel with `--demo` when previews cannot host AppKit status-item/panel lifecycle.

## Skills

Choose the narrowest relevant skill from its description. Keep routing policy
in this file and domain-specific guidance in the owning skill.

Global skills use the `global:<name>` form and must not be copied into `.agents/skills/`:

- `global:improve` — read-only audits and implementation plans
- `global:thermo-nuclear-code-quality-review` — strict reviews

When one of these global skills is active, load its optional Picker companion
overlay from `.agents/overlays/<skill-name>.md` after the global skill. The
overlay uses `kind: project-overlay`, preserves global safety and integrity
rules, and supplies Picker-specific paths, commands, platform facts, and
invariants:

- `global:accessibility-audit` → `.agents/overlays/accessibility-audit.md`
- `global:apple-design` → `.agents/overlays/apple-design.md`
- `global:code-quality` → `.agents/overlays/code-quality.md`
- `global:delivery-workflow` → `.agents/overlays/delivery-workflow.md`
- `global:macos-app-engineering` → `.agents/overlays/macos-app-engineering.md`
- `global:menubar` → `.agents/overlays/menubar.md`
- `global:swift-conventions` → `.agents/overlays/swift-conventions.md`

Load the project-only profile [`.agents/review-profiles/thermo-picker.md`](.agents/review-profiles/thermo-picker.md) with the global thermo review.

`delivery-workflow` owns validation commands, risk lanes, and Git evidence. Domain skills own Picker technical invariants.

Primary local skills:

- `global:delivery-workflow`
- `global:macos-app-engineering`
- `global:menubar`
- `global:accessibility-audit`
- `global:apple-design`
- `global:swift-conventions`
- `global:code-quality`
- `data-persistence`
- `debugging-diagnostics`
- `documentation`
- `localization`
- `swift-concurrency-expert`
- `testing-xctest`

## Compatibility

`CLAUDE.md` is a symlink to this file so Claude Code and other tools that look for `CLAUDE.md` share the same instructions. Edit **only** `AGENTS.md`.
