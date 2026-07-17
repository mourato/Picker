---
name: localization
description: Localization guidance for Picker — user-facing panel copy, tooltips, toasts, and accessible strings.
---

# Localization

Use when adding or changing user-visible strings, tooltips, permission toasts, or empty-state copy.

## Rules

- Keep user-facing text centralized and consistent in tone (short, direct).
- When introducing localization files, use stable keys; do not concatenate sentences in code for grammar-sensitive languages.
- Accessible labels should describe the action (“Copy HEX”, “Grab Font”), not only the visual glyph.
- Format examples (HEX/RGB/HSL) stay locale-stable as technical tokens; surrounding UI chrome can localize.
- Avoid hard-coded English in new permission/error toasts if a strings table exists — if none exists yet, keep strings easy to extract later.

## Checklist

- Are new strings reachable for future `Localizable.strings` extraction?
- Do VoiceOver labels match visible intent?
- Are technical format names left unambiguous across locales?

## Related

- A11y labels → `accessibility-audit`
- Docs / README → `documentation`
