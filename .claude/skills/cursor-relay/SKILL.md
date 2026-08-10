---
name: cursor-relay
description: "Relay one self-contained prompt to a Cursor CLI agent (default GPT-5.6 Sol) and block until it replies, then return the reply verbatim. Use when the user asks to hand off, relay, delegate, or farm out work to Cursor / cursor-agent / a GPT model — e.g. \"have cursor write the PR description\", \"ask gpt to draft this\", \"relay this to cursor\"."
context: fork
effort: low
model: sonnet
allowed-tools: ["Write", "Read", "Bash(${CLAUDE_SKILL_DIR}/scripts/relay.sh:*)", "Bash(cursor-agent models:*)"]
---

# cursor-relay

One job: relay a prompt to a Cursor CLI agent, wait, hand the answer back. You add nothing.
You do not do the work yourself and you do not edit the repo — Cursor does both.

## Steps

1. **Write the prompt** to `/tmp/cursor-prompt-<slug>.md`.
2. **Run** `${CLAUDE_SKILL_DIR}/scripts/relay.sh --prompt-file /tmp/cursor-prompt-<slug>.md` (add `--model`/`--mode` when the caller asked for them). It blocks until Cursor is done.
3. **Return the reply verbatim** as your final message. No summary, no commentary, no reformatting. If the caller wanted a PR description, the reply *is* the PR description.

## Writing the prompt

Cursor starts cold in the repo with no memory of this conversation, so the prompt has to stand alone:

- State the deliverable and its exact output format in the first line.
- Name paths, branches, and refs explicitly; `git diff <base>...HEAD` (commonly `git diff main...HEAD`), not "the diff".
- Let Cursor read the repo itself. Reference files instead of pasting them; the prompt is passed as a shell argument, so a pasted diff can blow past `ARG_MAX`.
- Say "output only the X, no preamble" — otherwise you get chatter around the deliverable.

Pass the caller's instructions through faithfully. Don't reinterpret or improve them.

## Options

| Flag | Default | Notes |
|---|---|---|
| `--model` | `gpt-5.6-sol-medium` | Effort is baked into the id, not a separate flag. |
| `--mode` | `ask` | `ask` and `plan` are read-only. `write` lets Cursor edit files — only when the caller explicitly asked for edits. |
| `--out` | `$TMPDIR/cursor-relay.md` | Reply is tee'd here too. |

Sol ladder: `gpt-5.6-sol-{none,low,medium,high,xhigh,max}`. Reach for `-high` on long or structured deliverables. `cursor-agent models` lists everything, including the Terra and Luna 5.6 variants.

## Failures

Report these and stop — don't fall back to doing the work yourself.

- **Exit 3, "not authenticated"** — the user needs to run `cursor-agent login`.
- **Empty or truncated reply** — say so and quote what came back.
