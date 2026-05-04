---
description: Link this folder to an Obsidian vault (creates one if needed)
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

Onboard the current project folder to an Obsidian vault. Single entry point — replaces `/vault-bridge create`, `/vault-bridge connect`, `/vault-bridge link`, and `/vault-bridge create-project`.

## Usage

```
/connect                       Discover or prompt for a vault path
/connect <path>                Connect to (or create) a vault at <path>
/connect <path> <slug>         Connect AND link this folder to project <slug>
/connect --new <path>          Force-create a new vault at <path> (error if non-empty)
/connect --link-only <slug>    Just set the project slug; vault must already be connected
```

## Inference rules

When `/connect <path>` is given without flags, the dispatcher infers what to do based on the state of the path:

| Path state | Action |
|---|---|
| Path doesn't exist | Create new vault (scaffold `Home.md`, `projects/`, `templates/`) |
| Path exists with `Home.md` (`type: vault-home` or `cabinet-home`) | Connect (read-only verification of vault structure) |
| Path exists with `projects/` folder but no `Home.md` | Connect (best-effort) |
| Path exists with neither | Error: "Expected `Home.md` with `type: vault-home` or a `projects/` folder at <path>" |

Dispatch to the `vault-bridge` skill's `/connect` section for the full pseudocode.
