# Vault content style

All vault body copy must be **actionable, clear, unambiguous, and
short**. Files are read by both humans and AI agents — both deserve
crisp output. Fluff, hedging, and throat-clearing are forbidden.
Apply to every body section of every file type.

---

## Voice and tense

- **Active voice.** "We chose Postgres." Not "Postgres was chosen."
- **Present tense for current state.** "The auth flow uses JWT."
- **Past tense for decisions and events.** "On 2026-04-30 we switched to JWT."
- **Imperative for instructions.** "Run `/sync` after every brief edit." Not "You should run /sync."
- **First-person plural for project decisions** ("we"); third-person for facts ("the auth flow").

## Structure

- **Short paragraphs.** 1–3 sentences. Break frequently. Walls of text fail both AI parsing and human scanning.
- **Headings as outline.** H2 = section, H3 = subsection. Don't skip levels (no H2 → H4). No H1 in body — the file is its own H1.
- **Lists when enumerating.** "First… second… third" inline → make it a list.
- **Tables when comparing.** ≥2 items with shared dimensions → table, not prose with "whereas X…"
- **Code fences with language tags.** ```bash, ```python, ```yaml, etc. Plain ` ``` ` only when truly language-agnostic.
- **One blank line between blocks.** Two only at major section breaks. Never three.
- **Wikilinks for vault-internal references** (`[[projects/foo/brief|foo]]`). Markdown-style links inside the vault are forbidden — `/dream` flags violations. External URLs use markdown (`[GitHub](https://…)`) or bare angle brackets (`<https://…>`).

## Callouts — signal, not emphasis

Callouts mark the *type* of information. Never use them for "look at this!" emphasis (that's bold's job, sparingly).

| Callout | Use for |
|---|---|
| `> [!note]` | Aside or context that's true but tangential |
| `> [!tip]` | A non-obvious trick or shortcut |
| `> [!warning]` | A real foot-gun |
| `> [!important]` | A constraint that, if missed, breaks something |
| `> [!example]` | A worked example demonstrating a rule |
| `> [!quote]` | Direct quote from a source |

Don't stack callouts. Don't use them as section dividers. Aim for ≤1 callout per ~3 paragraphs of body.

## Cuts — delete on first read

Words and phrases that almost always remove cleanly:

- "I think", "perhaps", "it might be the case that" — say it or don't
- "In this document, we will…" / "The purpose of this section is…" — just write the content
- "As mentioned above" / "as you can see" — references the reader is forced to scroll for
- "Basically", "essentially", "simply" — usually a tell that the next claim isn't simple
- "Of course", "obviously" — patronising
- Adverbs that don't change meaning ("very", "really", "quite", "actually", "just")
- Restating a heading in the first sentence of its section — get to the point

## Acceptance-test friendly

Every claim should be checkable:

- "Auth uses JWT" — check the code → yes/no ✓
- "We deploy on Tuesdays" — check the calendar → yes/no ✓
- "This is robust" — not checkable ✗ — say what it tolerates ("survives DB restart") or cut

---

## Reference body shapes

Common shapes that work. Use them unless the file's specific
frontmatter spec says otherwise.

### Decision body

```markdown
## Decision
[1–3 sentences. The actual decision in plain language.]

## Context
[Why this decision needed to be made. The constraints. 2–4 sentences.]

## Consequence
[What this commits us to. What we accepted in trade. 2–4 sentences.]

[Backlink to brief]
```

### Note body (atomic)

```markdown
[Single idea. 1–3 paragraphs.]
[Wikilinks to related notes inline.]
```

### Doc body (sectioned)

```markdown
[1–2 sentence purpose statement.]

## [Section]
[Content. Short paragraphs. Lists where relevant.]

## [Section]
[Content.]
```

### Source body (capture)

```markdown
[1–3 sentences: why this source is in the vault.]

## Notes
- [Bullet list of takeaways or pull quotes.]

## Cited in
- [[Wikilinks to vault notes that reference this source.]]
```

### Iteration body

```markdown
[1–2 sentences: what this iteration explores.]

## Approach
[The shape of the variant. Bullet list if multiple moving parts.]

## Strengths / Weaknesses
| Strengths | Weaknesses |
|---|---|
| … | … |

## Verdict
[Why drafting / on-shelf / picked / parked / rejected. 1–3 sentences.]
```

---

## Validator behaviour

The `PostToolUse` validator hook checks **frontmatter**. The content
style rules above are *not* mechanically enforced — style is
judgment. `/dream` (Pass 2) flags suspected style violations for
human review: wall-of-text paragraphs, callout misuse, throat-clearing
openings, restating-the-heading patterns.
