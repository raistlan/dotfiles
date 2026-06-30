#!/usr/bin/env bash
set -euo pipefail

# install-skills.sh — link portable dotfiles skills AND agents into ~/.claude/.
#
# Run this MANUALLY when you add or rename a skill in dotfiles/.claude/skills/ or
# an agent in dotfiles/.claude/agents/. It is never auto-run by Claude or a hook —
# symlinking into your home dir is a deliberate, user-initiated action. The script
# is idempotent: re-running it is safe and only re-reports already-correct links.
#
# Here is a list of all the commands for you to run manually:
#   The script discovers skills and agents dynamically, so the exact set depends on
#   what currently lives in dotfiles. Each link it creates is one of these, and here
#   is what each links and why:
#
# --- skills (one symlinked dir per dotfiles/.claude/skills/<name>/ with a SKILL.md) ---
# ln -s <dotfiles>/.claude/skills/de-slop            ~/.claude/skills/de-slop
#   Links the portable de-slop rubric skill so `de-slop` is invocable in every
#   project, keeping the canonical copy in dotfiles (not duplicated per repo).
# ln -s <dotfiles>/.claude/skills/grill-me           ~/.claude/skills/grill-me
#   Links the grill-me planning-interview skill so the `/grill-me` trigger and
#   its design-tree interview are available globally.
# ln -s <dotfiles>/.claude/skills/interactive-grilling ~/.claude/skills/interactive-grilling
#   Links the HTML-deck grilling variant (presentation-style grill-me) so it is
#   available globally; linked whenever its SKILL.md exists, even mid-build.
# ln -s <dotfiles>/.claude/skills/interactive-pr-review ~/.claude/skills/interactive-pr-review
#   Links the interactive slideshow PR-review skill (plus its references/ assets)
#   so the deck-based review workflow is invocable in any repo.
# ln -s <dotfiles>/.claude/skills/napkin             ~/.claude/skills/napkin
#   Links the napkin diagram-capture skill so `/napkin` files mermaid diagrams
#   into the workdiary from anywhere.
# ln -s <dotfiles>/.claude/skills/pr-description     ~/.claude/skills/pr-description
#   Links the portable PR-description skill so the canonical PR-description
#   format is invocable globally, deferring to a repo template when present.
#
# --- agents (one symlinked .md file per dotfiles/.claude/agents/<name>.md) ---
# ln -s <dotfiles>/.claude/agents/developer.md       ~/.claude/agents/developer.md
#   Links the portable `developer` agent type (strict-TDD code-craft persona) so
#   `agentType: developer` resolves in any repo — e.g. rudolph phase 3 spawns it.
#
# Any NEW SKILL.md-bearing dir under dotfiles/.claude/skills/, or NEW .md under
# dotfiles/.claude/agents/, is linked the same way by the loops below — add it to
# dotfiles and re-run; no edit to this list is required (it is documentation, not config).
#
# Plain asset dirs (a references/ folder with no SKILL.md, say) are skipped.

# Resolve dotfiles dirs relative to this script, so it works regardless of clone path.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_SRC="$SCRIPT_DIR/.claude/skills"
SKILLS_DEST="$HOME/.claude/skills"
AGENTS_SRC="$SCRIPT_DIR/.claude/agents"
AGENTS_DEST="$HOME/.claude/agents"

mkdir -p "$SKILLS_DEST" "$AGENTS_DEST"

linked=0
skipped=0
warned=0

# link_one <name> <src-path> <dest-path> — idempotent symlink with mismatch guard.
link_one() {
  local name="$1" src="$2" dest="$3"
  if [ -L "$dest" ]; then
    local current
    current="$(readlink "$dest")"
    if [ "$current" = "$src" ]; then
      echo "skipping $name (already linked)"
      skipped=$((skipped + 1))
      return
    fi
    echo "WARN: $name exists but points elsewhere ($current) — leaving it; remove it manually if you want this script to relink it" >&2
    warned=$((warned + 1))
    return
  fi
  if [ -e "$dest" ]; then
    echo "WARN: $name exists and is not a symlink — leaving it; resolve manually" >&2
    warned=$((warned + 1))
    return
  fi
  ln -s "$src" "$dest"
  echo "linking $name -> $src ✓"
  linked=$((linked + 1))
}

# Skills: one dir per skill, must carry a SKILL.md (plain asset dirs are skipped).
for skill_dir in "$SKILLS_SRC"/*/; do
  [ -d "$skill_dir" ] || continue
  name="$(basename "$skill_dir")"
  src="${skill_dir%/}"
  if [ ! -f "$src/SKILL.md" ]; then
    echo "skipping $name (no SKILL.md — not a skill dir)"
    continue
  fi
  link_one "$name" "$src" "$SKILLS_DEST/$name"
done

# Agents: one .md file per agent.
if [ -d "$AGENTS_SRC" ]; then
  for agent_file in "$AGENTS_SRC"/*.md; do
    [ -f "$agent_file" ] || continue
    name="$(basename "$agent_file")"
    link_one "$name" "$agent_file" "$AGENTS_DEST/$name"
  done
fi

echo "done: $linked linked, $skipped already linked, $warned warned"
