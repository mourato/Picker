---
name: code-quality
description: Refactoring and maintainability for Picker — deduplication, dead-code removal, and keeping the single package coherent.
---

# Code Quality

Use when simplifying code, moving responsibilities, or cleaning unused pieces exposed by a change.

## Checklist

- Reuse an existing helper before adding another abstraction.
- Keep side effects localized and named clearly.
- Prefer one obvious owner for each workflow (status item, panel, sampler, font picker, stores).
- Remove dead UI, helpers, assets, and stale previews in the same change when they become unused.
- Support every removal with objective evidence: `rg`, call sites, or runtime path.
- Do not grow toward a multi-module split unless the request explicitly asks for it — keep the compact package shape.

## Refactor Strategy

- Prefer behavior-preserving refactors in small slices.
- Separate structural moves from behavior changes when practical.
- If a file mixes unrelated concerns, split by ownership (`ColorSampler` vs panel chrome vs persistence), not by arbitrary line count.

## Validation

- `./build.sh`
- Manual smoke: open panel, sample or use `--demo`, confirm palette/fonts still behave.
- `swift format lint --configuration .swift-format --recursive Sources`
