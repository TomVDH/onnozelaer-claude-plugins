# Conversational vault operations

Operations that **don't have a slash command** but the `vault-bridge`
skill still handles. The model invokes them when the user describes
the intent in natural language. This file is the implementation
reference — the SKILL.md only lists what's covered.

Triggers are example phrasings, not exhaustive. The model should
recognise the intent and dispatch the matching flow.

---

## add-collection

**Trigger:** "add a tasks/ folder to foo", "scaffold a notes/ collection in bar"

```pseudocode
name = validate_slug(user-provided name)        // kebab-case

vault_path    = read vault_path from breadcrumb
project_slug  = read project_slug from breadcrumb
IF NOT project_slug: ERROR "No project linked. Run /connect --link-only <slug> first."

collection_dir = {vault_path}/projects/{project_slug}/{name}
IF exists collection_dir: ERROR "Collection '{name}' already exists."

mkdir {collection_dir}
vault.write("projects/{project_slug}/{name}/_index.md",
            collection_index(project_slug, name))

REPORT: "Collection '{name}' added to project '{project_slug}' with _index.md."
```

---

## archive / unarchive

**Trigger:** "archive foo", "restore bar from archive"

### archive

```pseudocode
slug       = user-provided slug OR read project_slug from breadcrumb
vault_path = read vault_path from breadcrumb

IF NOT exists {vault_path}/projects/{slug}/:
    ERROR "Project '{slug}' not found in projects/."

vault.property_set("projects/{slug}/brief.md", "status",  "archived")
vault.property_set("projects/{slug}/brief.md", "updated", TODAY)

vault.move("projects/{slug}", "archive/{slug}")

REBUILD projects/_index.md
RUN update_home()

IF breadcrumb.project_slug == slug:
    UPDATE breadcrumb: project_slug=

REPORT: "Project '{slug}' archived."
```

### unarchive

```pseudocode
slug       = user-provided slug
vault_path = read vault_path from breadcrumb

IF NOT exists {vault_path}/archive/{slug}/:
    ERROR "Project '{slug}' not found in archive/."

vault.property_set("archive/{slug}/brief.md", "status",  "active")
vault.property_set("archive/{slug}/brief.md", "updated", TODAY)

vault.move("archive/{slug}", "projects/{slug}")

REBUILD projects/_index.md
RUN update_home()

REPORT: "Project '{slug}' restored to active."
```

---

## set-type

**Trigger:** "change foo to plugin type", "set baz's project_type to knowledge"

```pseudocode
slug       = user-provided slug
new_type   = validate_type(user-provided type)      // coding | knowledge | plugin | tinkerage
vault_path = read vault_path from breadcrumb

brief_path = "projects/{slug}/brief.md"
IF NOT vault.exists(brief_path): ERROR "Project '{slug}' not found."

old_type = vault.property_read(brief_path, "project_type")

vault.property_set(brief_path, "project_type", new_type)
vault.property_set(brief_path, "updated",      TODAY)

// Tags: swap type/{old_type} → type/{new_type}
tags = vault.property_read(brief_path, "tags")
tags = replace "type/{old_type}" with "type/{new_type}" in tags
vault.property_set(brief_path, "tags", tags)

// Scaffold any new type-specific folders missing (mirrors create-project logic)
// Create _index.md for each new collection folder.

REPORT: "Project '{slug}' type changed from {old_type} to {new_type}. New folders scaffolded if needed."
```

---

## templates

**Trigger:** "show me the brief template for coding", "list available templates"

```pseudocode
IF subcommand == "list" OR no subcommand:
    FOR each .md file in examples/vault-templates/:
        name = filename without .md
        type = read type from frontmatter
        REPORT: "  {name} — type: {type}"

IF subcommand == "print" AND template_name provided:
    path = examples/vault-templates/{template_name}.md
    IF NOT exists path:
        path = examples/vault-templates/{template_name}   // try with extension
    IF NOT exists path:
        ERROR "Template '{template_name}' not found."
    REPORT: contents of path
```

---

## add-iteration / add-iteration-artefact

Iterations are a first-class collection type. Canonical folder:
`projects/{slug}/iterations/`. Opt-in for all project types — not
auto-created on project scaffold. Schema in `obsidian-bridge:vault-standards`.

**Trigger:** "new iteration D for foo on navy track", "attach concept.png to iter D"

### add-iteration

```pseudocode
identifier   = user-provided id                     // letter, number, or short word
iter_slug    = validate_slug(user-provided slug)
track        = optional --track flag
with_folder  = optional --with-folder flag

vault_path    = read vault_path from breadcrumb
project_slug  = read project_slug from breadcrumb
IF NOT project_slug: ERROR "No project linked."

iter_dir = {vault_path}/projects/{project_slug}/iterations

IF NOT exists iter_dir:
    mkdir iter_dir
    vault.write("projects/{project_slug}/iterations/_index.md",
                iterations_index(project_slug))

date     = TODAY
filename = "{date}-iter-{identifier}-{iter_slug}"

IF with_folder:
    mkdir {iter_dir}/{filename}
    vault.write("projects/{project_slug}/iterations/{filename}/_iteration.md",
                iteration_template(project_slug, identifier, date, track))
ELSE:
    vault.write("projects/{project_slug}/iterations/{filename}.md",
                iteration_template(project_slug, identifier, date, track))

// Add ## ITERATIONS block to brief if not present
brief_content = vault.read("projects/{project_slug}/brief.md")
IF NOT contains "## ITERATIONS":
    APPEND before last section or at end:
        "\n## ITERATIONS\n\nSee [[projects/{project_slug}/iterations/_index|iterations]].\n"

REBUILD iterations/_index.md from disk (grouped by track, sorted by date)

REPORT: "Iteration {identifier} created: {filename}"


FUNCTION iteration_template(slug, identifier, date, track):
    frontmatter = {
        type:       iteration,
        project:    "[[projects/{slug}/brief|{slug}]]",
        identifier: identifier,
        status:     drafting,
        date:       date,
        tags:       [ob/iteration]
    }
    IF track: frontmatter.track = track
    RETURN: frontmatter + "\n# Iteration {identifier}\n"


FUNCTION iterations_index(slug):
    RETURN collection_index template with:
        project:     "[[projects/{slug}/brief|{slug}]]"
        title:       "Iterations — {slug}"
        description: "Design and code iterations grouped by track."
```

### add-iteration-artefact

```pseudocode
iter_id = user-provided iteration identifier        // matches identifier field
file    = user-provided file path                   // absolute or relative to CWD

vault_path    = read vault_path from breadcrumb
project_slug  = read project_slug from breadcrumb
iter_dir      = {vault_path}/projects/{project_slug}/iterations

// Find iteration by identifier
found = null
FOR each entry in iter_dir:
    IF entry name contains "-iter-{iter_id}-":
        found = entry
        BREAK
IF NOT found: ERROR "Iteration '{iter_id}' not found."

// If file form, promote to folder form
IF found is a .md file:
    folder_name = found without .md extension
    mkdir {iter_dir}/{folder_name}
    vault.move("projects/{project_slug}/iterations/{found}",
               "projects/{project_slug}/iterations/{folder_name}/_iteration.md")
    found = folder_name

// Copy artefact into iteration folder
artefact_name = basename(file)
cp {file} to {iter_dir}/{found}/{artefact_name}

// Update frontmatter artefacts list
iter_file = "projects/{project_slug}/iterations/{found}/_iteration.md"
existing  = vault.property_read(iter_file, "artefacts") OR []
existing.add(artefact_name)
vault.property_set(iter_file, "artefacts", existing)

REBUILD iterations/_index.md

REPORT: "Artefact '{artefact_name}' added to iteration {iter_id}. Promoted to folder form."
```
