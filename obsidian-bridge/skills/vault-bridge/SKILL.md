---
name: vault-bridge
description: Connect, create, scaffold, or manage the Obsidian vault. Use for setting up vaults, scaffolding projects, syncing briefs, running housekeeping, managing iterations, migrating from v2, and handoff operations.
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
version: 0.1.0
---

Bridge between Claude Code sessions and a persistent Obsidian vault. This skill handles explicit vault operations — creating, connecting, scaffolding, syncing, archiving, housekeeping, iterations, migration, and handoff. Vault interactions outside of explicit `/vault-bridge` commands should be silent and automatic.

## Vault Structure (v3)

Full structure, frontmatter schemas, naming rules, wikilink conventions, and tag taxonomy are in `references/vault-standards.md`. Key paths:

- `projects/{slug}/brief.md` — project brief (type-shaped by `project_type`)
- `projects/{slug}/decisions/` — decision records
- `projects/{slug}/sessions/` — session summaries
- `projects/{slug}/notes/` — general notes
- `projects/{slug}/iterations/` — design/code iterations (opt-in)
- `archive/{slug}/` — archived projects (same shape)
- `Home.md` — auto-rebuilt vault home

Subfolder defaults vary by project type (`coding`, `knowledge`, `plugin`, `tinkerage`) — see `vault-standards.md § Per-Type Project Subfolder Defaults`.

## Vault Primitives

All vault operations go through the `vault.*` abstraction defined in `references/vault-integration.md`. CLI-first policy: prefer Obsidian CLI for every operation it supports. Filesystem fallback when CLI unavailable.

```pseudocode
FUNCTION vault_op(op, args):
    IF cli_available():
        RUN via obsidian CLI
    ELSE:
        RUN via filesystem (Read/Write/Glob/Grep)
```

Read `references/vault-integration.md` for the full operation table and fallback rules.

---

## Commands

### create — Scaffold a new v3 vault

```pseudocode
IF user provides path: vault_path = resolve(path)
ELSE: REQUEST path from user

IF non-empty dir AND not an Obsidian vault:
    offer subfolder mode (_cabinet/) or new location
ELSE:
    base = vault_path

mkdir -p projects, archive, templates
COPY templates from plugin examples/vault-templates/ to {base}/templates/
CREATE Home.md from home.md template (set updated: TODAY)
CREATE projects/_index.md from projects-index.md template

// Detect transport
IF cli_available():
    mode = "cli"
    vault_name = basename(vault_path)
ELSE:
    mode = "filesystem"
    vault_name = basename(vault_path)

// Write breadcrumb
WRITE $CLAUDE_PROJECT_DIR/.obsidian-bridge:
    vault_path={base}
    vault_name={vault_name}
    project_slug=
    linked_at={TODAY}
    mode={mode}

// Add to .gitignore if not present
IF .gitignore exists AND NOT contains ".obsidian-bridge":
    APPEND ".obsidian-bridge" to .gitignore

REPORT: "Vault created at {base}. Transport: {mode}. Run /vault-bridge create-project <slug> <type> to scaffold your first project."
```

### connect — Point at an existing vault

```pseudocode
path = resolve(user-provided path)

// 1. Detect vault
IF path contains Home.md with type: vault-home OR type: cabinet-home:
    base = path
ELIF path/projects/ exists:
    base = path
ELSE:
    ERROR "No vault found at this path. Expected Home.md with type: vault-home or a projects/ folder."

// 2. Detect schema version
has_project_type = false
FOR each project dir in base/projects/:
    IF brief.md exists AND contains "project_type:":
        has_project_type = true
        BREAK

IF has_project_type:
    version = "v3"
ELIF any project has brief.md + decisions/ + sessions/:
    version = "v2"
ELSE:
    version = "unknown"

// 3. Detect transport
IF cli_available():
    mode = "cli"
    vault_name = detect_vault_name() OR basename(path)
ELSE:
    mode = "filesystem"
    vault_name = basename(path)

// 4. Inventory
FOR each project dir in base/projects/:
    count decisions, sessions
    read brief status and project_type
    REPORT: slug, type, status, decisions, sessions

// 5. Write breadcrumb (no project_slug yet — user links separately)
WRITE $CLAUDE_PROJECT_DIR/.obsidian-bridge:
    vault_path={base}
    vault_name={vault_name}
    project_slug=
    linked_at={TODAY}
    mode={mode}

// 6. Add to .gitignore if needed
IF .gitignore exists AND NOT contains ".obsidian-bridge":
    APPEND ".obsidian-bridge" to .gitignore

// 7. Cabinet detection
IF base/crew/ exists:
    REPORT: "Cabinet detected — crew/ folder present, untouched by bridge."

IF version == "v2":
    SUGGEST: "Run /vault-bridge migrate to convert to v3 schema."

REPORT: "Connected to {vault_name} at {base}. Schema: {version}. Transport: {mode}."
```

### link — Set project slug for current directory

```pseudocode
slug = user-provided slug
breadcrumb = $CLAUDE_PROJECT_DIR/.obsidian-bridge

IF NOT exists breadcrumb:
    ERROR "No vault connected. Run /vault-bridge connect <path> first."

// Read existing breadcrumb
vault_path = read vault_path from breadcrumb

// Validate slug exists
IF NOT exists {vault_path}/projects/{slug}/brief.md:
    // List available projects
    available = list dirs in {vault_path}/projects/
    ERROR "Project '{slug}' not found. Available: {available}"

// Update breadcrumb with new slug
UPDATE breadcrumb: project_slug={slug}, linked_at={TODAY}

// Read project info
project_type = read project_type from brief.md
status = read status from brief.md

REPORT: "Linked to project '{slug}' (type: {project_type}, status: {status})."
```

### create-project — Scaffold a type-shaped project

Requires both `<slug>` and `<type>`. Asks if either is omitted. Validates slug against naming rules (lowercase, hyphenated, no spaces, no dots).

```pseudocode
slug = validate_slug(user-provided slug)
project_type = validate_type(user-provided type)  // coding | knowledge | plugin | tinkerage

// Read breadcrumb for vault path
vault_path = read vault_path from $CLAUDE_PROJECT_DIR/.obsidian-bridge
IF NOT vault_path: ERROR "No vault connected."

project_dir = {vault_path}/projects/{slug}
IF exists project_dir: ERROR "Project '{slug}' already exists."

// 1. Create project directory
mkdir {project_dir}

// 2. Create brief from type-shaped template
template = read examples/vault-templates/brief-{project_type}.md
brief = template with:
    slug: {slug}
    aliases: [{slug}]
    created: {TODAY}
    updated: {TODAY}
    # Title set to slug (user can rename)
vault.write("projects/{slug}/brief.md", brief)

// 3. Scaffold type-specific subfolders
MATCH project_type:
    "coding":
        FOR folder IN [decisions, notes, tasks, references, sessions, images]:
            mkdir {project_dir}/{folder}
        FOR folder IN [decisions, notes, tasks, references]:
            vault.write("projects/{slug}/{folder}/_index.md", collection_index(slug, folder))

    "plugin":
        FOR folder IN [decisions, notes, tasks, references, releases, sessions, images]:
            mkdir {project_dir}/{folder}
        FOR folder IN [decisions, notes, tasks, references, releases]:
            vault.write("projects/{slug}/{folder}/_index.md", collection_index(slug, folder))

    "knowledge":
        FOR folder IN [notes, sources, references, sessions]:
            mkdir {project_dir}/{folder}
        FOR folder IN [notes, sources, references]:
            vault.write("projects/{slug}/{folder}/_index.md", collection_index(slug, folder))

    "tinkerage":
        mkdir {project_dir}/sessions   // optional, created for convenience

// 4. Update projects/_index.md
REBUILD projects/_index.md from all project briefs

// 5. Update Home.md
RUN update_home()

// 6. Update breadcrumb with slug
UPDATE $CLAUDE_PROJECT_DIR/.obsidian-bridge: project_slug={slug}

// 7. If codebase root detected, scaffold codebase dirs
IF git root OR $CLAUDE_PROJECT_DIR is a code project:
    mkdir -p assets, concepts, previews in codebase root (if not exists)

REPORT: "Project '{slug}' scaffolded as {project_type}. Folders: [list]. Brief at projects/{slug}/brief.md."


// Helper: generate collection _index.md
FUNCTION collection_index(slug, folder_name):
    RETURN template from examples/vault-templates/collection-index.md with:
        project: "[[projects/{slug}/brief|{slug}]]"
        title: capitalize(folder_name)
```

### add-collection — Add sub-collection folder + `_index.md`

```pseudocode
name = validate_slug(user-provided name)  // kebab-case

// Read breadcrumb
vault_path = read vault_path from breadcrumb
project_slug = read project_slug from breadcrumb
IF NOT project_slug: ERROR "No project linked. Run /vault-bridge link <slug> first."

collection_dir = {vault_path}/projects/{project_slug}/{name}
IF exists collection_dir: ERROR "Collection '{name}' already exists."

mkdir {collection_dir}
vault.write("projects/{project_slug}/{name}/_index.md", collection_index(project_slug, name))

REPORT: "Collection '{name}' added to project '{project_slug}' with _index.md."
```

### sync — Write/update current project's brief

```pseudocode
// Read breadcrumb
vault_path = read vault_path from breadcrumb
project_slug = read project_slug from breadcrumb
IF NOT project_slug: ERROR "No project linked."

brief_path = "projects/{project_slug}/brief.md"

// Build brief content from current session context
// Gather: overview, tech stack, constraints, work notes, milestones, user decisions
// from conversation context and any existing brief content

IF vault.exists(brief_path):
    existing = vault.read(brief_path)
    ASK: "Brief exists. Merge (preserve existing, update changed sections) or overwrite?"
    IF merge:
        // Preserve existing sections, update scope + work notes from session
        merged = merge_briefs(existing, session_context)
        vault.write(brief_path, merged)
    ELSE:
        vault.write(brief_path, new_brief)
ELSE:
    // Read project_type from breadcrumb context or ask
    vault.write(brief_path, new_brief)

// Update brief frontmatter
vault.property_set(brief_path, "updated", TODAY)

// Rebuild indices
REBUILD projects/_index.md
RUN update_home()

REPORT: "Brief synced for '{project_slug}'."
```

### status — Vault summary + per-project counts

```pseudocode
// Read breadcrumb
vault_path = read vault_path from breadcrumb
vault_name = read vault_name from breadcrumb
mode = read mode from breadcrumb

REPORT header: "Vault: {vault_name} at {vault_path}"
REPORT: "Transport: {mode}"
IF mode == "cli":
    cli_ver = run "obsidian version"
    REPORT: "CLI version: {cli_ver}"

// Schema version detection
has_v3 = any brief has project_type field
has_v2 = any brief lacks project_type field
IF has_v3 AND has_v2: version_note = "v3 (mixed — some v2 projects remain)"
ELIF has_v3: version_note = "v3"
ELSE: version_note = "v2"
REPORT: "Schema: {version_note}"

// Per-project inventory
FOR each project dir in {vault_path}/projects/:
    slug = dirname
    brief = read brief.md frontmatter
    status = brief.status
    project_type = brief.project_type OR "unknown"
    decisions = count files in decisions/
    sessions = count files in sessions/
    last_session = most recent session filename date
    REPORT row: "  {slug} — {project_type} — {status} — {decisions}d {sessions}s — last: {last_session}"

// Archive
FOR each dir in {vault_path}/archive/:
    REPORT: "  [archived] {dirname}"

// Cabinet detection
IF {vault_path}/crew/ exists:
    REPORT: "Cabinet: detected — crew/ folder present, untouched by bridge."

// Remember detection
IF $CLAUDE_PROJECT_DIR/.remember/ exists:
    IF _handoff.md exists for current project:
        handoff_date = read updated from _handoff.md frontmatter
        REPORT: "Remember: detected — last handoff sync: {handoff_date}"
    ELSE:
        REPORT: "Remember: detected — no handoff yet."

// Drift teaser (quick check)
issues = quick_scan_for_drift()  // briefs missing project_type, collections without _index, etc.
IF issues > 0:
    REPORT: "Drift: {issues} issues detected. Run /dream for details."
```

### templates — List or print available templates

```pseudocode
IF subcommand == "list" OR no subcommand:
    FOR each .md file in examples/vault-templates/:
        name = filename without .md
        type = read type from frontmatter
        REPORT: "  {name} — type: {type}"

IF subcommand == "print" AND template_name provided:
    path = examples/vault-templates/{template_name}.md
    IF NOT exists path:
        path = examples/vault-templates/{template_name}  // try with extension
    IF NOT exists path:
        ERROR "Template '{template_name}' not found."
    content = read path
    REPORT: content
```

### archive — Move project to archive/

```pseudocode
slug = user-provided slug OR read project_slug from breadcrumb
vault_path = read vault_path from breadcrumb

IF NOT exists {vault_path}/projects/{slug}/:
    ERROR "Project '{slug}' not found in projects/."

// Update brief status
vault.property_set("projects/{slug}/brief.md", "status", "archived")
vault.property_set("projects/{slug}/brief.md", "updated", TODAY)

// Move the folder
vault.move("projects/{slug}", "archive/{slug}")

// Rebuild indices
REBUILD projects/_index.md
RUN update_home()

// If current breadcrumb points to this slug, clear it
IF breadcrumb project_slug == slug:
    UPDATE breadcrumb: project_slug=

REPORT: "Project '{slug}' archived."
```

### unarchive — Restore project from archive/

```pseudocode
slug = user-provided slug
vault_path = read vault_path from breadcrumb

IF NOT exists {vault_path}/archive/{slug}/:
    ERROR "Project '{slug}' not found in archive/."

// Update brief status
vault.property_set("archive/{slug}/brief.md", "status", "active")
vault.property_set("archive/{slug}/brief.md", "updated", TODAY)

// Move back
vault.move("archive/{slug}", "projects/{slug}")

// Rebuild indices
REBUILD projects/_index.md
RUN update_home()

REPORT: "Project '{slug}' restored to active."
```

### reindex — Rebuild all `_index.md` files from disk

```pseudocode
vault_path = read vault_path from breadcrumb

// 1. Rebuild projects/_index.md
projects = list dirs in {vault_path}/projects/
FOR each project:
    read brief frontmatter (slug, status, project_type, created, updated)
    count decisions, sessions
    find latest session date
WRITE projects/_index.md with table rows

// 2. Rebuild per-project collection indices
FOR each project dir:
    FOR each subfolder that is a collection (has ≥2 .md siblings, not sessions/images/assets/):
        IF _index.md missing:
            CREATE from collection-index template
        REBUILD _index.md entries from folder contents
            sort chronologically if filenames have dates, else alphabetically

// 3. Rebuild iterations/_index.md (if exists)
FOR each project with iterations/:
    group iterations by track (from frontmatter)
    sort by date within track
    WRITE iterations/_index.md with track grouping and status badges

// 4. Rebuild Home.md
RUN update_home()

// 5. Report
REPORT: "Reindexed {N} projects, rebuilt {M} _index.md files."
```

### set-type — Change project type post-hoc

```pseudocode
slug = user-provided slug
new_type = validate_type(user-provided type)
vault_path = read vault_path from breadcrumb

brief_path = "projects/{slug}/brief.md"
IF NOT vault.exists(brief_path): ERROR "Project '{slug}' not found."

old_type = vault.property_read(brief_path, "project_type")

// Update frontmatter
vault.property_set(brief_path, "project_type", new_type)
vault.property_set(brief_path, "updated", TODAY)

// Update tags: remove old type tag, add new
// Read tags, replace type/{old_type} with type/{new_type}
tags = vault.property_read(brief_path, "tags")
tags = replace "type/{old_type}" with "type/{new_type}" in tags
vault.property_set(brief_path, "tags", tags)

// Scaffold new type-specific folders if missing
MATCH new_type:
    // Same logic as create-project folder scaffolding
    // Only create folders that don't already exist
    // Create _index.md for new collection folders

REPORT: "Project '{slug}' type changed from {old_type} to {new_type}. New folders scaffolded if needed."
```

### housekeeping — Full consistency check

Runs all structural checks from the housekeeping checklist. Auto-fixes safe items, reports manual items.

```pseudocode
vault_path = read vault_path from breadcrumb
project_slug = read project_slug from breadcrumb

// Scope: current project if linked, otherwise vault-wide
IF project_slug:
    scope = [project_slug]
ELSE:
    scope = list all project slugs

auto_fixes = []
manual_items = []

FOR each slug in scope:
    project_dir = {vault_path}/projects/{slug}

    // 1. Empty project folder
    IF project_dir has no .md files and no subfolders:
        manual_items.add("Empty project folder: {slug} — archive or delete?")

    // 2. Missing brief.md
    IF NOT exists brief.md:
        auto_fixes.add("Missing brief.md for {slug} — scaffold from template")
        ACTION: scaffold brief from type template (ask type if unknown)

    // 3. Slug shape violation
    IF slug contains dots, spaces, or uppercase:
        manual_items.add("Slug '{slug}' violates naming rules — rename with /vault-bridge?")

    // 4. Collection folders missing _index.md
    FOR each subfolder with ≥2 .md siblings (excluding sessions/, images/, assets/):
        IF NOT exists _index.md:
            auto_fixes.add("Missing _index.md in {slug}/{folder}")
            ACTION: create from collection-index template

    // 5. _index.md out of sync
    FOR each _index.md:
        expected_entries = list .md siblings
        actual_entries = parse _index.md links
        IF mismatch:
            auto_fixes.add("_index.md out of sync in {slug}/{folder}")
            ACTION: rebuild from disk

    // 6. Files missing frontmatter
    FOR each .md file (excluding .obsidian/, templates/):
        IF no YAML frontmatter:
            auto_fixes.add("Missing frontmatter: {file}")
            ACTION: add minimal valid frontmatter based on location

    // 7. Malformed/incomplete frontmatter
    FOR each .md file with frontmatter:
        IF missing required fields for its type:
            auto_fixes.add("Incomplete frontmatter: {file} — missing {fields}")
            ACTION: add missing required fields with defaults

    // 8. Broken wikilinks
    FOR each wikilink [[target]] in all files:
        IF target not resolvable:
            manual_items.add("Broken wikilink [[{target}]] in {file}")

    // 9. Markdown-style links
    FOR each [text](path) in vault files:
        auto_fixes.add("Markdown link in {file} — convert to wikilink")
        ACTION: replace with [[equivalent]]

    // 10. Tag clutter
    all_tags = collect all tags across scope
    FOR tag with usage_count == 1:
        manual_items.add("Single-use tag #{tag} in {file}")
    FOR near-duplicates (e.g. #postgres vs #postgresql):
        manual_items.add("Near-duplicate tags: #{a} vs #{b}")

    // 11. Stale updated date
    IF status == "active" AND updated > 90 days ago:
        manual_items.add("Stale project '{slug}' — last updated {updated}")

    // 12. Decision filename pattern
    FOR each file in decisions/:
        IF NOT matches YYYY-MM-DD-{kebab}.md:
            auto_fixes.add("Decision filename violation: {file}")
            ACTION: rename to correct pattern

    // 13. Session filename pattern
    FOR each file in sessions/:
        IF NOT matches YYYY-MM-DD.md:
            auto_fixes.add("Session filename violation: {file}")
            ACTION: rename or merge same-day

    // 14. Root docs missing type: doc
    FOR each .md in project root (not brief.md, not _handoff.md, not _index.md):
        IF NOT has type: doc in frontmatter:
            auto_fixes.add("Root doc missing type: doc — {file}")
            ACTION: add type: doc frontmatter

    // 15. Brief body missing required blocks for type
    project_type = read from brief frontmatter
    required_blocks = get_required_blocks(project_type)
    existing_blocks = parse ## headers from brief body
    FOR each missing block:
        auto_fixes.add("Brief missing block: ## {block} for type {project_type}")
        ACTION: add empty block with placeholder

// Report
REPORT:
    "## Auto-fixable ({count})"
    list auto_fixes
    "[Fix all] [Pick] [Skip]"
    ""
    "## Needs decision ({count})"
    list manual_items

// If user chooses "Fix all": run all auto_fixes sequentially
// If "Pick": present each, user approves/skips
// If "Skip": done
```