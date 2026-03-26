# Vault Images — Screenshot-to-Vault Pattern

Capture screenshots from preview servers and write them directly into the vault's per-project `images/` folder, then embed them in session notes and decision docs using `![[wikilinks]]`. Obsidian renders them inline and syncs via iCloud.

**Why this matters:** Written specs fail to convey visual design decisions. A screenshot closes the context gap — especially when handing off between Claude Code instances via `/cabinet-resume`, where the receiving session needs to see the exact visual state. It also prevents regressions: "this is what it looked like when it was working."

First used: 2026-03-26, DutchBC PoC — 5 screenshots captured (playground state, Q/X/K direction heroes) for cross-session handoff.

---

## How to Capture

```pseudocode
// 1. Ensure the images directory exists
BASH: mkdir -p {vault_base}/projects/{slug}/images/

// 2. Scroll to the right section first (Playwright captures viewport, not full page)
mcp__plugin_playwright__browser_evaluate: window.scrollTo(0, 0)
// OR use fullPage: true if supported

// 3. Take the screenshot directly to the vault path
mcp__plugin_playwright__browser_take_screenshot:
    filename = "{vault_base}/projects/{slug}/images/{descriptive-name}.png"
    type     = "png"   // lossless — preferred for design screenshots

// DO NOT use preview_screenshot — it cannot save to a custom path
```

---

## How to Embed

In session notes or decision docs, embed with a caption below:

```markdown
![[descriptive-name.png]]
*Caption: what this shows and why it was captured.*
```

Obsidian resolves the filename by shortest path — no full path needed in the embed, just the filename.

---

## Naming Convention

Files live at: `projects/{slug}/images/{descriptive-name}.png`

Name files descriptively and specifically:

| Good | Avoid |
|------|-------|
| `playground-current-dark-default.png` | `screenshot.png` |
| `direction-q-oxidised-hero.png` | `image1.png` |
| `auth-flow-gate2-approved.png` | `test.png` |

---

## Gotchas

**iCloud vault paths are long.** Always use the absolute path for capture (e.g. `/Users/tom/Library/Mobile Documents/iCloud~md~obsidian/Documents/Claude Cabinet/projects/{slug}/images/`). The `![[filename.png]]` embed in the note uses just the filename — Obsidian resolves it.

**Playwright captures the viewport.** Scroll to the right section before capturing, or pass `fullPage: true` where supported. The `browser_evaluate` tool with `window.scrollTo(x, y)` is the reliable approach for targeting a specific section.

**Use `mcp__plugin_playwright__browser_take_screenshot`, not `preview_screenshot`.** The preview screenshot tool cannot write to arbitrary paths — it will not land in the vault.
