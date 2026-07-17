---
name: apple-design
description: Liquid Glass, motion, materials, and typography feel for Picker’s menu-bar panel — aligned with DesignSystem tokens and system accessibility settings.
---

# Apple Design

Use when changing panel visuals, glass materials, section-switch motion, springs, or typography/specimen presentation.

## Invariants

- Prefer real macOS 26 **Liquid Glass** (`glassEffect`) over mock blurs or opaque chrome.
- Reuse tokens in `DesignSystem.swift` (ink, spacing, radii, motion) before inventing new constants.
- Motion should be interruptible and short; section switch is a sliding pill with crossfade — labels stay pinned.
- Respect `@Environment(\.accessibilityReduceMotion)` and Reduce Transparency: prefer opacity crossfades and more solid surfaces when those settings are on.
- Specimen text should render in the real face when loaded; fallbacks must still look intentional, not broken.

## Checklist

- Does glass still read as a floating panel over the desktop?
- Are springs/critically damped defaults used for UI chrome (no gratuitous bounce)?
- Is hierarchy clear without extra cards, badges, or chrome?
- Do dark/light and high-contrast settings keep HEX and labels readable? (Ink contrast → `accessibility-audit`.)

## Related

- Implementation wiring → `macos-app-engineering`
- Contrast / VoiceOver → `accessibility-audit`
