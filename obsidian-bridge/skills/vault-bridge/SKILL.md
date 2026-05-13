---
name: vault-bridge
description: Operate the Obsidian vault. Dispatched by /connect, /sync, /check, /draw, /ramasse, /iterate. Handles vault setup, project scaffolding, sync, status, cleanup, visual-artefact discovery, iteration state, and conversational vault ops.
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
version: 0.2.0
---

Bridge between Claude Code sessions and a persistent Obsidian vault.
This skill handles explicit vault operations and the conversational
ones the command surface deliberately doesn't expose.

## Vault structure (v3)

Full structure, frontmatter schemas, naming rules, wikilinks, and
tag taxonomy live in the `obsidian-bridge:vault-standards` skill.
Key paths:

- `projects/{slug}/brief.md` — type-shaped project brief
- `projects/{slug}/decisions/`, `sessions/`, `notes/`, `iterations/`
- `archive/{slug}/` — archived projects (same shape)
- `Home.md` — auto-rebuilt vault home

Subfolder defaults vary by `project_type` (`coding`, `knowledge`,
`plugin`, `tinkerage`) — see `vault-standards` § Per-Type Project
Subfolder Defaults.

## Vault primitives

All vault operations go through the `vault.*` abstraction in
`references/vault-integration.md`. CLI-first: prefer Obsidian CLI
for every op it supports; filesystem fallback when unavailable.

```pseudocode
FUNCTION vault_op(op, args):
    IF cli_available():  RUN via obsidian CLI
    ELSE:                RUN via filesystem (Read/Write/Glob/Grep)
```

---

## Anchor / breadcrumb file

Per-project link to a vault, key=value, used by every operation and
every hook (SessionStart, UserPromptSubmit, PostToolUse, PreCompact).

**Canonical:** `$CLAUDE_PROJECT_DIR/.claude/obsidian-bridge`
**Legacy:**    `$CLAUDE_PROJECT_DIR/.obsidian-bridge` — auto-migrated by SessionStart hook step 0.

```
vault_path=/absolute/path/to/vault
vault_name=basename
project_slug=optional-slug
linked_at=YYYY-MM-DD
mode=cli|filesystem
```

**Discovery chain (in order, first hit wins):**

1. `$CLAUDE_PROJECT_DIR/.claude/obsidian-bridge` — project-level breadcrumb.
2. `$CLAUDE_PROJECT_DIR/.cabinet-anchor-hint` — cabinet plugin interop.
3. `~/.claude/obsidian-bridge` — **user-level default**. Set once, applies everywhere a project hasn't overridden it. `project_slug` is never inherited from this file (always project-scoped).
4. `$OB_DEFAULT_VAULT` env var — legacy global fallback.
5. Walk parent dirs (≤5) for `Home.md` with `type: vault-home` or `cabinet-home`.

**Read pattern (every op):** walk the chain, take the first hit.

**Write pattern (project-level):**
1. `mkdir -p $CLAUDE_PROJECT_DIR/.claude`
2. Write `$CLAUDE_PROJECT_DIR/.claude/obsidian-bridge`
3. Append `.claude/obsidian-bridge` to `.gitignore` if not present.
4. **Refresh `CLAUDE.md` managed block** (see below).
5. Legacy cleanup is handled by the SessionStart hook — not here.

**User-level default — explicit setup:**
- `/connect --user-default <path>` writes `~/.claude/obsidian-bridge` instead of the project breadcrumb. After that, any project without its own breadcrumb falls back to it. Stops the "no vault linked" reminder across all projects.

---

## CLAUDE.md managed block

For decent per-project memory, `/connect` (and `/sync`, `set-type`,
any op that mutates breadcrumb state) **refreshes a managed block in
`CLAUDE.md`** at the project root. This gives Claude Code's native
per-project memory layer the vault context — no re-injection from
hooks needed each session.

### Marker format

```markdown
<!-- begin obsidian-bridge -->
## Obsidian Bridge

- **Vault:** `<vault_name>` at `<vault_path>` (mode: `<cli|filesystem>`)
- **Project:** `<project_slug>` (type: `<project_type>`, status: `<status>`)
- **Decisions:** `projects/<slug>/decisions/YYYY-MM-DD-{slug}.md`
- **Sessions:** `projects/<slug>/sessions/YYYY-MM-DD.md`
- **Standards:** invoke `obsidian-bridge:vault-standards` for the canonical schema.
<!-- end obsidian-bridge -->
```

### Update algorithm

```pseudocode
FUNCTION refresh_claude_md(project_dir, breadcrumb):
    claude_md = "{project_dir}/CLAUDE.md"
    new_block = render_block(breadcrumb)        // BEGIN … content … END
    existing  = read claude_md (empty if absent)

    IF existing contains "<!-- begin obsidian-bridge -->":
        // Replace in place — everything between markers, markers included
        new_content = regex_replace(existing,
                                    r'<!-- begin obsidian-bridge -->.*?<!-- end obsidian-bridge -->',
                                    new_block,
                                    dotall=True)
    ELSE:
        // Append at the end with a leading blank line
        new_content = existing.rstrip() + "\n\n" + new_block + "\n"

    write claude_md(new_content)
```

### Removal

To unlink: delete `$CLAUDE_PROJECT_DIR/.claude/obsidian-bridge` and
strip the managed block from `CLAUDE.md` (everything between the
markers, inclusive). No `/unlink` command exists yet — manual edits
are fine; the markers make the boundary unambiguous.

---

## /connect — onboard

Combined entry for create + connect + link + create-project.
Inference rules:

| Path state | Action |
|---|---|
| Path doesn't exist | **Create** new vault (scaffold Home.md, projects/, templates/) |
| Path exists with `Home.md` (`type: vault-home` or `cabinet-home`) | **Connect** (read-only verification) |
| Path exists with `projects/` folder, no Home.md | **Connect** (best-effort) |
| Path exists with neither | **Error**: "Expected Home.md with type: vault-home or a projects/ folder" |

**Subforms:**

| Form | Behaviour |
|---|---|
| `/connect` | Discover or prompt for path |
| `/connect <path>` | Infer create vs connect from path state |
| `/connect <path> <slug>` | Connect AND link to project `<slug>` |
| `/connect --new <path>` | Force-create (error if path is non-empty and not a vault) |
| `/connect --link-only <slug>` | Set slug only; vault must already be connected |
| `/connect --user-default <path>` | Set `~/.claude/obsidian-bridge` as a global default vault. Applies to every project that doesn't have its own breadcrumb. |

```pseudocode
PARSE flags + positional args
breadcrumb = read canonical anchor

CASE invocation:
  --link-only <slug>:       → link subform
  --new <path>:             → create subform (force)
  --user-default <path>:    → user-default subform
  <path>:
    IF path doesn't exist:                                   → create
    ELIF path/Home.md exists with vault-home|cabinet-home:    → connect
    ELIF path/projects/ exists:                              → connect (best-effort)
    ELSE: ERROR
  <path> <slug>:
    Run path-inference flow above to ensure connect, then run link <slug>
  no args:
    IF breadcrumb exists: REPORT current vault + project (read-only summary)
    ELSE:                 PROMPT for vault path
```

### User-default subform — set the global vault fallback

```pseudocode
path = resolve(user-provided path)

// Validate the path is a real vault (loose check — Home.md or projects/)
IF NOT exists path: ERROR "Path does not exist: {path}"
IF NOT (exists {path}/Home.md OR exists {path}/projects/):
    ERROR "No vault detected at {path}. Expected Home.md or projects/ folder."

mkdir -p "${HOME}/.claude"
WRITE "${HOME}/.claude/obsidian-bridge":
    vault_path={path}
    vault_name={basename(path)}
    linked_at={TODAY}
    mode={cli IF cli_available() ELSE filesystem}

// NOTE: project_slug is deliberately omitted — it's always project-scoped.

REPORT: "User-level default vault set: {path}. Every project without its own breadcrumb will fall back to this. The 'no vault linked' reminder will no longer fire globally."
```

### Create subform — scaffold a new v3 vault

```pseudocode
IF user provides path: vault_path = resolve(path)
ELSE:                  REQUEST path from user

IF non-empty dir AND not an Obsidian vault:
    offer subfolder mode (suggest `_vault/` or ask user) or a new location
ELSE:
    base = vault_path

mkdir -p projects, archive, templates
COPY templates from plugin examples/vault-templates/ to {base}/templates/
CREATE Home.md from home.md template (set updated: TODAY)
CREATE projects/_index.md from projects-index.md template

mode       = "cli" IF cli_available() ELSE "filesystem"
vault_name = basename(vault_path)

WRITE breadcrumb:
    vault_path={base}, vault_name={vault_name},
    project_slug=, linked_at={TODAY}, mode={mode}

IF .gitignore exists AND NOT contains ".claude/obsidian-bridge":
    APPEND ".claude/obsidian-bridge" to .gitignore

refresh_claude_md(project_dir, breadcrumb)   // see § CLAUDE.md managed block

REPORT: "Vault created at {base}. Transport: {mode}. Run /connect <path> <slug> to scaffold your first project."
```

### Connect subform — point at an existing vault

```pseudocode
path = resolve(user-provided path)

// 1. Detect vault
IF path contains Home.md with type: vault-home OR cabinet-home: base = path
ELIF path/projects/ exists:                                    base = path
ELSE: ERROR "No vault found at this path. Expected Home.md with type: vault-home or a projects/ folder."

// 2. Schema version
has_project_type = any brief in projects/ contains "project_type:"
IF has_project_type:                                                   version = "v3"
ELIF any project has brief.md + decisions/ + sessions/:                version = "v2"
ELSE:                                                                  version = "unknown"

// 3. Transport
mode       = "cli" IF cli_available() ELSE "filesystem"
vault_name = (cli_available() AND detect_vault_name()) OR basename(path)

// 4. Inventory
FOR each project dir in base/projects/:
    count decisions, sessions
    read brief status and project_type
    REPORT: slug, type, status, decisions, sessions

// 5. Write breadcrumb (no project_slug yet)
WRITE breadcrumb:
    vault_path={base}, vault_name={vault_name},
    project_slug=, linked_at={TODAY}, mode={mode}

// 6. .gitignore housekeeping
IF .gitignore exists AND NOT contains ".claude/obsidian-bridge":
    APPEND ".claude/obsidian-bridge" to .gitignore

// 7. Refresh CLAUDE.md managed block — see § CLAUDE.md managed block
refresh_claude_md(project_dir, breadcrumb)

// 8. Cabinet detection
IF base/crew/ exists:
    REPORT: "Cabinet detected — crew/ folder present, untouched by bridge."

IF version == "v2":
    SUGGEST: "Run vault migration to convert to v3 schema."

REPORT: "Connected to {vault_name} at {base}. Schema: {version}. Transport: {mode}."
```

### Link subform — set project slug

```pseudocode
slug       = user-provided slug
vault_path = read vault_path from breadcrumb (canonical-then-legacy)
IF NOT breadcrumb: ERROR "No vault connected. Run /connect <path> first."

IF NOT exists {vault_path}/projects/{slug}/brief.md:
    available = list dirs in {vault_path}/projects/
    ERROR "Project '{slug}' not found. Available: {available}"

UPDATE breadcrumb: project_slug={slug}, linked_at={TODAY}

project_type = read project_type from brief.md
status       = read status from brief.md

refresh_claude_md(project_dir, breadcrumb)   // see § CLAUDE.md managed block

REPORT: "Linked to project '{slug}' (type: {project_type}, status: {status})."
```

### Create-project subform — scaffold a type-shaped project

Requires `<slug>` and `<type>`. Asks if either is omitted. Validates
slug (lowercase, hyphenated, no spaces, no dots).

```pseudocode
slug         = validate_slug(user-provided slug)
project_type = validate_type(user-provided type)    // coding | knowledge | plugin | tinkerage

vault_path = read vault_path from breadcrumb
IF NOT vault_path: ERROR "No vault connected."

project_dir = {vault_path}/projects/{slug}
IF exists project_dir: ERROR "Project '{slug}' already exists."

// 1. Directory
mkdir {project_dir}

// 2. Brief from type-shaped template
template = read examples/vault-templates/brief-{project_type}.md
brief    = template with:
    slug: {slug}, aliases: [{slug}],
    created: {TODAY}, updated: {TODAY}
    # Title set to slug (user can rename)
vault.write("projects/{slug}/brief.md", brief)

// 3. Type-specific subfolders + _index.md
MATCH project_type:
  "coding":
    FOR f IN [decisions, notes, tasks, references, sessions, images]: mkdir {project_dir}/{f}
    FOR f IN [decisions, notes, tasks, references]:
        vault.write("projects/{slug}/{f}/_index.md", collection_index(slug, f))

  "plugin":
    FOR f IN [decisions, notes, tasks, references, releases, sessions, images]: mkdir {project_dir}/{f}
    FOR f IN [decisions, notes, tasks, references, releases]:
        vault.write("projects/{slug}/{f}/_index.md", collection_index(slug, f))

  "knowledge":
    FOR f IN [notes, sources, references, sessions]: mkdir {project_dir}/{f}
    FOR f IN [notes, sources, references]:
        vault.write("projects/{slug}/{f}/_index.md", collection_index(slug, f))

  "tinkerage":
    mkdir {project_dir}/sessions

// 4. Vault-level index rebuilds
REBUILD projects/_index.md from all project briefs
RUN update_home()

// 5. Breadcrumb update
UPDATE breadcrumb: project_slug={slug}
refresh_claude_md(project_dir, breadcrumb)   // see § CLAUDE.md managed block

// 6. Codebase scaffold (if applicable)
IF git root OR $CLAUDE_PROJECT_DIR is a code project:
    mkdir -p assets, concepts, previews in codebase root (if not exists)

REPORT: "Project '{slug}' scaffolded as {project_type}. Folders: [list]. Brief at projects/{slug}/brief.md."


FUNCTION collection_index(slug, folder_name):
    RETURN template from examples/vault-templates/collection-index.md with:
        project: "[[projects/{slug}/brief|{slug}]]"
        title:   capitalize(folder_name)
```

---

## /sync — push state

Combined brief + handoff sync.

| Form | Action |
|---|---|
| `/sync` | Brief, then handoff (sequential) |
| `/sync brief` | Brief only |
| `/sync handoff` | Handoff only |

### Brief subform

```pseudocode
vault_path   = read vault_path from breadcrumb
project_slug = read project_slug from breadcrumb
IF NOT project_slug: ERROR "No project linked."

brief_path = "projects/{project_slug}/brief.md"

// Build brief content from current session context:
//   overview, tech stack, constraints, work notes, milestones, user decisions

IF vault.exists(brief_path):
    existing = vault.read(brief_path)
    ASK: "Brief exists. Merge (preserve existing, update changed sections) or overwrite?"
    IF merge:
        merged = merge_briefs(existing, session_context)
        vault.write(brief_path, merged)
    ELSE:
        vault.write(brief_path, new_brief)
ELSE:
    vault.write(brief_path, new_brief)

vault.property_set(brief_path, "updated", TODAY)
REBUILD projects/_index.md
RUN update_home()

REPORT: "Brief synced for '{project_slug}'."
```

### Handoff subform — mirror `.remember/remember.md` → `_handoff.md`

Light integration with the `remember` plugin. See
`references/remember-integration.md`.

```pseudocode
vault_path   = read vault_path from breadcrumb
project_slug = read project_slug from breadcrumb
IF NOT project_slug: ERROR "No project linked."

remember_file = $CLAUDE_PROJECT_DIR/.remember/remember.md
IF NOT exists remember_file: ERROR "No .remember/remember.md found in project directory."

content = read remember_file

handoff = """
---
type: handoff
project: "[[projects/{project_slug}/brief|{project_slug}]]"
updated: {TODAY}
source: remember
tags:
  - ob/handoff
---

# Handoff — {project_slug}

*Mirrored from `.remember/remember.md` on {TODAY}.*

---

{content}
"""

vault.write("projects/{project_slug}/_handoff.md", handoff)
REPORT: "Handoff synced for '{project_slug}'. Mirrored {line_count} lines from remember.md."
```

---

## /check — read-only

Status, handoff status, iterations, decisions, sessions, tags — with
optional sections. Multi-section: `/check iterations decisions`
returns both.

| Form | Output |
|---|---|
| `/check` | Full vault summary |
| `/check handoff` | Handoff section only |
| `/check iterations [--all]` | Iteration listing |
| `/check decisions [--all]` | Recent decisions |
| `/check sessions` | Recent sessions |
| `/check tags` | Tag taxonomy summary |

### Default `/check` — full status

```pseudocode
vault_path = read vault_path from breadcrumb
vault_name = read vault_name from breadcrumb
mode       = read mode       from breadcrumb

REPORT header: "Vault: {vault_name} at {vault_path}"
REPORT: "Transport: {mode}"
IF mode == "cli":
    cli_ver = run "obsidian version"
    REPORT: "CLI version: {cli_ver}"

// Schema version
has_v3 = any brief has project_type field
has_v2 = any brief lacks project_type field
IF has_v3 AND has_v2: version_note = "v3 (mixed — some v2 projects remain)"
ELIF has_v3:          version_note = "v3"
ELSE:                 version_note = "v2"
REPORT: "Schema: {version_note}"

// Per-project inventory
FOR each project dir in {vault_path}/projects/:
    slug         = dirname
    brief        = read brief.md frontmatter
    decisions    = count files in decisions/
    sessions     = count files in sessions/
    last_session = most recent session filename date
    REPORT row: "  {slug} — {brief.project_type or 'unknown'} — {brief.status} — {decisions}d {sessions}s — last: {last_session}"

FOR each dir in {vault_path}/archive/:
    REPORT: "  [archived] {dirname}"

IF {vault_path}/crew/ exists:
    REPORT: "Cabinet: detected — crew/ folder present, untouched by bridge."

IF $CLAUDE_PROJECT_DIR/.remember/ exists:
    IF _handoff.md exists for current project:
        REPORT: "Remember: detected — last handoff sync: {read from _handoff.md frontmatter}"
    ELSE:
        REPORT: "Remember: detected — no handoff yet."

issues = quick_scan_for_drift()    // briefs missing project_type, collections without _index, etc.
IF issues > 0:
    REPORT: "Drift: {issues} issues detected. Run /dream for details."
```

### Handoff subform — show last sync time

```pseudocode
vault_path   = read vault_path from breadcrumb
project_slug = read project_slug from breadcrumb

remember_file = $CLAUDE_PROJECT_DIR/.remember/remember.md
handoff_file  = {vault_path}/projects/{project_slug}/_handoff.md

IF NOT exists remember_file: REPORT: "No .remember/remember.md found." RETURN

IF vault.exists("projects/{project_slug}/_handoff.md"):
    handoff_date = vault.property_read("projects/{project_slug}/_handoff.md", "updated")
    IF mtime(remember_file) > mtime(handoff_file):
        REPORT: "Handoff: stale. Last sync: {handoff_date}. remember.md updated since."
    ELSE:
        REPORT: "Handoff: current. Last sync: {handoff_date}."
ELSE:
    REPORT: "Handoff: never synced. Run /sync handoff."
```

### Iterations subform — list iterations grouped by track

```pseudocode
slug       = user-provided slug OR read project_slug from breadcrumb
tree_flag  = optional --tree flag
vault_path = read vault_path from breadcrumb

iter_dir = {vault_path}/projects/{slug}/iterations
IF NOT exists iter_dir: REPORT "No iterations for project '{slug}'." RETURN

iterations = []
FOR each entry in iter_dir (excluding _index.md):
    IF entry is .md file:                       fm = read frontmatter
    ELIF entry is folder with _iteration.md:    fm = read _iteration.md frontmatter
    ELSE: SKIP
    iterations.add({
        identifier: fm.identifier, status: fm.status, date: fm.date,
        track: fm.track OR "Loose", register: fm.register,
        supersedes: fm.supersedes, builds_on: fm.builds_on,
        filename: entry name
    })

tracks = group iterations by track
sort tracks by most recent iteration date (descending)

FOR each track:
    REPORT: "## Track: {track_name}"
    FOR each iteration in track (sorted by date):
        REPORT: "  [{iteration.identifier}] {iteration.filename} — {iteration.status}"
        IF iteration.register: REPORT: "      {iteration.register}"

IF tree_flag:
    REPORT: "\n## Lineage"
    FOR each iteration with supersedes or builds_on:
        REPORT: "  {identifier} → supersedes {target}" or "  {identifier} ← builds on {ancestor}"
```

---

## /ramasse — tidy

Combined reindex + housekeeping.

| Form | Action |
|---|---|
| `/ramasse` | Full sweep (indexes + housekeeping) |
| `/ramasse --dry-run` | Show what would change; don't write |
| `/ramasse indexes` | Reindex only |
| `/ramasse housekeeping` | Consistency check only |

### Indexes subform — rebuild all `_index.md` from disk

```pseudocode
vault_path = read vault_path from breadcrumb

// 1. projects/_index.md
projects = list dirs in {vault_path}/projects/
FOR each project:
    read brief frontmatter (slug, status, project_type, created, updated)
    count decisions, sessions
    find latest session date
WRITE projects/_index.md with table rows

// 2. Per-project collection indices
FOR each project dir:
    FOR each subfolder that is a collection (≥2 .md siblings, not sessions/images/assets/):
        IF _index.md missing: CREATE from collection-index template
        REBUILD _index.md from folder contents
            (chronologically if filenames have dates, else alphabetically)

// 3. iterations/_index.md (if exists)
FOR each project with iterations/:
    group by track, sort by date within track
    WRITE iterations/_index.md with track grouping and status badges

// 4. Home.md
RUN update_home()

REPORT: "Reindexed {N} projects, rebuilt {M} _index.md files."
```

### Housekeeping subform — full consistency check

Runs 16 structural and content checks. Full check list with triggers
and resolutions in `references/HOUSEKEEPING_CHECKS.md`. Auto-fixes
safe items (with prompt: fix all / pick / skip). Reports manual items.

```pseudocode
vault_path   = read vault_path from breadcrumb
project_slug = read project_slug from breadcrumb

scope = [project_slug] IF project_slug ELSE list all project slugs

auto_fixes   = []
manual_items = []

FOR each slug in scope:
    RUN the 16 checks (see references/HOUSEKEEPING_CHECKS.md)
    Each check adds to auto_fixes or manual_items as defined.

REPORT:
    "## Auto-fixable ({auto_fixes.count})"
    list auto_fixes
    "[Fix all] [Pick] [Skip]"
    ""
    "## Needs decision ({manual_items.count})"
    list manual_items

IF user chooses "Fix all": run all auto_fixes sequentially.
IF "Pick":                 present each, user approves/skips.
IF "Skip":                 done.
```

---

## /draw — list visual artefacts

The `/draw` command in `commands/draw.md` has subverbs that route to
specialised skills:

| Subverb | Skill |
|---|---|
| `/draw canvas <name>` | `obsidian-bridge:canvas` |
| `/draw base <name>` | `obsidian-bridge:bases` |
| `/draw diagram [type]` | `obsidian-bridge:mermaid` |

The bare `/draw` form lists artefacts in the current project — that
flow lives here.

```pseudocode
breadcrumb = read $CLAUDE_PROJECT_DIR/.claude/obsidian-bridge
IF NOT breadcrumb: ERROR "No vault connected. Run /connect first."

vault_path   = read vault_path from breadcrumb
project_slug = read project_slug from breadcrumb
scope        = "project: {project_slug}" IF project_slug ELSE "vault-wide"

IF project_slug:
    base     = {vault_path}/projects/{project_slug}
    canvases = glob {base}/**/*.canvas
    bases    = glob {base}/**/*.base
    diagrams = grep -lE '^```mermaid' {base}/**/*.md
ELSE:
    canvases = glob {vault_path}/**/*.canvas (excluding archive/)
    bases    = glob {vault_path}/**/*.base   (excluding archive/)
    diagrams = grep -lE '^```mermaid' {vault_path}/**/*.md (excluding archive/)

REPORT: "Visual artefacts ({scope}):"
REPORT canvases:  none OR top 10 by mtime
REPORT bases:     none OR full list
REPORT diagrams:  none OR top 10 by mtime

REPORT: "(Use `/draw canvas|base|diagram <name>` to create. See obsidian-bridge:canvas / :bases / :mermaid skills for syntax.)"
```

---

## /iterate — state transitions

Set the status of an iteration. Mechanical, deliberate — replaces the
old `iteration-set-status`. Valid statuses: `drafting`, `on-shelf`,
`picked`, `parked`, `rejected`, `superseded`.

> **Sunset note.** `/iterate` exists for state-machine reliability.
> Iteration *creation* and *listing* are conversational ("new
> iteration D for foo on navy track", "show on-shelf iterations").
> If conversational state transitions prove robust across model
> versions, `/iterate` may be sunset in a future release.

| Form | Target |
|---|---|
| `/iterate <id> <status>` | Current project |
| `/iterate <slug>:<id> <status>` | Explicit slug |

```pseudocode
iter_id    = user-provided identifier
new_status = validate(user-provided status)    // drafting | on-shelf | picked | parked | rejected | superseded

vault_path   = read vault_path from breadcrumb
project_slug = read project_slug from breadcrumb
iter_dir     = {vault_path}/projects/{project_slug}/iterations

iter_file = find iteration file by identifier
IF NOT found: ERROR "Iteration '{iter_id}' not found."

vault.property_set(iter_file, "status", new_status)

// "picked" → optionally supersede same-track siblings
IF new_status == "picked":
    track = vault.property_read(iter_file, "track")
    IF track:
        siblings = other iterations on same track AND status NOT IN [rejected, superseded]
        IF siblings.length > 0:
            ASK: "Mark {siblings.length} sibling(s) on track '{track}' as superseded?"
            IF yes:
                FOR each: vault.property_set(sibling.file, "status", "superseded")

REBUILD iterations/_index.md
REPORT: "Iteration {iter_id} status set to {new_status}."
```

---

## Conversational operations

The new command surface deliberately doesn't expose every vault op
as a slash command. The model handles these conversationally when
the user describes intent. Full pseudocode in
`references/CONVERSATIONAL_OPERATIONS.md`:

| Op | Example phrasing |
|---|---|
| `add-collection` | "add a tasks/ folder to foo" |
| `archive` / `unarchive` | "archive foo", "restore bar" |
| `set-type` | "change foo to plugin type" |
| `templates` | "show me the brief template for coding" |
| `add-iteration` | "new iteration D for foo on navy track" |
| `add-iteration-artefact` | "attach concept.png to iter D" |

---

## Migration

Vault migration (v2 → v3) is conversational. **Trigger:** "migrate
this vault to v3". Full walkthrough in
`references/MIGRATION_V2_V3.md`. Idempotent — re-running on v3 acts
as housekeeping.

Anchor migration (`.obsidian-bridge` → `.claude/obsidian-bridge`) is
**silent and automatic** via the `SessionStart` hook step 0.

---

## See also

- `obsidian-bridge:vault-standards` — schema, naming, tags, brief blocks
- `references/vault-integration.md` — `vault.*` primitives, fallback rules
- `references/remember-integration.md` — handoff sync detail
- `references/CONVERSATIONAL_OPERATIONS.md` — conversational op pseudocode
- `references/MIGRATION_V2_V3.md` — v2 → v3 walkthrough
- `references/HOUSEKEEPING_CHECKS.md` — the 16 housekeeping checks
