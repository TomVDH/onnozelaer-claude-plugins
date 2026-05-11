# Vault migration — v2 → v3

One-shot, opt-in walkthrough. Idempotent — re-running on a v3 vault
effectively becomes housekeeping. Conversational invocation only; no
slash command. See spec §16 for full detail.

**Trigger:** "migrate this vault to v3"

---

## Walkthrough

```pseudocode
vault_path = read vault_path from breadcrumb

// 1. Confirm scope
projects    = list dirs in {vault_path}/projects/
archived    = list dirs in {vault_path}/archive/
total_files = count all .md files in vault

REPORT: "Migration scope: {projects.length} projects, {archived.length} archived, {total_files} files."
REPORT: "This will: add project_type to briefs, reformat brief bodies to v3 blocks, add _index.md to collections, normalise tags."
ASK:    "Proceed? (A backup will be created first.)"
IF NOT proceed: RETURN

// 2. Backup
backup_dir = {vault_path}/.backup-v2-{TODAY}
cp -r {vault_path}/projects {backup_dir}/projects
cp -r {vault_path}/archive  {backup_dir}/archive 2>/dev/null || true
cp    {vault_path}/Home.md  {backup_dir}/Home.md
REPORT: "Backup created at {backup_dir}. Delete after verifying migration."

// 3. Migrate each project
FOR each project in projects + archived:
    slug       = dirname
    brief_path = resolve brief.md path (projects/ or archive/)

    // a. Detect project_type if not set
    existing_type = vault.property_read(brief_path, "project_type")
    IF NOT existing_type:
        // Heuristic defaults
        IF exists decisions/: suggested = "coding"
        ELIF exists sources/: suggested = "knowledge"
        ELIF exists releases/: suggested = "plugin"
        ELSE: suggested = "tinkerage"

        ASK: "Project '{slug}' — assign type? Suggested: {suggested}. Options: coding, knowledge, plugin, tinkerage."
        project_type = user response OR suggested
        vault.property_set(brief_path, "project_type", project_type)
    ELSE:
        project_type = existing_type

    // b. Add aliases if missing
    aliases = vault.property_read(brief_path, "aliases")
    IF NOT aliases OR aliases is empty:
        vault.property_set(brief_path, "aliases", [slug])

    // c. Normalise tags: keep cabinet/*, add ob/*, add type/*
    tags = vault.property_read(brief_path, "tags")
    IF NOT contains "ob/project":            tags.add("ob/project")
    IF NOT contains "type/{project_type}":   tags.add("type/{project_type}")
    vault.property_set(brief_path, "tags", tags)

    // d. Ensure slug field
    IF NOT vault.property_read(brief_path, "slug"):
        vault.property_set(brief_path, "slug", slug)

    // e. Brief body reformat (see reformat_brief_body function below)
    body        = read brief body (after frontmatter)
    reformatted = reformat_brief_body(body, project_type)
    IF reformatted != body:
        write reformatted body back

    // f. Slug repair
    IF slug contains dots, spaces, or uppercase:
        suggested_slug = slugify(slug)
        ASK: "Rename '{slug}' → '{suggested_slug}'?"
        IF yes:
            vault.move("projects/{slug}", "projects/{suggested_slug}")
            slug = suggested_slug

// 4. Backfill _index.md
FOR each project:
    FOR each collection folder (≥2 .md siblings, not sessions/images/assets/):
        IF NOT exists _index.md: CREATE from collection-index template
        REBUILD _index.md from folder contents

// 5. Emergent iteration folders
FOR each project:
    FOR folder_name IN [design-iterations, surfaces, aesthetics]:
        IF exists {project_dir}/{folder_name}/:
            ASK: "Canonicalise '{folder_name}/' → 'iterations/' for project '{slug}'?"
            IF yes:
                vault.move("projects/{slug}/{folder_name}", "projects/{slug}/iterations")
                FOR each .md in iterations/:
                    IF type == "design-iteration":
                        vault.property_set(file, "type", "iteration")
                    tags = read tags
                    IF "cabinet/design-iteration" in tags:
                        tags.add("ob/iteration")
                    vault.property_set(file, "tags", tags)
                CREATE iterations/_index.md (rebuild from disk)
            ELSE:
                IF NOT exists _index.md: CREATE _index.md for it

// 6. Root-level singleton docs
FOR each project:
    FOR each .md in project root (not brief.md, not _handoff.md, not _index.md):
        IF NOT has type: doc frontmatter:
            ADD type: doc frontmatter (preserve body)

// 7. Update Home.md frontmatter
home = read Home.md
IF type == "cabinet-home":
    IF {vault_path}/crew/ exists:
        SET type to [vault-home, cabinet-home]
    ELSE:
        SET type to vault-home
RUN update_home()

// 8. Run housekeeping (auto-fix all safe items)
RUN housekeeping

// 9. Report
changes = count all changes made
REPORT: "Migration complete. Changed {changes} files. Backup at {backup_dir}."
REPORT: "Review the changes, then delete {backup_dir} when satisfied."
```

---

## Brief body reformat

v2 → v3 section mapping for `coding` type:

```
## Overview      →  ## INTRO
## Tech Stack    →  ## TECHNICAL STACK
## Scope         →  split: ## CONSTRAINTS + ## USER DECISIONS
## Conventions   →  append to ## TECHNICAL STACK or ## CONSTRAINTS
## Team Notes    →  ## WORK NOTES
anything else    →  ## WORK NOTES
```

Similar mappings for `knowledge`, `plugin`, and `tinkerage`. All
content is preserved verbatim under best-fit headers. Empty required
blocks are added with a `TBD` placeholder.

```pseudocode
FUNCTION reformat_brief_body(body, project_type):
    required_blocks = get_blocks_for_type(project_type)
    mapped_body     = map_sections(body, project_type)

    FOR each required block NOT present in mapped_body:
        APPEND "## {BLOCK}\n\nTBD\n"

    RETURN mapped_body
```

---

## Anchor migration

Anchor migration (legacy `.obsidian-bridge` → `.claude/obsidian-bridge`)
is **silent and automatic** — handled by the `SessionStart` hook
step 0. There is no separate command for it.
