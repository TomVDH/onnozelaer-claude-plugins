# Housekeeping checks

The 16 structural and content checks `/ramasse housekeeping` runs.
Each check is **auto-fixable** or **needs-decision**. Auto-fixable
items are applied (with confirmation prompt for "fix all" / "pick" /
"skip"). Needs-decision items are reported only.

Scope: current project if linked, otherwise vault-wide.

---

## Checks

| # | Check | Trigger | Resolution |
|---|---|---|---|
| 1 | Empty project folder | No `.md` files and no subfolders | needs-decision: archive or delete? |
| 2 | Missing `brief.md` | Project has no `brief.md` | auto-fix: scaffold from type template (ask type if unknown) |
| 3 | Slug shape violation | Contains dots, spaces, or uppercase | needs-decision: rename? |
| 4 | Collection missing `_index.md` | Subfolder with ≥2 `.md` siblings (excluding `sessions/`, `images/`, `assets/`) lacks `_index.md` | auto-fix: create from `collection-index` template |
| 5 | `_index.md` out of sync | Index entries don't match `.md` siblings | auto-fix: rebuild from disk |
| 6 | Missing frontmatter | `.md` file (excluding `.obsidian/`, `templates/`) has no YAML | auto-fix: add minimal valid frontmatter based on location |
| 7 | Incomplete frontmatter | File missing required fields for its type | auto-fix: add missing required fields with defaults |
| 8 | Broken wikilink | `[[target]]` doesn't resolve | needs-decision: keep, fix, or remove? |
| 9 | Markdown-style link | `[text](path)` instead of `[[wikilink]]` | auto-fix: convert to wikilink |
| 10 | Tag clutter | Single-use tag, near-duplicates (e.g. `#postgres` vs `#postgresql`) | needs-decision: merge or keep? |
| 11 | Stale `updated` date | `status: active` AND `updated` > 90 days ago | needs-decision: still active? |
| 12 | Decision filename pattern | File in `decisions/` not matching `YYYY-MM-DD-{kebab}.md` | auto-fix: rename to correct pattern |
| 13 | Session filename pattern | File in `sessions/` not matching `YYYY-MM-DD.md` | auto-fix: rename or merge same-day |
| 14 | Root doc missing `type: doc` | `.md` in project root (not `brief.md`, `_handoff.md`, `_index.md`) lacks `type: doc` | auto-fix: add `type: doc` frontmatter |
| 15 | Brief body missing required blocks | Per `project_type`, required `##` blocks absent | auto-fix: add empty block with placeholder |
| 16 | Unknown slug in `relations` | `relations.parents`/`children`/`related` references a slug that doesn't exist as `projects/{slug}/brief.md` or `archive/{slug}/brief.md` | needs-decision: fix or drop? |

---

## Required blocks by project type

Used by check #15.

| `project_type` | Required `##` blocks |
|---|---|
| `coding` | `INTRO`, `TECHNICAL STACK`, `CONSTRAINTS`, `USER DECISIONS`, `WORK NOTES` |
| `knowledge` | `INTRO`, `THESIS`, `EVIDENCE`, `OPEN QUESTIONS` |
| `plugin` | `INTRO`, `SURFACE`, `INTERNALS`, `RELEASES`, `WORK NOTES` |
| `tinkerage` | `INTRO`, `WORK NOTES` |

See `obsidian-bridge:vault-standards` for the full brief schema.

---

## Report shape

```
## Auto-fixable ({count})
- <description>
- <description>
[Fix all] [Pick] [Skip]

## Needs decision ({count})
- <description>
- <description>
```

User chooses: **Fix all** runs all auto-fixes sequentially. **Pick**
presents each, user approves/skips. **Skip** done.
