---
kind: project-overlay
extends: apple-design
project: Picker
precedence: project
---

# Picker design overlay

- Target macOS 26+ and use real Liquid Glass (`glassEffect`); do not add an
  older-OS fallback or substitute mock blur chrome.
- Reuse Picker’s existing `DesignSystem.swift` tokens for materials, spacing,
  radii, typography, and motion.
- Preserve the Colors/Fonts sliding pill with pinned labels and crossfade;
  respect Reduce Motion, Reduce Transparency, and Increase Contrast.
