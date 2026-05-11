# Command surface migration — old → new

Quick reference for anyone with the old `/vault-bridge ...` and `/dream` surface in muscle memory.

## Mapping

| Old | New |
|---|---|
| `/vault-bridge create [path]` | `/connect [path]` (path doesn't exist → creates) |
| `/vault-bridge create --new [path]` | `/connect --new [path]` |
| `/vault-bridge connect <path>` | `/connect <path>` (path exists with Home.md → connects) |
| `/vault-bridge link <slug>` | `/connect --link-only <slug>` |
| `/vault-bridge create-project <slug> <type>` | conversational ("new project foo, knowledge type") |
| `/vault-bridge add-collection <name>` | conversational ("add a tasks/ folder to foo") |
| `/vault-bridge sync` | `/sync` (or `/sync brief` for brief only) |
| `/vault-bridge handoff sync` | `/sync` (or `/sync handoff` for handoff only) |
| `/vault-bridge status` | `/check` |
| `/vault-bridge handoff status` | `/check handoff` |
| `/vault-bridge archive <slug>` | conversational ("archive foo") |
| `/vault-bridge unarchive <slug>` | conversational ("unarchive foo") |
| `/vault-bridge reindex` | `/ramasse indexes` (or `/ramasse` for full sweep) |
| `/vault-bridge housekeeping` | `/ramasse housekeeping` (or `/ramasse` for full sweep) |
| `/vault-bridge migrate` | conversational ("migrate this vault to v3") |
| `/vault-bridge migrate-anchor` | **auto** — runs silently in SessionStart hook |
| `/vault-bridge set-type <slug> <type>` | conversational ("change foo to plugin type") |
| `/vault-bridge templates [list\|print <name>]` | conversational ("show me the brief template for coding") |
| `/vault-bridge add-iteration <id> <slug>` | conversational ("new iteration D for foo on navy track") |
| `/vault-bridge add-iteration-artefact <id> <file>` | conversational ("attach concept.png to iter D") |
| `/vault-bridge iterations [<slug>] [--tree]` | `/check iterations` (or conversational) |
| `/vault-bridge iteration-set-status <id> <status>` | `/iterate <id> <status>` |
| `/dream` | `/dream` (unchanged) |

## Why the change

The old surface had ~25 subcommands across two slash entries. The new surface is 7 top-level verbs:

```
/connect /sync /check /draw /ramasse /dream /iterate
```

Content creation (decisions, notes, sources, projects, archives, etc.) moves from commands to conversation. Commands now exist only for: lifecycle moments, state-machine transitions, cleanup, diagnostic, and visual artefact entry (canvas/base/diagram via `/draw`).

See [`2026-05-04-command-surface-redesign.md`](2026-05-04-command-surface-redesign.md) for the full design rationale.

## Anchor file location

The anchor file moved from `$CLAUDE_PROJECT_DIR/.obsidian-bridge` to `$CLAUDE_PROJECT_DIR/.claude/obsidian-bridge`. **You don't need to do anything** — the SessionStart hook auto-migrates legacy anchors silently the next time you open Claude in a project. The `.gitignore` line is also rewritten.
