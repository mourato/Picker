---
kind: project-overlay
extends: code-quality
project: Picker
precedence: project
---

# Picker code-quality overlay

- Keep the project as one dependency-free Swift package with clear ownership
  across the status item, panel, sampler, font picker, and persistence stores.
- Preserve the deliberately small surface and existing product contracts in
  `AGENTS.md`; do not refactor Liquid Glass, focus preservation, permissions,
  or persistence behavior as incidental cleanup.
- Validate Swift changes with `swift format lint --configuration .swift-format
  --recursive Sources` and the authoritative `./build.sh` path.
