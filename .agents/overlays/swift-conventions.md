---
kind: project-overlay
extends: swift-conventions
project: Picker
precedence: project
---

# Picker Swift conventions overlay

- Swift sources live under `Sources/Picker/` in the single package; keep
  existing names and ownership boundaries discoverable.
- Format and lint with `swift format --configuration .swift-format`; the
  required check is `swift format lint --configuration .swift-format
  --recursive Sources`.
- New isolated SwiftUI views should include `#Preview` when practical.
- Preserve the no-third-party-dependency policy and use `./build.sh debug` for
  the app-bundle build rather than plain `swift build`.
