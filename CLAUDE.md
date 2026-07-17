# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Picker is a native macOS menu-bar color picker (SwiftUI + AppKit, no dependencies). It samples any screen pixel via a freeze loupe, shows HEX/RGB/HSL/HSB, and keeps a saved palette.

## Build & run

- **Build with `./build.sh`, not `swift build`.** Plain SPM only compiles the binary. `build.sh` also assembles `build/Picker.app`, generates `Contents/Info.plist` (`LSUIElement = true` for menu-bar-only, `LSMinimumSystemVersion = 26.0`, Screen Recording + Apple Events usage strings), and **ad-hoc codesigns** (`codesign --force --deep --sign -`). The Info.plist and signing are required for Liquid Glass and Screen Recording permission to work.
- `./build.sh` defaults to release; pass `debug` for a debug build.
- Run: `open build/Picker.app`. The eyedropper appears in the menu bar (left-click opens the panel, right-click quits).
- **`--demo` flag** (`build/Picker.app/Contents/MacOS/Picker --demo`): seeds 10 swatches, **disables persistence** (in-memory only), and keeps the panel open without dismiss-on-outside-click. Use it for fast UI iteration without touching the real palette.

## Hard requirement

macOS 26 (Tahoe). The app relies on SwiftUI `glassEffect` (Liquid Glass) and ScreenCaptureKit for the freeze loupe. There is no fallback for older macOS.

## Don't "fix" these on sight — they're deliberate

- **Non-activating `NSPanel`, not `MenuBarExtra`.** `FloatingPanel` sets `canBecomeMain = false` and a non-activating style so the panel doesn't steal focus from the app being sampled. `MenuBarExtra` would close on sample.
- **Freeze loupe, not `NSColorSampler`.** The system sampler cannot show a configurable HEX/HSL/HSB label. `ColorSampler` captures each display once (ScreenCaptureKit), paints an opaque overlay, and samples the frozen bitmap so the loupe label can follow `AppSettings.colorDisplayFormat`.
- **YIQ contrast math, not WCAG luminance.** Ink color is chosen by perceived brightness (`0.299·R + 0.587·G + 0.114·B`), which keeps white text legible on saturated reds/blues where WCAG relative luminance gets it wrong.
- **Wheel-to-horizontal palette scroll.** `WheelHScroll` intercepts the vertical mouse wheel to scroll the palette row horizontally; trackpad swipes pass through.

## Persistence

Stores persist to `UserDefaults`: colors under `picker.pickedColors.v1` (capped at 60; consecutive duplicate samples update rather than append), fonts under `picker.pickedFonts.v1` (re-grabbing a family moves it to the front), display format under `picker.colorDisplayFormat.v1`, loupe zoom under `picker.loupeMagnification.v1`, pick shortcut under `picker.pickShortcut.keyCode.v1` / `.modifiers.v1`. The `--demo` path sets `persistenceEnabled = false` on stores/settings so seeded data never touches the user's real saved items.

## Color loupe

"Pick a Color" (panel button or global hotkey, default **⌃⌥C** via Carbon `RegisterEventHotKey`) gates on **Screen Recording** (`CGPreflightScreenCaptureAccess` / `CGRequestScreenCaptureAccess`) before hiding the panel — toast + System Settings deep link on deny. On grant: freeze every display, show loupe overlay, label uses the preferred format (gear in the panel). Loupe zoom defaults to 12× (range 4…32); change it in settings or with **−** / **=** during capture (persists). Click commits; Esc / right-click cancels.

## Fonts feature

The panel has a Colors/Fonts section switch. macOS has no system font loupe, so "Grab Font" (`FontPicker.swift`) overlays a full-screen, **click-through, accessibility-invisible** window and installs a **`CGEventTap`** (`.cgSessionEventTap`, `.headInsertEventTap`) that *consumes* mouse-moved + click events before any app sees them — so the page beneath stays inert (a hover-dropdown won't open, a link won't follow on click). Consuming moves at the session tap does **not** freeze the cursor, and there is **no `NSApp.activate`** so the source app isn't force-deselected.

Reading: a **system-wide** `AXUIElementCopyElementAtPosition` (the overlay is AX-invisible so the hit test reads *through* it — a per-application query only reaches `AXWebArea`/`AXScrollArea` and can't descend into web content) returns the element under the point, then a descent (`AXChildren` + `AXFrame` containment) resolves to the deepest **`AXStaticText`** leaf. This is robust for any text anywhere, including items in an already-open dropdown, and means the highlight hugs the actual text run, never a surrounding div. Font comes from WebKit/Blink text-marker attrs (`AXTextMarkerRangeForUIElement` → `AXAttributedStringForTextMarkerRange`), char-range fallback for native text.

The overlay draws a crosshair, a box around the text, and a live "family · size" label. Click text → grab; click non-text / Esc / right-click → close.

- Requires **Accessibility permission** — prompts on first use via `AXIsProcessTrustedWithOptions`; until granted, "Grab Font" shows a toast. The grant is tied to the binary's code signature, so rebuild+reinstall needs re-granting. (When run from a terminal that already holds Accessibility, the binary inherits it — handy for verifying without granting the bundle.)
- The fonts side shows a live specimen rendered in the family (`Font.custom`) and a Google Fonts "Find" link; fonts not installed locally are saved by name with an "approx." note.
- The Colors/Fonts `SectionSwitch` slides a single pill; the labels are pinned in fixed slots and only crossfade color — they never reflow.

## Formatting

Code is formatted with Apple's `swift-format` (bundled with the toolchain) against `.swift-format` (4-space indent, 100-col). Format in place after edits:

```bash
swift format --in-place --configuration .swift-format --recursive Sources
swift format lint --configuration .swift-format --recursive Sources   # check only
```

## Testing & conventions

- There are no automated tests. Verify changes by building and running the app (use `--demo` for UI work).
- Commits are granular — one logical change per commit.
