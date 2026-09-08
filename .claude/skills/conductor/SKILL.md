---
name: conductor
description: "Boot a CONDUCTOR agent for a multi-ticket rudolph pipeline. Scaffolds a self-contained per-project CONDUCTOR handoff by splicing the generic conductor role (from the `conductor` agent definition) into a project-specific board, then hands back the exact `claude --bg` launch command to run from the repo root. Use when the user says /conductor, or asks to boot/start/spin up a conductor, a pipeline conductor, or a board-keeper for a project's rudolph builders."
allowed-tools: ["Read", "Write", "Edit", "Bash(date:*)", "Bash(mkdir:*)", "Bash(test:*)", "Bash(ls:*)", "Skill", "mcp__linear__get_project", "mcp__linear__list_issues", "mcp__linear__get_issue"]
---

# Conductor

Boot a CONDUCTOR: a long-lived session that runs a project's rudolph build pipeline as a message bus, board keeper, stack steward, and builder launcher. This skill does two things — it writes a **self-contained per-project handoff** and it gives the **exact launch command**. It does not launch the session itself; the user runs the command (or tells you to), because the session must be launched from the target repo root.

The role itself is generic and lives in one place: the `conductor` agent definition (`~/.claude/agents/conductor.md`, source in this dotfiles repo at `.claude/agents/conductor.md`). This skill splices that generic role into the project-specific board. Read the agent definition first — it is the source of truth for the duties and non-negotiables, and the handoff inlines it verbatim rather than paraphrasing.

## Why the handoff must be self-contained

The launch command is `claude --bg --name "CONDUCTOR [<project>]" "$(cat <handoff-path>)"`. The handoff is `cat`-ed into a single prompt string on argv — no `@import` resolution runs on it, so nothing the handoff references by path is pulled in automatically. Everything the conductor needs at boot has to be in the file itself. Inline the generic role; do not link to it.

## Inputs to gather first

Ask the user for whatever you cannot infer, in one batched question — do not interrogate:

- **Project name** — the display name (e.g. `Minor IDV`) and a short slug for paths and the session name (e.g. `minor-idv`).
- **Repo root** — the absolute path the conductor and every builder launch from (e.g. `/Users/raistlan/development/headway`). This is where the project MCP servers load.
- **Tracker** — Linear team and project URL, or whichever tracker holds the tickets. If Linear and the MCP is available, read the project (`get_project`, `list_issues`) to seed the board rather than asking the user to type it.
- **Governing documents** — does the project have a working agreement, tech spec, decision log, or similar that binds the conductor? Name them and where they live. If none, say so and the handoff's governing-docs section shrinks to a line.
- **Builder prompts** — where the per-ticket rudolph launch prompts live (e.g. a `handoffs-<date>/launch/` dir), if any are staged. The handoff lists them under "Up next".

## Locate or scaffold the handoff

Handoffs live under the workdiary, one dated dir per generation:

```
~/development/workdiary/PIPELINE/<slug>/handoffs-<YYYY-MM-DD>/CONDUCTOR-handoff.md
```

Get today's date with `date +%Y-%m-%d`. If a `CONDUCTOR-handoff.md` already exists for this project (any dated dir), read the most recent one — it is the authoritative prior state and the new handoff should carry its board forward, not start blank. Create the dated dir with `mkdir -p` before writing.

## Handoff structure

Mirror the shape of the two reference handoffs at `~/development/workdiary/PIPELINE/minor-idv/handoffs-2026-09-08/CONDUCTOR-handoff.md` (most recent, authoritative) and `~/development/workdiary/PIPELINE/minor-idv/handoffs-2026-09-04/CONDUCTOR-handoff.md` (earlier, shows what is stable vs project-specific). Read both before writing so the generated handoff matches their voice and section order. The stable spine, in order:

1. **Identity line** — one paragraph: who the conductor is, the project and tracker URL, the repo root, the instruction to launch from that root so the project MCP loads, and the exact session name `CONDUCTOR [<project>]`. Stamp it with the generation date and a note to rebuild the board from live data before trusting the snapshot.
2. **Your job, and only your job** — the five duties (message bus, launcher/relauncher, occupancy steward, board keeper, stack steward). Inline these from the `conductor` agent definition; keep any project-specific launch-prompt paths.
3. **Model and effort** — inline the policy table from the agent definition verbatim (conductor `opus[1m]`/medium; planning and verification — rudolph Plan, Architect, Quality, Verify — `fable[1m]`/high; development — Build, Ship, and fix agents — `opus[1m]`/medium), plus the rule that the model swaps at the phase boundary alongside the occupancy relaunch and the zsh quoting hazard on `[1m]` aliases. The conductor launches every builder itself, so this table is what actually governs which model each phase runs on — a handoff that omits it produces builders on the user's global default.
4. **Non-negotiables** — draft-only GitHub/Slack, marked Linear comments, never edit a governed Tech Spec, never author a Decision Log entry as the decider, refuse permission laundering. Inline from the agent definition, then add whatever the project's own working agreement makes stricter.
5. **Governing documents** — the project's binding docs, how to read them (e.g. the `work-with-linear-project` skill with the team and project as args), and the current decisions worth citing. Omit or shrink to a line if the project has none.
6. **Board snapshot** — Done, In Review (PR open), In Progress (building), Up next (unblocked, no session). Seed it from the tracker if reachable; otherwise leave a clearly-labeled skeleton and tell the conductor to rebuild it first. Always mark it stale-by-construction.
7. **Machine and CI hazards** — the shadowed-binary and lease-push traps, MCP-is-cwd-scoped, migration-drift and merge-queue quirks. These are largely generic to this machine; carry them forward from the reference handoffs and the agent definition, dropping any that do not apply to the target repo.
8. **First actions** — read the governing docs, rebuild the board, ListAgents and introduce yourself to live builders, then wait for the user.

Keep the project-specific content (ticket ids, PR numbers, decision numbers, stack state) out of the generic sections and confined to the board and governing-docs sections, so a later regeneration only has to refresh those.

## The launch command

After writing the handoff, print the command for the user to run **from the repo root** (not the workdiary, or the Linear write MCP will not load):

```bash
cd <repo-root> && claude --bg --model 'opus[1m]' --effort medium --name "CONDUCTOR [<project>]" "$(cat ~/development/workdiary/PIPELINE/<slug>/handoffs-<YYYY-MM-DD>/CONDUCTOR-handoff.md)"
```

Both flags are part of the command, not decoration: without them the conductor inherits whatever model and effort the user's global settings carry, and a conductor on a small model mangles the relay. Medium effort is right for the role — it relays and books, and hands every judgment to a builder. Quote any `[1m]` alias; in zsh the brackets are a glob and the command dies before `claude` runs.

State plainly that the session must be launched from the repo root, name the handoff path, and stop. Do not launch it yourself unless the user tells you to.

## Prose rules

Write the handoff in the user's voice and format: each paragraph one unbroken line, no hard-wrapping. Comments and notes state why, not what. Do not invent board state — if the tracker was unreachable, say so in the handoff and in your report rather than guessing ticket status.

## Installation note

This skill and the `conductor` agent definition live in the dotfiles repo. They are only invocable after they are symlinked into `~/.claude/` by the repo's `install-skills.sh` — run it once after adding them; it is never auto-run.
