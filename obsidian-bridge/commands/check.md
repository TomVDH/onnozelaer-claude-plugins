---
description: Read-only summary; optional sections (iterations, decisions, sessions, handoff)
allowed-tools: Read, Glob, Grep
---

Read-only summary of the linked vault and current project. Replaces `/vault-bridge status` and `/vault-bridge handoff status`. Pass one or more sections for a focused view.

## Usage

```
/check                                     Full vault + current-project summary
/check <section> [<section> ...]           Focused view; sections combine in one call
```

### Sections

| Section | What it shows |
|---|---|
| `iterations` | Iterations grouped by track and status (current project; --all for vault-wide) |
| `decisions` | Recent decisions (current project; --all for vault-wide) |
| `sessions` | Recent session summaries |
| `handoff` | Last handoff sync time + freshness vs `.remember/remember.md` |
| `tags` | Tag taxonomy summary across vault |

Multi-section: `/check iterations decisions` returns both, separately rendered.

Dispatch to the `vault-bridge` skill's `/check` section.
