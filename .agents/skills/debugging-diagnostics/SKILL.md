---
name: debugging-diagnostics
description: Debugging guidance for Picker — crashes, AX/Chrome Grab Font failures, event taps, and FontLoader network issues.
---

# Debugging Diagnostics

Use for crashes, flaky sampling/font grab, permission failures, or unexplained UI state.

## Method

1. Reproduce with a clear signature (action, app under cursor, OS permission state, signed vs ad-hoc build).
2. Narrow: panel shell vs color loupe vs font overlay vs persistence vs FontLoader.
3. Fix with a regression note in the PR/commit; prefer a focused test when logic is pure (color math, decode).

## Picker Hotspots

- **Accessibility not granted** — Grab Font toast; grant is tied to code signature (ad-hoc resign resets it).
- **Chrome/Chromium** — needs Automation + “Allow JavaScript from Apple Events”; AX geometry + `NSAppleScript` path differs from Safari/WebKit.
- **Event tap** — session tap must consume moves/clicks without freezing the cursor; teardown on Esc/dismiss must remove the tap.
- **FontLoader** — network/catalog failures should fall back cleanly; do not leave the specimen in a half-registered state.
- **Persistence** — corrupted UserDefaults JSON should fail soft.

## Logging Hygiene

- Prefer temporary, high-signal logs while diagnosing; do not ship noisy AX dumps.
- Never log full page script results or unrelated personal screen content.

## Related

- AX contracts → `accessibility-audit`
- Build/sign → `delivery-workflow`
