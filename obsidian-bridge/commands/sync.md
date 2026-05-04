---
description: Push current state to the vault (brief + handoff)
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

Push current project state to the linked vault. Replaces `/vault-bridge sync` and `/vault-bridge handoff sync` — runs both in one pass.

## Usage

```
/sync                  Sync brief + handoff
/sync brief            Sync brief only
/sync handoff          Sync handoff only (mirror .remember/remember.md → vault _handoff.md)
```

Dispatch to the `vault-bridge` skill's `/sync` section.
