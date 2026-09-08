---
name: cursor-relay
description: "Hand one self-contained prompt to a Cursor agent and return its reply verbatim. Two transports: a local Cursor CLI relay that blocks for read-only work, and a Cursor Cloud Agent for work needing write access, services, fixtures, or a browser (E2E). Use when the user asks to hand off, relay, delegate, or farm out work to Cursor / cursor-agent / a GPT model, or to run an E2E / browser test in Cursor's cloud — e.g. \"have cursor write the PR description\", \"ask gpt to draft this\", \"kick off the E2E in cursor cloud\"."
context: fork
effort: low
model: sonnet
allowed-tools: ["Write", "Read", "Bash(${CLAUDE_SKILL_DIR}/scripts/relay.sh:*)", "Bash(${CLAUDE_SKILL_DIR}/scripts/cloud.sh:*)", "Bash(cursor-agent models:*)", "Bash(git remote get-url:*)"]
---

# cursor-relay

One job: hand a prompt to a Cursor agent and hand the answer back. You add nothing.
You do not do the work yourself and you do not edit the repo — Cursor does both.

## Pick the transport first

| | `scripts/relay.sh` (local CLI) | `scripts/cloud.sh` (Cloud Agent) |
|---|---|---|
| Runs in | this machine, this checkout | Cursor's own cloud environment |
| Blocking | yes, always | `launch` is async; `wait` blocks |
| Can write files | only with `--mode write` | yes |
| Can start services / docker / a browser | **no** | yes |
| Good for | drafting prose, reviewing a diff, answering a question | E2E, browser QA, anything needing fixtures or a running stack |

**The failure this table exists to prevent:** `relay.sh` defaults to `--mode ask`, which is read-only. It cannot fetch refs, create worktrees, start a dev server, or seed fixtures. Handing it an E2E task produces a confident "could not run" and wastes the round trip. If the task needs a *running application*, use `cloud.sh`.

## Local relay — steps

1. **Write the prompt** to `/tmp/cursor-prompt-<slug>.md`.
2. **Run** `${CLAUDE_SKILL_DIR}/scripts/relay.sh --prompt-file /tmp/cursor-prompt-<slug>.md` (add `--model`/`--mode` when the caller asked for them). It blocks until Cursor is done.
3. **Return the reply verbatim** as your final message. No summary, no commentary, no reformatting. If the caller wanted a PR description, the reply *is* the PR description.

### Options

| Flag | Default | Notes |
|---|---|---|
| `--model` | `gpt-5.6-sol-medium` | Effort is baked into the id, not a separate flag. |
| `--mode` | `ask` | `ask` and `plan` are read-only. `write` lets Cursor edit files — only when the caller explicitly asked for edits. |
| `--out` | `$TMPDIR/cursor-relay.md` | Reply is tee'd here too. |

Sol ladder: `gpt-5.6-sol-{none,low,medium,high,xhigh,max}`. Reach for `-high` on long or structured deliverables. `cursor-agent models` lists everything, including the Terra and Luna 5.6 variants.

## Cloud agent — steps

1. **Write the prompt** to `/tmp/cursor-prompt-<slug>.md`.
2. **Launch** against a *pushed* branch — the cloud clones from the remote, so unpushed commits are invisible:

   ```bash
   ${CLAUDE_SKILL_DIR}/scripts/cloud.sh launch <branch> --prompt-file /tmp/cursor-prompt-<slug>.md
   ```

   Prints `agentId`, `runId`, `url`, `repo`, `startingRef`. **Report the URL to the caller** — it is how a human watches the run.
3. **Then either** hand back the ids and let the caller poll (right for a long E2E), **or** block:

   ```bash
   ${CLAUDE_SKILL_DIR}/scripts/cloud.sh wait <agentId> <runId> --timeout 1800
   ${CLAUDE_SKILL_DIR}/scripts/cloud.sh status <agentId> <runId>
   ```

   `wait` prints the run's result text on stdout; return it verbatim. It exits 4 if the run ended in any state other than `FINISHED`, and 5 on timeout — a timeout does **not** cancel the run.

### Options

| Flag / env | Default | Notes |
|---|---|---|
| `--repo` / `CURSOR_RELAY_REPO_URL` | derived from `git remote get-url origin` | Normalizes `git@`, `ssh://`, and `https://` forms. Derived from the **current directory's** repo, so `cd` to the right one or pass `--repo`. |
| `--model` / `CURSOR_RELAY_CLOUD_MODEL` | `claude-sonnet-4-5` | Cloud model ids differ from the local CLI's. |
| `CURSOR_API_KEY` | — | Required. Ambient env, else `$CURSOR_RELAY_ENV_FILE`, else `~/.config/cursor-relay/.env`. Never echoed. |

`autoCreatePR` is hard-wired off. If the caller wants a PR, they open it.

## Writing the prompt

Cursor starts cold with no memory of this conversation, so the prompt has to stand alone:

- State the deliverable and its exact output format in the first line.
- Name paths, branches, and refs explicitly; `git diff <base>...HEAD` (commonly `git diff main...HEAD`), not "the diff". If the base is not the default branch, say so — a stacked PR's base is another branch.
- Let Cursor read the repo itself. Reference files instead of pasting them; the local relay passes the prompt as a shell argument, so a pasted diff can blow past `ARG_MAX`.
- Say "output only the X, no preamble" — otherwise you get chatter around the deliverable.
- For anything empirical, name the **control** — the condition that rules out the alternative explanation — and add: *if you cannot run it, say "could not run" and name the blocking step; do not simulate or infer a result.* A fabricated pass is worse than no answer.

Pass the caller's instructions through faithfully. Don't reinterpret or improve them.

## Failures

Report these and stop — don't fall back to doing the work yourself.

- **relay.sh exit 3, "not authenticated"** — the user needs to run `cursor-agent login`.
- **cloud.sh "CURSOR_API_KEY not set"** — relay the setup line it prints; don't guess a key location.
- **cloud.sh "launch failed"** — quote the raw Cursor response; it carries the reason (bad ref, repo not connected to the Cursor GitHub App, plan without cloud agents).
- **Empty or truncated reply** — say so and quote what came back.
