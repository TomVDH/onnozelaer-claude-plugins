#!/usr/bin/env bash
# user-prompt-vault-reminder.sh — UserPromptSubmit hook for obsidian-bridge
#
# Reminds the user to link a vault, but ONLY when their message looks like
# vault-related work AND only ONCE per session.
#
# Suppression rules (any one → silent exit):
#   1. Canonical anchor file exists at .claude/obsidian-bridge
#   2. .cabinet-anchor-hint exists (cabinet plugin can resolve a vault)
#   3. User-level default breadcrumb at ~/.claude/obsidian-bridge
#   4. OB_DEFAULT_VAULT env var is set
#   5. The user's prompt contains no vault-related keywords
#   6. Already reminded this session (.claude/.ob-reminded sentinel present)
#   7. OB_REMINDER_DISABLE=1 env var is set (escape hatch)
#
# After firing, drops a sentinel `.claude/.ob-reminded` so the reminder
# is at most one-per-session. The SessionStart hook clears the sentinel.
set -euo pipefail

main() {
  # Escape hatch
  [ "${OB_REMINDER_DISABLE:-0}" = "1" ] && return 0

  local project_dir="${CLAUDE_PROJECT_DIR:-}"
  [ -z "$project_dir" ] && return 0

  # 1. Canonical anchor file exists → vault is linked, no reminder needed
  # (Legacy .obsidian-bridge is auto-migrated by SessionStart hook step 0.)
  [ -f "$project_dir/.claude/obsidian-bridge" ] && return 0

  # 2. Cabinet anchor hint → vault discoverable via cabinet plugin
  [ -f "$project_dir/.cabinet-anchor-hint" ] && return 0

  # 3. User-level default breadcrumb → global vault fallback
  [ -n "${HOME:-}" ] && [ -f "${HOME}/.claude/obsidian-bridge" ] && return 0

  # 4. Default vault env → vault discoverable via fallback
  [ -n "${OB_DEFAULT_VAULT:-}" ] && return 0

  # 5. Already reminded this session → don't repeat
  [ -f "$project_dir/.claude/.ob-reminded" ] && return 0

  # 6. Read the user's prompt from stdin (JSON payload)
  local input prompt=""
  input=$(cat 2>/dev/null || true)
  if [ -n "$input" ]; then
    if command -v python3 >/dev/null 2>&1; then
      prompt=$(printf '%s' "$input" | python3 -c 'import json,sys
try:
  print(json.load(sys.stdin).get("prompt",""))
except Exception:
  pass' 2>/dev/null || true)
    elif command -v jq >/dev/null 2>&1; then
      prompt=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null || true)
    fi
  fi

  # If we could not parse a prompt, fall back to firing once
  # so we don't silently swallow the reminder when stdin is empty.
  if [ -z "$prompt" ]; then
    fire_reminder "$project_dir"
    return 0
  fi

  # 7. Keyword-gate: only fire on vault-related signals
  # Conservative regex — false positive = one harmless extra reminder.
  local pattern='vault|obsidian|frontmatter|wiki[ -]?link|/connect|/sync|/check|/dream|/ramasse|/draw|/iterate|#ob/|_handoff\.md|_index\.md|brief\.md|\.base\b'
  if printf '%s' "$prompt" | grep -qiE "$pattern"; then
    fire_reminder "$project_dir"
  fi
}

fire_reminder() {
  local project_dir="$1"
  printf 'No vault linked. Run /connect before vault-dependent work (or set OB_DEFAULT_VAULT, or write ~/.claude/obsidian-bridge for a global default).'
  # Drop sentinel so we don't repeat this session
  mkdir -p "$project_dir/.claude" 2>/dev/null || true
  : > "$project_dir/.claude/.ob-reminded" 2>/dev/null || true
}

main "$@"
