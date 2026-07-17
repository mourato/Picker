---
name: documentation
description: Documentation guidance for Picker — README, AGENTS.md (canonical agent guide; CLAUDE.md symlink), and MARK organization in sources.
---

# Documentation

Use when updating project docs, agent guidance, or in-source section markers.

## Ownership

- **README.md** — product pitch, requirements, build/run, feature overview for humans.
- **AGENTS.md** — canonical agent guide (identity, commands, deliberate design, loupe/fonts, skills routing). Edit this file only.
- **CLAUDE.md** — symlink to `AGENTS.md` for Claude Code / tools that expect that filename. Do not edit separately.
- **`.agents/SKILLS_INDEX.md`** — skill catalog and routing table.
- Source `// MARK:` — navigate large files (`PanelView`, `FontPicker`, `App`).

## Rules

- Keep agent guidance in `AGENTS.md` only; never diverge a separate `CLAUDE.md` body.
- Document Chrome Automation / Accessibility requirements whenever Grab Font behavior changes.
- Prefer linking to skills over duplicating long checklists in README.
- Do not invent Makefile targets or test commands that do not exist.

## Checklist

- Would a new contributor build and run from README alone?
- Do agent docs still match `./build.sh` and `--demo` behavior?
- Are deliberate non-obvious choices (non-activating panel, YIQ, wheel scroll) still called out?
- Does `CLAUDE.md` still resolve to `AGENTS.md` (`readlink CLAUDE.md`)?

## Related

- Standards / routing → `AGENTS.md` + `SKILLS_INDEX.md`
- Delivery commands → `delivery-workflow`
