# Obsidian Bridge

Canonical Obsidian-vault layout, schema, primitives, and cleanup workflow for Claude Code.

Standalone plugin — works without any other plugins. Pairs cleanly with `cabinet-of-imd` when both are installed.

## What it does

- **Type-shaped projects** — `coding`, `knowledge`, `plugin`, `tinkerage` — each with appropriate brief blocks and subfolder defaults.
- **Vault primitives** — CLI-first Obsidian operations with filesystem fallback. Read, write, search, move, rename — abstracted behind `vault.*` calls.
- **SessionStart hook** — discovers vault, injects context, steers toward vault connection when not linked.
- **7 verbs** — lifecycle (`/connect`, `/sync`, `/check`), cleanup (`/ramasse`, `/dream`), visual artefacts (`/draw`), state transitions (`/iterate`). Content creation moves to conversation.
- **Remember integration** — mirror `.remember/remember.md` to vault as `_handoff.md`.

## Commands

| Verb | Purpose |
|---|---|
| `/connect [path]` | Onboard: link this folder to an Obsidian vault (creates one if needed) |
| `/sync` | Push current state to the vault (brief + handoff) |
| `/check [section]` | Read-only summary; optional sections: `iterations`, `decisions`, `sessions`, `handoff`, `tags` |
| `/draw <subverb>` | Visual artefacts — `canvas <name>` / `base <name>` / `diagram [type]` |
| `/ramasse` | Tidy the vault — rebuild indexes, fix drift, normalise tags |
| `/dream` | Deep diagnostic — surfaces structural and content issues |
| `/iterate <id> <status>` | Set iteration status (`drafting`/`on-shelf`/`picked`/`parked`/`rejected`/`superseded`). May be sunset later |

> Coming from the old `/vault-bridge ...` surface? See [`notes/2026-05-04-command-surface-redesign-migration.md`](notes/2026-05-04-command-surface-redesign-migration.md).

## Install

Add to your Claude Code plugins or install from the Onnozelaer marketplace.

## Vault schema version

This plugin uses vault schema **v3**. Projects created with cabinet-of-imd v2 vaults can be migrated conversationally ("migrate this vault to v3").

## License

MIT
