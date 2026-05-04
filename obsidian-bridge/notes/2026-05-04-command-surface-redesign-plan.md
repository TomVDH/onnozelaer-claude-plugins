# Command surface redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current ~25-subcommand `/vault-bridge` + `/dream` surface with 7 opinionated top-level verbs (`/connect`, `/sync`, `/check`, `/draw`, `/ramasse`, `/dream`, `/iterate`), and clean all legacy reads from the anchor chain in favour of silent auto-migration.

**Architecture:** Plugin already has the underlying logic; this plan rewires the entry surface. New `*.md` command files dispatch to existing skill logic. The `vault-bridge` skill body gets restructured around the new verbs. SessionStart hook gains a step-0 auto-migration. All other hook readers drop their legacy fallback (canonical-only reads). No new business logic — only re-grouping, renaming, and one new auto-migrate step.

**Tech Stack:** Markdown command files (with YAML frontmatter), bash hook scripts, Python hook scripts, JSON plugin manifest.

**Spec:** [`2026-05-04-command-surface-redesign.md`](2026-05-04-command-surface-redesign.md) — read it first if you haven't.

---

## Phase 0 — Pre-flight (merge dependencies)

Two in-flight branches must land on `main` before this plan can execute cleanly. They're independent of each other; the order below is the safest.

### Task 0a: Merge `feat/obsidian-deepening` into main

Adds canvas + search skills + AUTHORITATIVE_REFERENCE pointers. Independent of everything else here. Will conflict on `ATTRIBUTIONS.md` (~5 lines) if other branches modify it; resolve by keeping all entries.

**Files:**
- Modify: `obsidian-bridge/ATTRIBUTIONS.md` (likely conflict)

- [ ] **Step 1: Switch to main, fetch latest**
  ```bash
  cd /Users/tomvanderhegden/.claude/plugins/marketplaces/onnozelaer-claude-marketplace
  git checkout main
  git fetch origin
  ```

- [ ] **Step 2: Preview merge for conflicts**
  ```bash
  git merge-tree --name-only HEAD feat/obsidian-deepening
  ```
  Expected: a tree SHA (clean merge) OR a list of conflicted files. If `ATTRIBUTIONS.md` shows up, expect a small textual conflict.

- [ ] **Step 3: Merge with --no-ff**
  ```bash
  git merge --no-ff feat/obsidian-deepening -m "Merge branch 'feat/obsidian-deepening' into main

  Adds canvas + search skills (new), authoritative-reference pointers
  in bases/markdown/vault-standards (deepening), and updated ATTRIBUTIONS.md
  crediting the Obsidian Help vault (CC BY 4.0) and JSON Canvas spec (MIT).

  Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
  ```

- [ ] **Step 4: If conflict, resolve and continue**
  Open `ATTRIBUTIONS.md`, keep both contributions side-by-side, ensure all entries land. Then:
  ```bash
  git add obsidian-bridge/ATTRIBUTIONS.md
  git commit
  ```

- [ ] **Step 5: Push**
  ```bash
  git push origin main
  ```

### Task 0b: Merge `feat/anchor-in-dot-claude` into main

Moves anchor to `.claude/obsidian-bridge` with canonical-then-legacy fallback in all readers. Phase 1 of THIS plan will remove the legacy fallback (replace with auto-migration). Merging first keeps the diff small.

**Files:**
- Modify: `obsidian-bridge/hooks/hooks.json`, plus 5 hook scripts and `vault-bridge` skill body

- [ ] **Step 1: Preview merge**
  ```bash
  git merge-tree --name-only HEAD feat/anchor-in-dot-claude
  ```
  Expected: clean tree SHA (no other branch has touched these hook scripts post-merge of obsidian-deepening).

- [ ] **Step 2: Merge with --no-ff**
  ```bash
  git merge --no-ff feat/anchor-in-dot-claude -m "Merge branch 'feat/anchor-in-dot-claude' into main

  Anchor file canonical location is now .claude/obsidian-bridge.
  Readers fall back to legacy .obsidian-bridge for one release cycle
  before that fallback is removed in favour of auto-migration
  (see notes/2026-05-04-command-surface-redesign.md).

  Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
  ```

- [ ] **Step 3: Verify hooks.json still parses**
  ```bash
  python3 -c "import json; json.load(open('obsidian-bridge/hooks/hooks.json'))" && echo "JSON valid"
  ```

- [ ] **Step 4: Push**
  ```bash
  git push origin main
  ```

### Task 0c: Create the implementation branch

- [ ] **Step 1: Branch off main**
  ```bash
  git checkout -b feat/command-surface-redesign
  git status -sb
  ```
  Expected: `## feat/command-surface-redesign`

---

## Phase 1 — Hook updates: auto-migration + drop legacy fallback

The SessionStart hook gains a new step 0 (auto-migrate legacy anchor). All other readers drop their canonical-then-legacy fallback (canonical-only).

### Task 1: Add SessionStart step-0 auto-migration

**Files:**
- Modify: `obsidian-bridge/hooks/scripts/session-start-vault.sh`

- [ ] **Step 1: Write a failing test scenario**

  Save to `/tmp/test-migration.sh`:
  ```bash
  #!/usr/bin/env bash
  set -euo pipefail
  TMPDIR_TEST=$(mktemp -d)
  PD="$TMPDIR_TEST/proj"
  VAULT="$TMPDIR_TEST/vault"
  mkdir -p "$PD" "$VAULT"
  # Set up legacy anchor + .gitignore
  printf 'vault_path=%s\nproject_slug=foo\n' "$VAULT" > "$PD/.obsidian-bridge"
  printf '.obsidian-bridge\n' > "$PD/.gitignore"
  # Run the hook
  CLAUDE_PROJECT_DIR="$PD" bash /Users/tomvanderhegden/.claude/plugins/marketplaces/onnozelaer-claude-marketplace/obsidian-bridge/hooks/scripts/session-start-vault.sh
  echo "---"
  echo "After:"
  ls -la "$PD/.claude/" 2>&1 | grep obsidian-bridge || echo "MIGRATION FAILED — no .claude/obsidian-bridge"
  [ -f "$PD/.obsidian-bridge" ] && echo "MIGRATION FAILED — legacy file still present" || echo "Legacy removed ✓"
  cat "$PD/.gitignore"
  rm -rf "$TMPDIR_TEST"
  ```

- [ ] **Step 2: Run the test, verify it fails**
  ```bash
  bash /tmp/test-migration.sh
  ```
  Expected: `MIGRATION FAILED — no .claude/obsidian-bridge` (because the hook doesn't auto-migrate yet).

- [ ] **Step 3: Add migration block at the top of the `main()` function in session-start-vault.sh**

  Edit `obsidian-bridge/hooks/scripts/session-start-vault.sh`. Insert a new block right after the `local project_dir="${CLAUDE_PROJECT_DIR:-}"` line and the empty-check, BEFORE the existing variable declaration:

  ```bash
    # --- 0. Auto-migrate legacy anchor (.obsidian-bridge → .claude/obsidian-bridge) ---
    local legacy_anchor="$project_dir/.obsidian-bridge"
    local canonical_anchor="$project_dir/.claude/obsidian-bridge"
    if [ -f "$legacy_anchor" ] && [ ! -f "$canonical_anchor" ]; then
      mkdir -p "$project_dir/.claude" 2>/dev/null || true
      if mv "$legacy_anchor" "$canonical_anchor" 2>/dev/null; then
        # Rewrite .gitignore line if present
        local gitignore="$project_dir/.gitignore"
        if [ -f "$gitignore" ] && grep -qxF '.obsidian-bridge' "$gitignore"; then
          # macOS sed needs '' after -i
          sed -i '' 's|^\.obsidian-bridge$|.claude/obsidian-bridge|' "$gitignore" 2>/dev/null \
            || sed -i 's|^\.obsidian-bridge$|.claude/obsidian-bridge|' "$gitignore" 2>/dev/null \
            || true
        fi
        printf '[obsidian-bridge] auto-migrated anchor → .claude/obsidian-bridge\n' >&2
      fi
    fi
  ```

- [ ] **Step 4: Run the test, verify it passes**
  ```bash
  bash /tmp/test-migration.sh
  ```
  Expected: `Legacy removed ✓` and `.gitignore` contains `.claude/obsidian-bridge`.

- [ ] **Step 5: Commit**
  ```bash
  git add obsidian-bridge/hooks/scripts/session-start-vault.sh
  git commit -m "feat(obsidian-bridge): SessionStart hook auto-migrates legacy anchor

  Adds step 0 to session-start-vault.sh: if .obsidian-bridge exists at
  project root and .claude/obsidian-bridge does not, move the file and
  rewrite the .gitignore line. One-line notice on stderr. Silent on
  re-runs (idempotent).

  Replaces /vault-bridge migrate-anchor (to be removed in a follow-up
  task in this plan).

  Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
  ```

### Task 2: Remove legacy fallback from session-start-vault.sh read chain

**Files:**
- Modify: `obsidian-bridge/hooks/scripts/session-start-vault.sh`

- [ ] **Step 1: Locate the canonical-then-legacy block**
  In `session-start-vault.sh`, find the `for candidate in ... .claude/obsidian-bridge ... .obsidian-bridge ...` loop in step 1 (added by `feat/anchor-in-dot-claude`).

- [ ] **Step 2: Replace the loop with direct canonical read**
  Replace:
  ```bash
    # --- 1. Read breadcrumb ---
    # Prefer .claude/obsidian-bridge (current convention); fall back to
    # .obsidian-bridge at project root (legacy, pre-migration).
    local breadcrumb=""
    for candidate in \
        "$project_dir/.claude/obsidian-bridge" \
        "$project_dir/.obsidian-bridge"; do
      if [ -f "$candidate" ]; then
        breadcrumb="$candidate"
        break
      fi
    done
    if [ -n "$breadcrumb" ]; then
  ```
  With:
  ```bash
    # --- 1. Read breadcrumb (canonical only — legacy auto-migrated in step 0) ---
    local breadcrumb="$project_dir/.claude/obsidian-bridge"
    if [ -f "$breadcrumb" ]; then
  ```

- [ ] **Step 3: Run the migration test again to confirm session-start still resolves**
  ```bash
  bash /tmp/test-migration.sh
  ```
  Expected: hook output starts with `## Obsidian Bridge` and shows the vault path.

- [ ] **Step 4: Commit**
  ```bash
  git add obsidian-bridge/hooks/scripts/session-start-vault.sh
  git commit -m "refactor(obsidian-bridge): SessionStart drops legacy anchor fallback

  Step 0 (auto-migration) ensures the canonical anchor is always present
  when a legacy one exists, so the read chain no longer needs to check
  both locations.

  Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
  ```

### Task 3: Drop legacy fallback from user-prompt-vault-reminder.sh

**Files:**
- Modify: `obsidian-bridge/hooks/scripts/user-prompt-vault-reminder.sh`

- [ ] **Step 1: Locate the dual-check**
  Find:
  ```bash
    # 1. Anchor file exists → vault is linked, no reminder needed
    # Prefer .claude/obsidian-bridge; fall back to legacy .obsidian-bridge
    [ -f "$project_dir/.claude/obsidian-bridge" ] && return 0
    [ -f "$project_dir/.obsidian-bridge" ] && return 0
  ```

- [ ] **Step 2: Replace with single canonical check**
  Replace with:
  ```bash
    # 1. Canonical anchor file exists → vault is linked, no reminder needed
    # (Legacy .obsidian-bridge is auto-migrated by SessionStart hook step 0.)
    [ -f "$project_dir/.claude/obsidian-bridge" ] && return 0
  ```

  Also update the header comment in the file:
  ```
  # Suppression rules (any one → silent exit):
  #   1. Canonical anchor file exists at .claude/obsidian-bridge
  ```

- [ ] **Step 3: Test — vault keyword with canonical anchor → silent**
  ```bash
  TMPDIR_TEST=$(mktemp -d)
  mkdir -p "$TMPDIR_TEST/.claude"
  printf 'vault_path=/tmp/v\n' > "$TMPDIR_TEST/.claude/obsidian-bridge"
  echo '{"prompt":"obsidian vault stuff"}' | CLAUDE_PROJECT_DIR="$TMPDIR_TEST" bash /Users/tomvanderhegden/.claude/plugins/marketplaces/onnozelaer-claude-marketplace/obsidian-bridge/hooks/scripts/user-prompt-vault-reminder.sh
  echo "(should be empty above)"
  rm -rf "$TMPDIR_TEST"
  ```
  Expected: empty output.

- [ ] **Step 4: Commit**
  ```bash
  git add obsidian-bridge/hooks/scripts/user-prompt-vault-reminder.sh
  git commit -m "refactor(obsidian-bridge): UserPromptSubmit reads canonical anchor only

  Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
  ```

### Task 4: Drop legacy fallback from session-end-handoff.sh

**Files:**
- Modify: `obsidian-bridge/hooks/scripts/session-end-handoff.sh`

- [ ] **Step 1: Replace the for-loop fallback with direct canonical**
  Replace:
  ```bash
    # Prefer .claude/obsidian-bridge; fall back to legacy .obsidian-bridge
    local breadcrumb=""
    for candidate in \
        "$project_dir/.claude/obsidian-bridge" \
        "$project_dir/.obsidian-bridge"; do
      if [ -f "$candidate" ]; then
        breadcrumb="$candidate"
        break
      fi
    done
    [ -z "$breadcrumb" ] && return 0
  ```
  With:
  ```bash
    # Canonical anchor only — legacy auto-migrated by SessionStart step 0
    local breadcrumb="$project_dir/.claude/obsidian-bridge"
    [ -f "$breadcrumb" ] || return 0
  ```

- [ ] **Step 2: Smoke-check the script still parses**
  ```bash
  bash -n /Users/tomvanderhegden/.claude/plugins/marketplaces/onnozelaer-claude-marketplace/obsidian-bridge/hooks/scripts/session-end-handoff.sh && echo "syntax ok"
  ```
  Expected: `syntax ok`.

- [ ] **Step 3: Commit**
  ```bash
  git add obsidian-bridge/hooks/scripts/session-end-handoff.sh
  git commit -m "refactor(obsidian-bridge): SessionEnd reads canonical anchor only

  Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
  ```

### Task 5: Drop legacy fallback from postuse-vault-validator.py

**Files:**
- Modify: `obsidian-bridge/hooks/scripts/postuse-vault-validator.py`

- [ ] **Step 1: Replace `find_anchor()` body with canonical-only**
  Replace:
  ```python
  def find_anchor(project_dir: str) -> str:
      """Locate the obsidian-bridge anchor file. Prefer the current
      convention (.claude/obsidian-bridge); fall back to the legacy
      location (.obsidian-bridge at project root)."""
      for candidate in (
          os.path.join(project_dir, ".claude", "obsidian-bridge"),
          os.path.join(project_dir, ".obsidian-bridge"),
      ):
          if os.path.isfile(candidate):
              return candidate
      return ""
  ```
  With:
  ```python
  def find_anchor(project_dir: str) -> str:
      """Return the canonical anchor file path if present, else empty string.
      Legacy .obsidian-bridge at project root is auto-migrated by the
      SessionStart hook (step 0) — readers see only the canonical path."""
      candidate = os.path.join(project_dir, ".claude", "obsidian-bridge")
      return candidate if os.path.isfile(candidate) else ""
  ```

- [ ] **Step 2: Verify Python parses**
  ```bash
  python3 -c "import ast; ast.parse(open('/Users/tomvanderhegden/.claude/plugins/marketplaces/onnozelaer-claude-marketplace/obsidian-bridge/hooks/scripts/postuse-vault-validator.py').read())" && echo "syntax ok"
  ```

- [ ] **Step 3: Quick functional test (canonical anchor → finds vault)**
  ```bash
  TMPDIR_TEST=$(mktemp -d)
  PD="$TMPDIR_TEST/proj"; VAULT="$TMPDIR_TEST/vault"
  mkdir -p "$PD/.claude" "$VAULT/projects/foo"
  printf 'vault_path=%s\n' "$VAULT" > "$PD/.claude/obsidian-bridge"
  printf 'no fm' > "$VAULT/projects/foo/x.md"
  printf '{"tool_name":"Write","tool_input":{"file_path":"%s/projects/foo/x.md"}}' "$VAULT" \
    | CLAUDE_PROJECT_DIR="$PD" python3 /Users/tomvanderhegden/.claude/plugins/marketplaces/onnozelaer-claude-marketplace/obsidian-bridge/hooks/scripts/postuse-vault-validator.py
  rm -rf "$TMPDIR_TEST"
  ```
  Expected: warning message about missing frontmatter.

- [ ] **Step 4: Commit**
  ```bash
  git add obsidian-bridge/hooks/scripts/postuse-vault-validator.py
  git commit -m "refactor(obsidian-bridge): PostToolUse validator reads canonical anchor only

  Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
  ```

### Task 6: Drop legacy fallback from precompact-handoff-sync.py

**Files:**
- Modify: `obsidian-bridge/hooks/scripts/precompact-handoff-sync.py`

- [ ] **Step 1: Replace `find_anchor()` body with canonical-only**
  Same shape as Task 5 step 1.

- [ ] **Step 2: Verify Python parses**
  ```bash
  python3 -c "import ast; ast.parse(open('/Users/tomvanderhegden/.claude/plugins/marketplaces/onnozelaer-claude-marketplace/obsidian-bridge/hooks/scripts/precompact-handoff-sync.py').read())" && echo "syntax ok"
  ```

- [ ] **Step 3: Functional test (precompact writes handoff with canonical anchor)**
  ```bash
  TMPDIR_TEST=$(mktemp -d)
  PD="$TMPDIR_TEST/proj"; VAULT="$TMPDIR_TEST/vault"
  mkdir -p "$PD/.claude" "$PD/.remember" "$VAULT/projects/foo"
  printf 'vault_path=%s\nproject_slug=foo\n' "$VAULT" > "$PD/.claude/obsidian-bridge"
  printf 'remember body\n' > "$PD/.remember/remember.md"
  CLAUDE_PROJECT_DIR="$PD" python3 /Users/tomvanderhegden/.claude/plugins/marketplaces/onnozelaer-claude-marketplace/obsidian-bridge/hooks/scripts/precompact-handoff-sync.py
  cat "$VAULT/projects/foo/_handoff.md"
  rm -rf "$TMPDIR_TEST"
  ```
  Expected: handoff file written with canonical frontmatter.

- [ ] **Step 4: Commit**
  ```bash
  git add obsidian-bridge/hooks/scripts/precompact-handoff-sync.py
  git commit -m "refactor(obsidian-bridge): PreCompact sync reads canonical anchor only

  Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
  ```

---

## Phase 2 — New command files

Each new command is a `.md` file in `obsidian-bridge/commands/`. Frontmatter follows the existing convention from `commands/vault-bridge.md`. Body dispatches to the `vault-bridge` skill (Phase 4 will refactor that skill to match).

### Task 7: Create `commands/connect.md`

**Files:**
- Create: `obsidian-bridge/commands/connect.md`

- [ ] **Step 1: Write the file**
  Content:
  ````markdown
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
  ````

- [ ] **Step 2: Verify YAML frontmatter parses**
  ```bash
  python3 -c "
  import yaml, re
  text = open('/Users/tomvanderhegden/.claude/plugins/marketplaces/onnozelaer-claude-marketplace/obsidian-bridge/commands/connect.md').read()
  m = re.match(r'^---\n(.+?)\n---', text, re.DOTALL)
  yaml.safe_load(m.group(1))
  print('frontmatter ok')
  "
  ```
  Expected: `frontmatter ok`.

- [ ] **Step 3: Commit**
  ```bash
  git add obsidian-bridge/commands/connect.md
  git commit -m "feat(obsidian-bridge): /connect command (replaces create + connect + link + create-project)

  Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
  ```

### Task 8: Create `commands/sync.md`

**Files:**
- Create: `obsidian-bridge/commands/sync.md`

- [ ] **Step 1: Write the file**
  ````markdown
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
  ````

- [ ] **Step 2: Verify frontmatter parses (same check as Task 7 step 2, swap path)**

- [ ] **Step 3: Commit**
  ```bash
  git add obsidian-bridge/commands/sync.md
  git commit -m "feat(obsidian-bridge): /sync command (replaces sync + handoff sync)

  Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
  ```

### Task 9: Create `commands/check.md`

**Files:**
- Create: `obsidian-bridge/commands/check.md`

- [ ] **Step 1: Write the file**
  ````markdown
  ---
  description: Read-only summary; optional sections (iterations, decisions, sessions, handoff)
  allowed-tools: Read, Glob, Grep
  ---

  Read-only summary of the linked vault and current project. Replaces `/vault-bridge status` and `/vault-bridge handoff status`. Pass one or more sections for a focused view.

  ## Usage

  ```
  /check                                     Full vault + current-project summary
  /check <section> [<section> ...]           Focused view; sections combine in one call
  ```

  ### Sections

  | Section | What it shows |
  |---|---|
  | `iterations` | Iterations grouped by track and status (current project; --all for vault-wide) |
  | `decisions` | Recent decisions (current project; --all for vault-wide) |
  | `sessions` | Recent session summaries |
  | `handoff` | Last handoff sync time + freshness vs `.remember/remember.md` |
  | `tags` | Tag taxonomy summary across vault |

  Multi-section: `/check iterations decisions` returns both, separately rendered.

  Dispatch to the `vault-bridge` skill's `/check` section.
  ````

- [ ] **Step 2: Verify frontmatter parses**

- [ ] **Step 3: Commit**
  ```bash
  git add obsidian-bridge/commands/check.md
  git commit -m "feat(obsidian-bridge): /check command with optional sections (replaces status + handoff status)

  Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
  ```

### Task 10: Create `commands/draw.md`

**Files:**
- Create: `obsidian-bridge/commands/draw.md`

- [ ] **Step 1: Write the file**
  ````markdown
  ---
  description: Create or list visual artefacts — canvases, bases, mermaid diagrams
  allowed-tools: Read, Write, Edit, Bash, Glob, Grep
  ---

  Entry point for Obsidian's visual structures. Routes to the right skill based on subverb.

  ## Usage

  ```
  /draw                          List visual artefacts in current project (canvases, bases, recent mermaid blocks)
  /draw canvas <name>            Create or edit a .canvas file (loads canvas skill)
  /draw base <name>              Create or edit a .base file (loads bases skill)
  /draw diagram [type]           Insert a mermaid diagram into the current note (loads mermaid skill)
                                 type optional — flowchart | sequence | class | state | erd |
                                                gantt | mindmap | timeline | gitGraph |
                                                pie | quadrant | journey | C4
  ```

  ## Routing

  Subverb dispatch (no separate `draw` skill — the command body itself routes):
  - `/draw canvas <name>` → loads `obsidian-bridge:canvas` skill, creates/opens `.canvas` file at vault-canonical path (typically `projects/{slug}/canvases/{name}.canvas`).
  - `/draw base <name>` → loads `obsidian-bridge:bases` skill, creates/opens `.base` file (typically `projects/{slug}/bases/{name}.base`).
  - `/draw diagram [type]` → loads `obsidian-bridge:mermaid` skill, inserts a fenced ```` ```mermaid ```` block into the current note (or asks user where to insert if no note open).
  - `/draw` (no subverb) → invokes the `vault-bridge` skill's `draw-list` flow to enumerate visual artefacts in the current project.
  ````

- [ ] **Step 2: Verify frontmatter parses**

- [ ] **Step 3: Commit**
  ```bash
  git add obsidian-bridge/commands/draw.md
  git commit -m "feat(obsidian-bridge): /draw command for visual artefacts (canvas/base/mermaid)

  Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
  ```

### Task 11: Create `commands/ramasse.md`

**Files:**
- Create: `obsidian-bridge/commands/ramasse.md`

- [ ] **Step 1: Write the file**
  ````markdown
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
  ````

- [ ] **Step 2: Verify frontmatter parses**

- [ ] **Step 3: Commit**
  ```bash
  git add obsidian-bridge/commands/ramasse.md
  git commit -m "feat(obsidian-bridge): /ramasse command (replaces reindex + housekeeping)

  Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
  ```

### Task 12: Create `commands/iterate.md`

**Files:**
- Create: `obsidian-bridge/commands/iterate.md`

- [ ] **Step 1: Write the file**
  ````markdown
  ---
  description: Set iteration status (drafting / on-shelf / picked / parked / rejected / superseded). May be sunset in favour of conversational use
  allowed-tools: Read, Write, Edit, Bash, Glob, Grep
  ---

  Set the status of an iteration. Replaces `/vault-bridge iteration-set-status`.

  > **May be sunset.** Iteration creation and listing are conversational ("new iteration D for foo on the navy track", "show on-shelf iterations"). Only state transitions get a command, for mechanical reliability. If conversational handling proves robust across model versions, this command may be removed in a future release. See `obsidian-bridge:vault-bridge` skill for the full iteration workflow.

  ## Usage

  ```
  /iterate <id> <status>                Set iter <id> in current project to <status>
  /iterate <slug>:<id> <status>         Same, but explicit project slug
  ```

  ### Valid statuses

  ```
  drafting       work in progress
  on-shelf       done thinking, available to pick
  picked         selected as the direction
  parked         interesting later, not now
  rejected       no, killed
  superseded     newer iteration replaces this
  ```

  Dispatch to the `vault-bridge` skill's `/iterate` section.
  ````

- [ ] **Step 2: Verify frontmatter parses**

- [ ] **Step 3: Commit**
  ```bash
  git add obsidian-bridge/commands/iterate.md
  git commit -m "feat(obsidian-bridge): /iterate command for state transitions (replaces iteration-set-status)

  Includes 'may be sunset' note in description and body — iteration
  creation and listing are conversational; only state transitions
  get a dedicated command for mechanical reliability.

  Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
  ```

### Task 13: Refresh `commands/dream.md`

**Files:**
- Modify: `obsidian-bridge/commands/dream.md`

- [ ] **Step 1: Read current file**
  ```bash
  cat /Users/tomvanderhegden/.claude/plugins/marketplaces/onnozelaer-claude-marketplace/obsidian-bridge/commands/dream.md
  ```

- [ ] **Step 2: Update description if it doesn't match the new copy**
  Target description (frontmatter line):
  ```
  description: Deep diagnostic — surfaces structural and content issues
  ```

  If the current description differs, edit the YAML frontmatter only. Body stays as-is unless it references old `/vault-bridge` commands (search and update if found).

- [ ] **Step 3: Commit (only if anything changed)**
  ```bash
  git add obsidian-bridge/commands/dream.md
  git commit -m "chore(obsidian-bridge): refresh /dream command description

  Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
  ```

---

## Phase 3 — Remove old `/vault-bridge` command

The `vault-bridge` SKILL stays (it's the engine). Only the `vault-bridge` COMMAND file goes away (it's the old surface).

### Task 14: Delete `commands/vault-bridge.md`

**Files:**
- Delete: `obsidian-bridge/commands/vault-bridge.md`

- [ ] **Step 1: Delete the file**
  ```bash
  rm /Users/tomvanderhegden/.claude/plugins/marketplaces/onnozelaer-claude-marketplace/obsidian-bridge/commands/vault-bridge.md
  ls /Users/tomvanderhegden/.claude/plugins/marketplaces/onnozelaer-claude-marketplace/obsidian-bridge/commands/
  ```
  Expected listing: `check.md  connect.md  draw.md  dream.md  iterate.md  ramasse.md  sync.md` (7 files).

- [ ] **Step 2: Commit**
  ```bash
  git add -u obsidian-bridge/commands/
  git commit -m "feat(obsidian-bridge): remove /vault-bridge command surface

  The /vault-bridge command file is removed in favour of the new 6-verb
  surface (/connect, /sync, /check, /draw, /ramasse, /iterate) plus
  /dream. The vault-bridge SKILL is kept — it's the engine the new
  commands dispatch to. Only the slash-command entry point is gone.

  Per the spec, no deprecation aliases — clean break.

  Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
  ```

---

## Phase 4 — Refactor the `vault-bridge` skill

The skill body needs to be reorganised so each new command's pseudocode lives under the matching verb. Existing logic (create / connect / link / create-project / sync / status / reindex / housekeeping / iteration-set-status / handoff sync) is preserved verbatim, just regrouped.

### Task 15: Restructure `skills/vault-bridge/SKILL.md` around new verbs

**Files:**
- Modify: `obsidian-bridge/skills/vault-bridge/SKILL.md`

This is the largest single edit in the plan (~1000 lines, lots of existing content to regroup). Treat it as a multi-step structural pass.

- [ ] **Step 1: Read the current file in full**
  ```bash
  wc -l /Users/tomvanderhegden/.claude/plugins/marketplaces/onnozelaer-claude-marketplace/obsidian-bridge/skills/vault-bridge/SKILL.md
  ```
  Note the line count for reference.

- [ ] **Step 2: Update the skill description to match the new surface**
  Frontmatter `description:` field — replace with:
  ```
  description: Operate the Obsidian vault. Dispatched by /connect, /sync, /check, /ramasse, /iterate. Use for vault setup, project scaffolding, syncing briefs, status views, cleanup, iteration state.
  ```

- [ ] **Step 3: Restructure the `## Commands` section into the new verb groupings**
  Replace the existing per-command sections (each old `### create`, `### connect`, `### link`, `### create-project`, `### sync`, `### status`, `### archive`, `### unarchive`, `### reindex`, `### housekeeping`, `### set-type`, `### templates`, `### add-collection`) with these new top-level sections:

  ```markdown
  ## Commands

  ### /connect — onboard

  Combined entry for create + connect + link + create-project. Inference rules per the spec:
  - path doesn't exist → create
  - path exists with Home.md (type: vault-home or cabinet-home) → connect
  - path exists with projects/ folder, no Home.md → connect best-effort
  - path exists with neither → error

  Subforms:
  - /connect (no args) — discover or prompt
  - /connect <path> — infer create vs connect
  - /connect <path> <slug> — connect AND link
  - /connect --new <path> — force-create
  - /connect --link-only <slug> — set slug only
  ```

  Followed by a single combined pseudocode block that handles each subform via case analysis. Reuse the existing pseudocode primitives — same logic, regrouped.

  Repeat this pattern for /sync, /check, /ramasse, /iterate. Each gets one section with combined pseudocode.

- [ ] **Step 4: Move conversational operations into a new `## Conversational operations` section**
  Operations that no longer have commands but are still legitimate vault work:
  - add-collection
  - archive / unarchive
  - set-type
  - templates (list / print)
  - migrate (v2 → v3)
  - add-iteration / add-iteration-artefact / iterations (list)

  For each, briefly describe how the model handles it conversationally (intent → existing pseudocode primitives). This section tells the model: "yes, you can still do these things, here's how, just don't expect a slash-command entry."

- [ ] **Step 5: Add the `/iterate` sunset note as its own subsection**
  Inside `### /iterate — state transitions`, add at the end:

  ```markdown
  > **Note on `/iterate`:** This command exists for mechanical state-machine reliability. Iteration creation and listing are conversational (e.g. "new iteration D for foo on navy track", "show on-shelf iterations"). If conversational handling of state transitions proves robust across model versions, /iterate may be sunset in a future release.
  ```

- [ ] **Step 6: Verify the file still has all referenced sections (sanity grep)**
  ```bash
  for verb in connect sync check ramasse iterate; do
    grep -q "^### /$verb" /Users/tomvanderhegden/.claude/plugins/marketplaces/onnozelaer-claude-marketplace/obsidian-bridge/skills/vault-bridge/SKILL.md \
      && echo "$verb: ok" || echo "$verb: MISSING"
  done
  grep -q "^## Conversational operations" /Users/tomvanderhegden/.claude/plugins/marketplaces/onnozelaer-claude-marketplace/obsidian-bridge/skills/vault-bridge/SKILL.md \
    && echo "conversational: ok" || echo "conversational: MISSING"
  ```
  Expected: all `ok`.

- [ ] **Step 7: Commit**
  ```bash
  git add obsidian-bridge/skills/vault-bridge/SKILL.md
  git commit -m "refactor(obsidian-bridge): restructure vault-bridge skill around new 7-verb surface

  Skill body is now organised by new verb (/connect, /sync, /check,
  /ramasse, /iterate) with combined pseudocode per verb. Operations
  that lost their command (add-collection, archive, set-type,
  templates, migrate, iteration creation/listing) move to a new
  'Conversational operations' section so the model knows they're
  still legitimate vault work — just not slash-commands.

  /iterate section includes the sunset note from the spec.

  Skill description updated to match the new surface.

  No business logic changed — same pseudocode primitives, regrouped.

  Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
  ```

---

## Phase 5 — Plugin metadata

### Task 16: Update plugin description in `plugin.json`

**Files:**
- Modify: `obsidian-bridge/.claude-plugin/plugin.json`

- [ ] **Step 1: Read current**
  ```bash
  cat /Users/tomvanderhegden/.claude/plugins/marketplaces/onnozelaer-claude-marketplace/obsidian-bridge/.claude-plugin/plugin.json
  ```

- [ ] **Step 2: Update the `description` field**
  Replace:
  ```
  "description": "Canonical Obsidian-vault layout, schema, primitives, and cleanup workflow for Claude Code. Standalone and cabinet-aware.",
  ```
  With:
  ```
  "description": "Operate an Obsidian vault from Claude — opinionated layout, frontmatter schema, content know-how (canvas, bases, mermaid), and cleanup workflows.",
  ```

- [ ] **Step 3: Verify JSON parses**
  ```bash
  python3 -c "import json; json.load(open('/Users/tomvanderhegden/.claude/plugins/marketplaces/onnozelaer-claude-marketplace/obsidian-bridge/.claude-plugin/plugin.json'))" && echo "ok"
  ```

- [ ] **Step 4: Commit**
  ```bash
  git add obsidian-bridge/.claude-plugin/plugin.json
  git commit -m "chore(obsidian-bridge): refresh plugin description for the new surface

  Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
  ```

### Task 17: Update README

**Files:**
- Modify: `obsidian-bridge/README.md`

- [ ] **Step 1: Read current README**
  ```bash
  cat /Users/tomvanderhegden/.claude/plugins/marketplaces/onnozelaer-claude-marketplace/obsidian-bridge/README.md
  ```

- [ ] **Step 2: Replace the commands section with the new 7-verb surface**
  Use the same table from the spec's "Final command surface" section. Add a one-line note: "See `notes/2026-05-04-command-surface-redesign-migration.md` if you're coming from the old `/vault-bridge ...` surface" (this migration guide is created in Task 19 below).

- [ ] **Step 3: Sweep for references to old commands**
  ```bash
  grep -n "/vault-bridge " obsidian-bridge/README.md
  ```
  Replace any remaining `/vault-bridge subcommand` with the new equivalent.

- [ ] **Step 4: Commit**
  ```bash
  git add obsidian-bridge/README.md
  git commit -m "docs(obsidian-bridge): README reflects the new 7-verb surface

  Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
  ```

---

## Phase 6 — Notes sweep + migration guide

### Task 18: Sweep notes for old command references

**Files:**
- Modify: `obsidian-bridge/notes/mermaid-house-style.md` (if it references old commands)
- Modify: `obsidian-bridge/ATTRIBUTIONS.md` (if it references old commands)

- [ ] **Step 1: Find all references to old commands across the plugin**
  ```bash
  grep -rn "/vault-bridge" /Users/tomvanderhegden/.claude/plugins/marketplaces/onnozelaer-claude-marketplace/obsidian-bridge/ \
    --include="*.md" \
    | grep -v "notes/2026-05-04-command-surface-redesign" \
    | grep -v "skills/vault-bridge"
  ```
  Note: the spec, the plan itself, and the `vault-bridge` skill body are EXCLUDED — those reference old commands intentionally for context/history.

- [ ] **Step 2: For each result, decide and update**
  - If the reference is historical context ("replaces the old `/vault-bridge X`") → keep
  - If the reference is current usage instruction → update to new verb
  - If unclear → ask

- [ ] **Step 3: Commit (only if anything changed)**
  ```bash
  git add -u obsidian-bridge/
  git commit -m "docs(obsidian-bridge): sweep notes/ATTRIBUTIONS for old command references

  Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
  ```

### Task 19: Add migration guide

**Files:**
- Create: `obsidian-bridge/notes/2026-05-04-command-surface-redesign-migration.md`

- [ ] **Step 1: Write the migration guide**
  ````markdown
  # Command surface migration — old → new

  Quick reference for anyone with the old `/vault-bridge ...` and `/dream` surface in muscle memory.

  ## Mapping

  | Old | New |
  |---|---|
  | `/vault-bridge create [path]` | `/connect [path]` (path doesn't exist → creates) |
  | `/vault-bridge create --new [path]` | `/connect --new [path]` |
  | `/vault-bridge connect <path>` | `/connect <path>` (path exists with Home.md → connects) |
  | `/vault-bridge link <slug>` | `/connect --link-only <slug>` |
  | `/vault-bridge create-project <slug> <type>` | conversational ("new project foo, knowledge type") |
  | `/vault-bridge add-collection <name>` | conversational ("add a tasks/ folder to foo") |
  | `/vault-bridge sync` | `/sync` (or `/sync brief` for brief only) |
  | `/vault-bridge handoff sync` | `/sync` (or `/sync handoff` for handoff only) |
  | `/vault-bridge status` | `/check` |
  | `/vault-bridge handoff status` | `/check handoff` |
  | `/vault-bridge archive <slug>` | conversational ("archive foo") |
  | `/vault-bridge unarchive <slug>` | conversational ("unarchive foo") |
  | `/vault-bridge reindex` | `/ramasse indexes` (or `/ramasse` for full sweep) |
  | `/vault-bridge housekeeping` | `/ramasse housekeeping` (or `/ramasse` for full sweep) |
  | `/vault-bridge migrate` | conversational ("migrate this vault to v3") |
  | `/vault-bridge migrate-anchor` | **auto** — runs silently in SessionStart hook |
  | `/vault-bridge set-type <slug> <type>` | conversational ("change foo to plugin type") |
  | `/vault-bridge templates [list\|print <name>]` | conversational ("show me the brief template for coding") |
  | `/vault-bridge add-iteration <id> <slug>` | conversational ("new iteration D for foo on navy track") |
  | `/vault-bridge add-iteration-artefact <id> <file>` | conversational ("attach concept.png to iter D") |
  | `/vault-bridge iterations [<slug>] [--tree]` | `/check iterations` (or conversational) |
  | `/vault-bridge iteration-set-status <id> <status>` | `/iterate <id> <status>` |
  | `/dream` | `/dream` (unchanged) |

  ## Why the change

  The old surface had ~25 subcommands across two slash entries. The new surface is 7 top-level verbs:

  ```
  /connect /sync /check /draw /ramasse /dream /iterate
  ```

  Content creation (decisions, notes, sources, projects, archives, etc.) moves from commands to conversation. Commands now exist only for: lifecycle moments, state-machine transitions, cleanup, diagnostic, and visual artefact entry (canvas/base/diagram via `/draw`).

  See [`2026-05-04-command-surface-redesign.md`](2026-05-04-command-surface-redesign.md) for the full design rationale.

  ## Anchor file location

  The anchor file moved from `$CLAUDE_PROJECT_DIR/.obsidian-bridge` to `$CLAUDE_PROJECT_DIR/.claude/obsidian-bridge`. **You don't need to do anything** — the SessionStart hook auto-migrates legacy anchors silently the next time you open Claude in a project. The `.gitignore` line is also rewritten.
  ````

- [ ] **Step 2: Commit**
  ```bash
  git add obsidian-bridge/notes/2026-05-04-command-surface-redesign-migration.md
  git commit -m "docs(obsidian-bridge): migration guide — old vault-bridge surface → new 7 verbs

  Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
  ```

---

## Phase 7 — Verify and ship

### Task 20: Run all hook test scenarios

- [ ] **Step 1: Re-run the migration test from Task 1**
  ```bash
  bash /tmp/test-migration.sh
  ```
  Expected: legacy file moved, .gitignore rewritten, hook output shows linked vault.

- [ ] **Step 2: Re-run the canonical-anchor scenarios for each hook (compose into one script)**
  Use the test patterns from the validation work earlier in the session — each hook with a fresh tmpdir, canonical anchor only, verify expected output.

- [ ] **Step 3: hooks.json validates**
  ```bash
  python3 -c "import json; json.load(open('/Users/tomvanderhegden/.claude/plugins/marketplaces/onnozelaer-claude-marketplace/obsidian-bridge/hooks/hooks.json'))" && echo "ok"
  ```

- [ ] **Step 4: All command frontmatter parses**
  ```bash
  python3 << 'PYEOF'
  import yaml, re, glob
  for f in glob.glob('/Users/tomvanderhegden/.claude/plugins/marketplaces/onnozelaer-claude-marketplace/obsidian-bridge/commands/*.md'):
      text = open(f).read()
      m = re.match(r'^---\n(.+?)\n---', text, re.DOTALL)
      assert m, f"{f}: no frontmatter"
      yaml.safe_load(m.group(1))
      print(f"{f.split('/')[-1]}: ok")
  PYEOF
  ```

- [ ] **Step 5: All skill frontmatter parses**
  Same shape but glob `skills/*/SKILL.md`.

### Task 21: Smoke test in a real Claude Code session

- [ ] **Step 1: Open Claude Code in a clean test project**
  In a fresh terminal:
  ```bash
  mkdir -p /tmp/cb-test && cd /tmp/cb-test
  claude
  ```

- [ ] **Step 2: Inspect the slash menu**
  Type `/` and visually verify the 7 verbs appear: `/connect`, `/sync`, `/check`, `/draw`, `/ramasse`, `/dream`, `/iterate`. Old `/vault-bridge` should NOT appear.

- [ ] **Step 3: Verify legacy auto-migration works on a real legacy anchor**
  In another terminal:
  ```bash
  mkdir -p /tmp/cb-legacy
  printf 'vault_path=/tmp/some-vault\n' > /tmp/cb-legacy/.obsidian-bridge
  printf '.obsidian-bridge\n' > /tmp/cb-legacy/.gitignore
  cd /tmp/cb-legacy
  claude
  ```
  In the Claude session, the SessionStart hook should fire and the migration notice should appear in the transcript. After session start:
  ```bash
  ls -la /tmp/cb-legacy/.claude/  # should contain obsidian-bridge
  cat /tmp/cb-legacy/.gitignore    # should say .claude/obsidian-bridge
  ```

- [ ] **Step 4: Document any smoke-test surprises in the spec or fix them as follow-up tasks**
  If something didn't work, file a follow-up.

### Task 22: Push the implementation branch

- [ ] **Step 1: Confirm branch state**
  ```bash
  cd /Users/tomvanderhegden/.claude/plugins/marketplaces/onnozelaer-claude-marketplace
  git status
  git log --oneline main..HEAD | head -30
  ```

- [ ] **Step 2: Push**
  ```bash
  git push -u origin feat/command-surface-redesign
  ```

- [ ] **Step 3: Open PR (or merge to main if no review needed)**
  ```bash
  echo "PR link: https://github.com/TomVDH/onnozelaer-claude-marketplace/pull/new/feat/command-surface-redesign"
  ```

  OR if shipping straight to main:
  ```bash
  git checkout main
  git merge --no-ff feat/command-surface-redesign -m "Merge branch 'feat/command-surface-redesign' into main

  Lands the new 7-verb command surface (see notes/2026-05-04-command-surface-redesign.md
  and the migration guide for the old → new mapping)."
  git push origin main
  ```

---

## Done

After Task 22, the new surface is live. Users (= you) running `/<tab>` in any project see the 7-verb surface; legacy anchors auto-migrate; old `/vault-bridge ...` invocations no longer resolve. The `vault-bridge` skill is the engine for everything; the new commands are thin entries that dispatch into it.

## Out-of-scope follow-ups (not part of this plan)

- Sunset `/iterate` once conversational state-transition handling is verified robust (separate decision, separate release).
- Add a `/draw` skill if direct dispatch from the command body proves insufficient (currently expected to work; revisit only if it doesn't).
- Frontmatter schema revisions (rename `project_type` → `kind`, etc.) — separate brainstorm + plan.
- Plugin description / README polish for the marketplace listing — separate small task.
