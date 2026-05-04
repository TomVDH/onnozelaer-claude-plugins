# Command surface redesign — design spec

**Status:** DRAFT, brainstormed, not implemented.
**Date:** 2026-05-04
**Goal:** Collapse the current ~25-subcommand `/vault-bridge` + `/dream` surface into 7 opinionated top-level verbs, without losing any current functionality. Move content creation from commands into conversation; keep commands for lifecycle, sync, status, cleanup, diagnostic, visual artefacts, and iteration state transitions.

---

## Goals

- **Easier to use** — slash menu shows 6–7 evocative verbs instead of 25.
- **More opinionated** — there's one obvious way to do common things; rare things are conversational.
- **No power loss** — every current capability is reachable, just via a different path.
- **Discoverability for visual features** — canvases, bases, and mermaid diagrams get a dedicated entry point (`/draw`) so they're not invisible in the slash menu.
- **Mechanical reliability for state transitions** — iteration status changes get a dedicated verb because they are state-machine operations, not conversation.

## Non-goals

- Revising the frontmatter schema (`vault-standards`) — kept as-is.
- Revising hooks (5 hooks) — kept as-is.
- Revising skills (`vault-standards`, `mermaid`, `canvas`, `search`, `bases`, `markdown`, `cli`, `clipper-template`, `dream`, `vault-bridge`) — kept as-is.
- Renaming the plugin or restructuring the marketplace.

---

## Final command surface

| Verb | Purpose | Slash-menu description |
|---|---|---|
| `/connect [path]` | Onboard: link folder to vault, infers create / connect / link | Link this folder to an Obsidian vault (creates one if needed) |
| `/sync` | Push current state to vault — brief + handoff in one | Push current state to the vault (brief + handoff) |
| `/check [section]` | Read-only summary; optional section for focused view | Read-only summary; optional section (`iterations`, `decisions`, `sessions`) |
| `/draw <subverb> [args]` | Create or list visual artefacts | Create or list visual artefacts — canvases, bases, mermaid diagrams |
| `/ramasse` | Tidy: reindex + housekeeping in one pass | Tidy the vault — rebuild indexes, fix drift, normalise tags |
| `/dream` | Deep diagnostic — structural and content drift | Deep diagnostic — surfaces structural and content issues |
| `/iterate <id> <status>` | Iteration state transition (state-machine reliability) | Set iteration status (`drafting`/`on-shelf`/`picked`/`parked`/`rejected`/`superseded`). May be sunset in favour of conversational use |

7 verbs. Two foreign-language for character (`/ramasse` French, ~~`/cupola` Italian~~ → `/draw` English). Rest English.

### `/draw` subverbs

The only command with subverbs. Subverbs route into specific skills:

```
/draw                   → list visual artefacts in current project (canvases, bases, recent mermaid blocks)
/draw canvas <name>     → create or edit a .canvas file (loads canvas skill)
/draw base <name>       → create or edit a .base file (loads bases skill)
/draw diagram [type]    → drop a mermaid diagram into the current note (loads mermaid skill);
                          type optional — flowchart | sequence | class | state | erd | gantt | mindmap |
                          timeline | gitGraph | pie | quadrant | journey | C4
```

Subverbs are accepted because each routes into a structurally distinct artefact (different file type or specialised markdown). They earn their place; other commands don't get subverbs.

### `/iterate` sunset note

`/iterate` exists for **mechanical state-machine reliability**. State transitions (`drafting → picked`, `picked → superseded`, etc.) are not creative writing — they're property updates with a small enum. Conversational handling ("promote D to picked") is feasible but carries misinterpretation risk ("create a new iter D, promote, and pick").

**This command may be sunset in a future release** if conversational handling proves robust enough across model versions. Conversational creation and listing of iterations is already preferred — only the state transition has its own verb. Documented in the `vault-bridge` skill body.

---

## What is killed / folded

| Killed command | Where it lives now |
|---|---|
| `create`, `connect` (the verb), `link`, `create-project` | `/connect` (single onboarding entry) |
| `add-collection`, `archive`, `unarchive`, `set-type`, `templates` | conversational |
| `add-iteration`, `add-iteration-artefact`, `iterations` | conversational (only `/iterate` for status transitions) |
| `sync`, `handoff sync` | `/sync` |
| `status`, `handoff status` | `/check` (optional `[section]`) |
| `reindex`, `housekeeping` | `/ramasse` |
| `migrate` (v2→v3), `migrate-anchor` | conversational ("migrate this vault to v3", "move my anchor") |
| All `iteration-*` and `add-iteration-*` plurality | folded into `/iterate` (transitions only) + conversational (creation/listing) |

## What is preserved (no change)

- All 10 skills (`vault-standards`, `mermaid`, `canvas`, `search`, `bases`, `markdown`, `cli`, `clipper-template`, `dream`, `vault-bridge`) and their references.
- All 5 hooks (`SessionStart`, `SessionEnd`, `UserPromptSubmit`, `PostToolUse`, `PreCompact`).
- Frontmatter schema (canonical in `vault-standards` skill).
- Vault layout and naming rules.
- Anchor file location (`.claude/obsidian-bridge` canonical, legacy `.obsidian-bridge` fallback) — pending merge of `feat/anchor-in-dot-claude` branch.

---

## Plugin description (umbrella, shows in plugin browsers)

> Operate an Obsidian vault from Claude — opinionated layout, frontmatter schema, content know-how (canvas, bases, mermaid), and cleanup workflows.

(Replaces: "Canonical Obsidian-vault layout, schema, primitives, and cleanup workflow for Claude Code. Standalone and cabinet-aware.")

---

## How content creation works post-redesign

**Commands are for lifecycle, sync, status, cleanup, diagnostic, visual-artefact creation, and iteration state.**
**Content creation is conversational** for everything else. Examples:

| What you say | What happens |
|---|---|
| "add a decision: we're using postgres because X" | Model loads `vault-standards` + `markdown` skills, creates `projects/{slug}/decisions/YYYY-MM-DD-<title>.md` with canonical frontmatter |
| "make a quick source from this article: <url>" | Model creates `projects/{slug}/sources/<title>.md` with source schema |
| "new project foo, knowledge type" | Model creates `projects/foo/` scaffold with type-shaped templates |
| "archive foo" | Model moves `projects/foo/` → `archive/foo/` and rewrites frontmatter status |
| "change foo to plugin type" | Model updates `project_type` in `projects/foo/brief.md` and adjusts subfolder defaults |
| "promote iter D to picked" | Either: model updates frontmatter directly, OR you use `/iterate D picked` for guaranteed correctness |
| "show me on-shelf iterations" | Model greps `iterations/` folders for `status: on-shelf` and renders summary |
| "add a tasks/ folder to foo" | Model creates `projects/foo/tasks/_index.md` |
| "what does the brief template look like" | Model reads `examples/vault-templates/brief-{type}.md` |

The bet: with `vault-bridge` skill + `vault-standards` skill auto-loading, the model is reliable enough to handle these conversationally. Commands exist only where a command is genuinely better than conversation (lifecycle moments, mechanical state changes, visual entry points).

---

## Trade-offs accepted

- **Loss of slash-menu discoverability** for niche operations (set-type, archive, add-collection, templates, etc.). Mitigation: the `vault-bridge` skill body lists these capabilities so the model surfaces them when relevant.
- **Conversational risk** for state-changing operations like archive/migrate. Mitigation: model always confirms before destructive actions; PostToolUse validator catches bad frontmatter writes.
- **`/connect` does three things** (create / connect / link) by inference. Mitigation: clear flags for explicit override (`/connect --new`, `/connect --link-only`).
- **`/draw` has subverbs** while other commands don't. Justified: visual artefacts are distinct file types and warrant the routing; no other command's domain has this level of internal divergence.

---

## Implementation outline (for the writing-plans phase)

1. **Author the new commands** — 6 new `*.md` command files in `obsidian-bridge/commands/`:
   - `connect.md`, `sync.md`, `check.md`, `draw.md`, `ramasse.md`, `iterate.md`
   - (`/dream` already exists, keep as-is)
2. **Update `vault-bridge` skill** — refactor pseudocode so it serves the new commands' needs:
   - `/connect` dispatches to: existing create/connect/link logic with inference
   - `/sync` dispatches to: existing sync + handoff sync logic combined
   - `/check` dispatches to: existing status logic + section filters
   - `/ramasse` dispatches to: existing reindex + housekeeping combined
   - `/iterate` dispatches to: existing iteration-set-status logic
3. **Author the `draw` skill OR fold into existing skills** — TBD: `/draw` could either (a) get its own thin `draw` skill that routes to `canvas`/`bases`/`mermaid`, or (b) just dispatch directly via the command body. Decide in implementation plan.
4. **Update plugin description** in `.claude-plugin/plugin.json`.
5. **Add deprecation notes** to old `commands/vault-bridge.md` and old `commands/dream.md` for one release cycle, then remove. Or remove immediately if no one but Tom uses this plugin (likely true today).
6. **Update `vault-bridge` skill body** with the `/iterate` sunset note.
7. **Update README** with the new command surface.
8. **Update `notes/mermaid-house-style.md`** (and any other notes) if they reference old command names.
9. **No hook changes needed.** Hooks already work on the underlying file operations, not on command names.
10. **Migration guide** — short doc in `notes/` mapping old → new for any users who have the existing surface in muscle memory.

## Open questions for the implementation plan

- Should `/draw` get its own thin skill (`draw`) that routes to canvas/bases/mermaid, or should the command body itself dispatch?
- Should the old `/vault-bridge` and `/dream` commands stay as deprecated aliases for one release cycle, or be removed in the same commit as the new surface?
- Should `/check` accept multiple sections (`/check iterations decisions`) or only one at a time?
- For `/connect`, what's the inference rule order? (path doesn't exist → create; path exists with Home.md → connect; path exists without Home.md → ?)

These get resolved during the implementation plan.

---

## Next step

User reviews this spec. On approval, transition to writing-plans to produce the implementation plan.
