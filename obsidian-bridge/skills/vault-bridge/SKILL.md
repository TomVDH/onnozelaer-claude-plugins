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