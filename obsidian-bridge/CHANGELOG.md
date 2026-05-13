# Changelog

## 1.2.2 — 2026-05-11

**Harden vault-link discoverability — stop reprompting across sessions and projects.**

Three improvements so the "no vault linked" friction disappears once a project (or the user globally) is set up.

### Added

- **`CLAUDE.md` managed block** — `/connect` (and any breadcrumb-mutating op: `--link-only`, `create-project`, `set-type`, …) writes a managed block at the project root delimited by `<!-- begin obsidian-bridge -->` / `<!-- end obsidian-bridge -->`. The block lists vault, project, key paths, and a pointer to `vault-standards`. Claude Code auto-loads `CLAUDE.md` per session, so vault context now lives in native per-project memory — no SessionStart re-injection needed. Idempotent: rerunning `/connect` updates the block in place; everything outside the markers is left alone.
- **`/connect --user-default <path>`** — writes `~/.claude/obsidian-bridge` (user-level breadcrumb). Every project without its own breadcrumb falls back to this. One-time setup, stops the not-linked reminder everywhere. Project-level breadcrumbs always override.
- **Once-per-session reminder** — the `UserPromptSubmit` reminder drops a `.claude/.ob-reminded` sentinel after firing. Subsequent prompts in the same session skip the reminder. `SessionStart` clears the sentinel.
- **`~/.claude/obsidian-bridge` in the discovery chain** — added as step 3 (between cabinet-anchor-hint and `OB_DEFAULT_VAULT`). Both the SessionStart hook and the prompt-reminder hook respect it. `project_slug` is deliberately never inherited from the user-level breadcrumb (project_slug is always project-scoped).

### Changed

- **Reminder hook keyword pattern updated** — now matches the new 7-verb command surface (`/connect`, `/sync`, `/check`, `/dream`, `/ramasse`, `/draw`, `/iterate`) instead of the retired `/vault-bridge`.
- **`session-start-vault.sh`** — discovery chain renumbered to include user-level breadcrumb at step 3; old steps 3/4/5 shift by one.
- **`commands/connect.md`** — usage table updated for `--user-default`; CLAUDE.md integration noted.
- **`README.md`** — three new bullet points calling out CLAUDE.md integration, global default, once-per-session reminder.

### Behaviour

| Scenario | Before | Now |
|---|---|---|
| Project linked, vault keyword in prompt | No reminder | No reminder |
| Project not linked, vault keyword in 5 prompts in one session | 5 reminders | 1 reminder |
| Project not linked but `~/.claude/obsidian-bridge` exists | Reminder fires | No reminder |
| Across sessions, project remains linked | Hook re-injects context | `CLAUDE.md` already carries the context; hook is redundant but harmless |

## 1.2.1 — 2026-05-11

**Fix: bridge no longer wakes Obsidian when it's closed.**

Tom reported Obsidian opening and closing repeatedly during Claude sessions. Root cause: the bridge probed CLI availability by calling `obsidian version`, and the Obsidian CLI wakes the app to communicate with it. Every probe and every subsequent vault op was relaunching Obsidian.

### Fixed

- **`hooks/scripts/session-start-vault.sh`** — CLI detection now requires Obsidian to be currently running (`pgrep -i obsidian` or `ps -A | grep -i Obsidian`) before invoking `obsidian version`. If Obsidian is closed, `cli_available=no` and `mode=filesystem`; the CLI is never touched.
- **`references/vault-integration.md`** — `cli_available()` semantics updated: returns true only when binary is on PATH AND Obsidian is running. Hard rule added: never invoke the CLI as a probe when Obsidian is closed. Graceful-degradation note clarified — on mid-session CLI failure (user closed Obsidian), fall back to filesystem without retrying.
- **`skills/cli/SKILL.md`** — added a bridge-rule preamble: never invoke the CLI when Obsidian is closed. If not running, use filesystem ops or ask the user to open Obsidian. The bridge does not open or close the app on the user's behalf.

### Behaviour

- Obsidian open at session start → `mode=cli` (fast vault ops via Obsidian's index).
- Obsidian closed at session start → `mode=filesystem` (direct file ops, no CLI invocations, Obsidian stays closed).
- User opens Obsidian mid-session → no auto-switch to CLI; next session picks it up.
- User closes Obsidian mid-session → first failing CLI op transparently falls back to filesystem for the rest of the session.

## 1.2.0 — 2026-05-11

**Skill prose sharpening — heavy SKILL.md files slimmed via reference extraction.**

Pure polish pass. No API change, no schema change, no command surface change. Internal reorganisation of two skills to keep the trigger-time payload tight while preserving all content.

### Changed

- **`skills/vault-bridge/SKILL.md`** — 1223 → 674 lines (45% reduction). Tightened prose intros, DRY'd the repeated breadcrumb-read boilerplate, kept all command pseudocode. Extracted:
  - `references/CONVERSATIONAL_OPERATIONS.md` (245 lines) — `add-collection`, `archive`/`unarchive`, `set-type`, `templates`, `add-iteration`, `add-iteration-artefact`. These don't have slash commands and load on natural-language trigger; no need to ship them on every command dispatch.
  - `references/MIGRATION_V2_V3.md` (166 lines) — full v2 → v3 walkthrough. Rare, opt-in, conversational.
  - `references/HOUSEKEEPING_CHECKS.md` (64 lines) — the 16 housekeeping checks as a structured table, replacing the inline checklist in the `/ramasse housekeeping` flow.
  - Skill version bumped to `0.2.0`.
- **`skills/vault-standards/SKILL.md`** — 495 → 373 lines (25% reduction). Extracted:
  - `references/CONTENT_STYLE.md` (141 lines) — voice/tense/structure/callouts/cuts/acceptance-test rules + reference body shapes. Style is judgment, not validation; loads on demand.
  - Skill version bumped to `0.2.0`.
- **`notes/`** — moved the three `2026-05-04-command-surface-redesign-*` docs to `notes/archive/`. They describe a redesign that's already shipped (v1.1.0); kept as historical record. `mermaid-house-style.md` stays in place.

### Unchanged

- `skills/bases/SKILL.md` — upstream redistribution (MIT + CC BY 4.0, kepano/obsidian-skills); structure preserved out of respect for the source.
- All other skills, hooks, command files, templates, plugin description, and marketplace entry text.

## 1.1.1 — 2026-05-05

**Decouple bridge from cabinet specifics.**

Bridge can mention cabinet (interop is fine) but never expects it to be installed or accessible. This release scrubs the leakage points where bridge docs presumed cabinet's namespace, characters, or file conventions.

- `skills/vault-bridge/SKILL.md` — Default subfolder name when scaffolding a vault inside a non-empty dir is now neutral (`_vault/` suggested or ask the user). Was hardcoded `_cabinet/`.
- `skills/vault-standards/SKILL.md` — "Specialist Names (cabinet integration)" section replaced with "Specialist field (opaque to bridge)". No longer enumerates 8 cabinet-specific character names; bridge treats the field as opaque pass-through.
- `skills/dream/SKILL.md` — Removed cabinet specialist names from the chronicler-voice description and the auto-suggest mention. Now describes "companion plugin" behavior generically; cabinet is one possible companion.
- `references/vault-integration.md` — Cosmetic: example breadcrumb uses `MyVault`, not `Claude Cabinet`.
- `skills/mermaid/SKILL.md` — Cosmetic: removed "cabinet integration" from a Mermaid timeline example.

What still mentions cabinet (correctly framed as interop-tolerant, not required):
- Anchor chain step 2: `.cabinet-anchor-hint` fallback (gracefully absent)
- `Home.md` type accepts `vault-home | cabinet-home` (union, not requirement)
- "Cabinet detection — `crew/` folder present, untouched by bridge" (detect-and-yield, no dependency)
- Tag preservation: `cabinet/*` tags preserved alongside `ob/*` during migration
- README "pairs cleanly with cabinet-of-imd when both are installed"
- `# optional (cabinet)` annotations on optional fields (provenance hint, not requirement)

Non-breaking. No schema change. Existing vaults unaffected.

## 1.1.0 — 2026-05-04

**New optional schema field — `relations:` on project briefs.**

Encodes cross-project topology: `parents`, `children`, `related`, each a list of slug strings. Lets projects declare gating / spinoff / sibling relationships in frontmatter rather than ad-hoc in body text. Frontmatter takes slugs; body still uses wikilinks. Field is optional — existing briefs are unaffected.

- `vault-standards` — Brief frontmatter spec extended; note added on slug-vs-wikilink semantics.
- `vault-bridge` — housekeeping check #16 (relations referencing unknown slugs flagged as manual items).
- All four `brief-*` templates carry the field, initialised to empty lists.

Non-breaking. No migration required.

## 1.0.1 — 2026-05-04

Bug fix + content-style guide.

**Fix:**
- `hooks/hooks.json` — quoted `${CLAUDE_PLUGIN_ROOT}` in all 5 hook commands. Without quotes, hooks failed when the plugin path contained spaces (e.g. macOS installs under `~/Library/Application Support/...`). Symptom: `python3: can't open file '/Users/.../Library/Application'`.

**vault-standards skill expanded:**
- Doc schema clarified — explicit definition of what a doc IS (evergreen, singleton, no date in filename) plus common examples (`MANIFESTO.md`, `STACK.md`, `STYLE.md`, etc.).
- New "Doc vs Decision — disambiguation" subsection — criteria table, the "When was this decided?" test, and worked examples. `/dream` will flag suspected mismatches.
- New "Content style" section — voice/tense rules, structure rules, callout usage, words to delete, acceptance-test friendly principle, and reference body shapes per file type. Designed for both AI and human readers.

## 1.0.0 — 2026-05-04

First stable release. Major surface redesign + skill expansion.

**Breaking changes:**
- The `/vault-bridge` command is removed. Replaced by 6 opinionated top-level verbs: `/connect`, `/sync`, `/check`, `/draw`, `/ramasse`, `/iterate` (plus `/dream`, unchanged).
- The anchor file moved from `$CLAUDE_PROJECT_DIR/.obsidian-bridge` to `$CLAUDE_PROJECT_DIR/.claude/obsidian-bridge`. **Auto-migrated silently** by the SessionStart hook on first session — no user action required.

**New commands (6 verbs):**
- `/connect [path]` — onboard vault + project (replaces create / connect / link / create-project).
- `/sync` — push state to vault (combines sync + handoff sync).
- `/check [section]` — read-only summary; sections: iterations, decisions, sessions, handoff, tags.
- `/draw <subverb>` — visual artefacts; subverbs `canvas <name>`, `base <name>`, `diagram [type]` route to the canvas / bases / mermaid skills.
- `/ramasse` — tidy (combines reindex + housekeeping). French verb for "pick up / gather."
- `/iterate <id> <status>` — iteration state transitions. **May be sunset** in a future release if conversational handling proves robust.

**Conversational operations:**
Operations that lost their slash-command (add-collection, archive/unarchive, set-type, templates, add-iteration, add-iteration-artefact, iteration listing, schema migration) are now invoked conversationally. The `vault-bridge` skill body documents the trigger phrases and dispatches to existing pseudocode.

**New skills:**
- `obsidian-bridge:canvas` — JSON Canvas v1 reference (the `.canvas` file format).
- `obsidian-bridge:search` — Obsidian search query syntax (operators, property filters, regex, embedded `query` blocks).
- `obsidian-bridge:vault-standards` — promoted from a reference doc to an active skill that auto-loads when frontmatter is being written. Single source of truth for the schema.
- `obsidian-bridge:mermaid` — diagram syntax reference, plus a new `references/GENERATION_RULES.md` covering topology / labels / direction / styling discipline for *generating* diagrams.
- Imported four upstream skills from `kepano/obsidian-skills` (via antigravity-awesome-skills, MIT + CC BY 4.0): `bases`, `markdown`, `cli`, `clipper-template`. With schema-gate preambles deferring to `vault-standards` when in a bridge vault.

**New hook behaviours:**
- `SessionStart` step 0: silent auto-migration of legacy anchor + `.gitignore` rewrite.
- `UserPromptSubmit`: smart keyword-gated reminder (no longer fires on every turn when no vault is linked).
- `PostToolUse` (Write/Edit): validates vault-file frontmatter against `vault-standards`. Auto-bumps `updated:`, warns on missing `type:` / `ob/` tag / markdown-link-to-`.md`. Non-blocking.
- `PreCompact`: mirrors `.remember/remember.md` → vault `_handoff.md` before context compaction. Preserves human-edited content above a marker line.

**Other:**
- Migration guide at `notes/2026-05-04-command-surface-redesign-migration.md` maps every old command to its new equivalent.
- Plugin description rewritten to mention canvas / bases / mermaid know-how.
- README rewritten around the 7-verb surface.
- ATTRIBUTIONS.md credits upstream sources (kepano/obsidian-skills, antigravity-awesome-skills, Obsidian Help vault, JSON Canvas spec).

## 0.1.0 — 2026-04-30

Initial release. Extracted from `cabinet-of-imd` v2.2.0.

- Plugin scaffold with commands, skills, hooks, references, templates.
- Vault schema v3: type-shaped projects (`coding`, `knowledge`, `plugin`, `tinkerage`).
- `/vault-bridge` command: create, connect, link, create-project, add-collection, sync, status, archive, unarchive, reindex, housekeeping, migrate, set-type, templates, iterations, handoff.
- `/dream` command: Pass 1 (structural sanitation) + Pass 2 (content analysis).
- SessionStart hook with vault discovery and context injection.
- SessionEnd hook with optional remember handoff nudge.
- 13 vault templates.
- v2 → v3 migration command.
- Remember plugin integration (handoff sync).
