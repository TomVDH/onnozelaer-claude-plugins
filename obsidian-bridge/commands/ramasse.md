---
description: Tidy the vault — rebuild indexes, fix drift, normalise tags
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

Tidy the vault. Replaces `/vault-bridge reindex` and `/vault-bridge housekeeping` — runs the consistency sweep in one pass.

*Ramasse* (French): pick up, gather, tidy.

## Usage

```
/ramasse                       Full sweep: reindex all _index.md + housekeeping consistency check
/ramasse --dry-run             Show what would change without writing
/ramasse indexes               Rebuild _index.md only (skip consistency check)
/ramasse housekeeping          Consistency check only (skip reindex)
```

Dispatch to the `vault-bridge` skill's `/ramasse` section.
