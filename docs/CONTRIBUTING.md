---
title: Contributing to Messaging Docs
---

# Contributing to Messaging Docs

## Documentation Rules

- All documentation lives in `docs/`
- Do not edit the GitHub Wiki directly
- Wiki is auto-generated on merge to `main`

## Wiki Sync Workflow

- Changes under `docs/**` on `main` automatically sync to the GitHub Wiki via:
  - Workflow: `.github/workflows/wiki-sync.yml`
  - Script: `scripts/sync-wiki.sh`
- The script:
  - Clones the Wiki repo.
  - Clears old content (except `Home.md`).
  - Copies everything from `docs/` into the Wiki.
  - Copies `docs/README.md` to `Home.md` as the wiki landing page.

## Suggested Flow

1. Edit or add docs under `docs/` (and `docs/images/` for images).
2. Run a local spellcheck or preview in your editor if desired.
3. Open a PR with your changes.
4. After merge to `main`, the wiki sync workflow will update the GitHub Wiki automatically..
