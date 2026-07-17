---
name: documentation
description: Documentation guidance for Picker — README, CLAUDE.md, AGENTS.md, and MARK organization in sources.
---

# Documentation

Use when updating project docs, agent guidance, or in-source section markers.

## Ownership

- **README.md** — product pitch, requirements, build/run, feature overview for humans.
- **CLAUDE.md** — compact engineering constraints and “do not fix on sight” notes for coding agents.
- **AGENTS.md** — agent identity, commands, skill routing entry point.
- **`.agents/SKILLS_INDEX.md`** — skill catalog and routing table.
- Source `// MARK:` — navigate large files (`PanelView`, `FontPicker`, `App`).

## Rules

- Keep CLAUDE.md and AGENTS.md aligned on build commands and deliberate design constraints.
- Document Chrome Automation / Accessibility requirements whenever Grab Font behavior changes.
- Prefer linking to skills over duplicating long checklists in README.
- Do not invent Makefile targets or test commands that do not exist.

## Checklist

- Would a new contributor build and run from README alone?
- Do agent docs still match `./build.sh` and `--demo` behavior?
- Are deliberate non-obvious choices (non-activating panel, YIQ, wheel scroll) still called out?

## Related

- Standards / routing → `AGENTS.md` + `SKILLS_INDEX.md`
- Delivery commands → `delivery-workflow`
