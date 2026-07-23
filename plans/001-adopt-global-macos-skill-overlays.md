# Plan 001: Adopt global macOS skills with a Picker project overlay

> **Executor instructions**: This is a guidance-only migration. Do not modify
> Swift, `Package.swift`, `build.sh`, assets, or signing behavior. The global
> Plan 004 must be merged before execution.
>
> **Drift check (run first)**: `git diff --stat e248643..HEAD -- AGENTS.md .agents/skills .agents/overlays plans`

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: global Plan 004 merged to global `main`
- **Category**: migration / dx / docs
- **Planned at**: commit `e248643`, 2026-07-23

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `Medium/Full`
- **Parallelizable**: no — serialize product migrations after the global merge
- **Reviewer required**: yes — this creates the first local adoption ledger
- **Rationale**: Picker has no existing plan ledger or guidance validator, so the plan must establish both without disturbing its deliberately detailed `AGENTS.md` product contract.
- **Escalate when**: the harness cannot discover global skills, or the migration requires changing the app build/signing path.

## Why this matters

Picker has concise copies of seven shared skills, while its important product
contracts already live in `AGENTS.md`: Liquid Glass, focus preservation,
Screen Recording, Accessibility/AX, YIQ contrast, persistence caps, and demo
isolation. The migration should centralize generic macOS guidance and keep those
contracts local.

## Current state

- `AGENTS.md:86-109` already says global skills use `global:<name>` and must not
  be copied into `.agents/skills/`.
- The seven duplicate local skills are under
  `.agents/skills/{accessibility-audit,apple-design,code-quality,delivery-workflow,macos-app-engineering,menubar,swift-conventions}/`.
- Picker has no `Makefile`, no automated test target, and uses `./build.sh` as
  its authoritative build/signing path.
- `AGENTS.md` says to edit only `AGENTS.md` when maintaining the `CLAUDE.md`
  symlink; preserve that rule.

## Scope

**In scope**

- `AGENTS.md`
- `.agents/overlays/` with seven Picker overlays
- deletion of the seven duplicate local skill directories
- `plans/README.md` and this plan
- `.agents/review-profiles/thermo-picker.md` routing from deleted local skill
  paths to the corresponding global skills and Picker overlays

**Out of scope**

- `Sources/**`, `Package.swift`, `build.sh`, assets, signing, permissions,
  `CLAUDE.md`, and product behavior
- `data-persistence`, `debugging-diagnostics`, `documentation`,
  `localization`, `swift-concurrency-expert`, `swift-conventions` beyond the
  migrated duplicate, and any future test-target work
- Global skill content or provider runtime homes

## Overlay contents

The seven overlays must preserve these Picker-specific facts:

- macOS 26+ and real Liquid Glass; no older-OS fallback;
- `./build.sh`, `./build.sh debug`, and the required `swift format lint` check;
- non-activating `NSPanel`/`NSStatusItem` instead of `MenuBarExtra`;
- Screen Recording for color sampling and Accessibility/Automation for Grab Font;
- YIQ ink contrast, click-through AX-invisible overlay, deepest `AXStaticText`,
  and focus-preserving sampling;
- UserDefaults caps, `--demo` persistence isolation, and the absence of a test target.

Do not place those rules in the global skill bodies.

## Steps

### Step 1: Confirm prerequisite and create a clean branch

```sh
git switch main
git pull --ff-only origin main
git switch -c chore/picker-global-skill-overlays
```

**Verify**: `git status --short --branch` → clean feature branch; global skills
are discoverable; no same-name local replacement is loaded.

### Step 2: Create overlays and update AGENTS.md

Create seven companion files under `.agents/overlays/`. Extend the existing
Skills section in `AGENTS.md` with the seven global-skill-to-overlay mappings.
Route the project-only review profile from deleted local skill paths to the
global skills and corresponding Picker overlays. Keep the existing
`global:improve` and global review routing intact.

**Verify**: `rg -n "global:|project-overlay|\.agents/overlays|Liquid Glass|YIQ|AX|Screen Recording" AGENTS.md .agents/overlays` → routing and Picker invariants are visible.

### Step 3: Remove duplicate local copies

Delete only the seven local duplicate skill directories. Do not delete the
project-only review profile or any `.agents` metadata.

**Verify**: `find .agents/skills -mindepth 2 -maxdepth 2 -name SKILL.md -print | sort` → no migrated duplicate names; `find .agents/overlays -type f -name '*.md' | wc -l` → 7.

### Step 4: Validate guidance and build baseline

Run:

```sh
git diff --check
swift format lint --configuration .swift-format --recursive Sources
./build.sh debug
```

Expected result: formatting lint exits 0 and the debug app bundle is assembled
as before. Do not run plain `swift build` as the project policy forbids it.

### Step 5: Commit, push, merge, and clean up

Stage only `AGENTS.md`, `.agents/`, `plans/README.md`, and this plan. Commit:

```text
docs(agents): adopt global macos skill overlays
```

Push the feature branch, open a PR against `main`, wait for review/checks,
merge through the normal protected-branch path, then verify and clean:

```sh
git switch main
git pull --ff-only origin main
git fetch origin --prune
git branch -d chore/picker-global-skill-overlays
git push origin --delete chore/picker-global-skill-overlays  # only if present
git worktree list
```

Delete only the explicit disposable worktree after confirming it is no longer
in use. Never delete `main`, `upstream`, or an unmerged branch.

## Test plan

- Seven overlays exist and declare `extends` for the seven global skills.
- No duplicate local global-skill directory remains.
- The project-only review profile references global skills and Picker overlays,
  with no deleted local skill paths.
- `git diff --check` passes.
- `swift format lint ... Sources` passes.
- `./build.sh debug` passes and preserves the existing app bundle/signing path.
- Manually inspect that all AX, Liquid Glass, TCC, persistence, and demo rules
  remain in `AGENTS.md` or the overlays.

## Done criteria

- [ ] Seven Picker overlays exist.
- [ ] `AGENTS.md` routes global skill plus overlay.
- [ ] Duplicate local copies are removed.
- [ ] Formatting lint and debug build pass.
- [ ] No app source or build script changed.
- [ ] Commit, push, review, merge, local cleanup, remote branch cleanup, and
      worktree cleanup are complete.

## STOP conditions

- The global prerequisite is not merged/discoverable.
- The tree is dirty before branching.
- `./build.sh debug` changes or requires product source/build changes.
- Removing a local copy breaks a retained project-only profile.
- A merge requires bypassing review or force-pushing.

## Maintenance notes

Picker’s detailed AX, sampling, Liquid Glass, persistence, and demo contracts
must remain local. The global skills should be updated only for behavior that
is genuinely shared by all macOS projects.
