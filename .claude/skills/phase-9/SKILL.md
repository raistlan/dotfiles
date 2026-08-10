---
name: phase-9
description: "Work a round of incoming PR review comments to completion — inventory every open thread, classify into mechanical / needs-ruling / deliverable / draft-only, apply fixes bottom-up across a stack, re-run /quality-pass per PR, and hand back draft replies for the human to post. Repeatable: run it once per review round. This is the Review phase of the rudolph pipeline. Use when the user says /phase-9 or /review, or asks to work review comments, handle a review cycle, or address feedback on a PR or PR stack."
allowed-tools: Bash Read Edit Write Glob Grep Agent Skill AskUserQuestion
---

# /phase-9 — Review, the cycle after the PR opens

A PR is not done when it opens. It's done when the last thread is resolved and it merges. Everything between those two points is **Review**, and it repeats — once per round of incoming comments.

> **Naming.** This is the **Review** phase of the `/rudolph` pipeline, which runs Plan → Architect → Build → Quality → Ship → Exercise → Verify and then hands off here. Review deliberately carries **no phase number** — it repeats N times, so an ordinal would be a lie. The skill keeps the name `/phase-9` from when the pipeline had eight numbered phases; call it *Review* when talking to the human, and track rounds in `state.review_rounds`, not in `state.phase`.

Review can run N times, in a loop, against one or more PRs that has already been reviewed and/or approved by humans. PRs can be in many different shapes, meaning different hazards; stale approvals, moved branches, threads that predate a reshape.

---

## HARD RULE — you draft, the human posts

**Never reply to, comment on, approve, request changes on, or resolve a review thread. On any PR. Ever.** Your output is (a) code changes and (b) draft reply text in a file. Reads are fine (`gh pr view`, `gh pr diff`, the GraphQL `reviewThreads` API).

See "Never speak as me" in `~/.claude/CLAUDE.md` — colleagues read anything posted as the human's own judgment and voice, and that history is only trustworthy if nothing else ever writes to it.

---

## Where state lives

`~/development/workdiary/PIPELINE/<ticket>/`

```
README.md              ← AUTHORITATIVE current state. Wins over every numbered artifact.
state.json             ← machine-readable mirror
NN-review-cycle-<n>.md ← this cycle's work: threads, assessments, what changed
NN-replies-<n>.md      ← DRAFT reply text, one section per thread. Nothing posted.
NN-quality-<pr>.md     ← per-PR `/quality-pass` output, one file per PR re-run
```

Number `NN` continues the run dir's existing sequence. Never renumber or overwrite an earlier cycle's artifacts; supersede them and say so in the README's artifact map.

**Read order at boot:** `README.md` first (it carries a DO-NOT-UNDO list, a reversal log, and environment traps), then `state.json`, then the most recent `NN-review-cycle-*.md`. Earlier numbered artifacts are history and may record decisions since reversed.

---

## Before you reason about any branch

Three checks, every cycle, before anything else. Each of these has produced a confidently wrong conclusion in practice.

1. **Re-fetch and confirm heads.** `git fetch`, then `gh pr view <n> --json headRefOid` for every PR in scope. Compare against what the README claims. Branches move between cycles — including by the human, between your turns.
2. **Assume all approvals don't mean anything.** The repo has `dismissStaleReviewsOnPush: false` so a force-push preserves approvals. This means that a green approval check-mark can be evidence about a tree nobody reviewed.
3. **Confirm nothing is unpushed and no worktree is dirty.** An unpushed commit on a worktree branch is a thread you'll answer wrong.

---

## The loop

### 1 — Inventory every open thread

Pull them all via the GraphQL `reviewThreads` API, not by eyeballing the PR page. Include threads GitHub marks `outdated`. Do not include threads that are marked as resolved. For a stack, do this per PR and record which PR each thread lives on; the fix can belong on a *lower* PR than the thread.

### 2 — Verify "outdated" before believing it

GitHub marks a thread outdated when its anchor line moved, **not** when its point was addressed. A thread can be outdated and exist somewhere else.

For each thread, check against the *current* code whether the concern was actually answered, and classify it:

- **MOOT** — the symbol or code it pointed at no longer exists, and nothing replaced it. Say which commit removed it.
- **ANSWERED** — the concern was addressed. Cite the `file:line` that answers it.
- **STILL LIVE** — the anchor moved but the point stands. Re-anchor it to the current line.

Do not claim a cycle answered a thread without a citation. Threads that predate a reshape are the ones that get this wrong most often.

**Anchors drift.** When re-anchoring, re-read the thread's original diff hunk since an inventory built from line numbers alone will attach a thread to the wrong symbol.

### 3 — Classify into four buckets

This is the step that makes the cycle tractable. Every thread goes in exactly one bucket:

| Bucket | Meaning | What you do |
|---|---|---|
| **Mechanical** | Unambiguous, no judgment needed. Things such as renames, inlines, a missing assertion | Just do it. No gate. |
| **Needs ruling** | A real design call with a tradeoff | **Stop and ask.** One at a time. Bring a recommendation and the tradeoff, not a survey. Write no code first. |
| **Deliverable** | Produces an artifact that isn't code such as a ticket draft or a design sketch | Write it to the run dir and raise to the human to file it. |
| **Draft-only** | Needs a reply, no code change | Reply text only. |

Put the bucket in the cycle artifact next to each thread.

### 4 — Apply fixes, bottom-up

In a stack, a fix belongs on the **lowest PR that owns the code**, not on the tip. Landing it at the tip means the lower PRs stay wrong and the reviewer's next pass re-raises it.

Then cascade. See "Rebasing a stack" below — **including the semantic-conflict sweep, which is not optional.**

### 5 — Re-run `/quality-pass` on every PR you touched

Not just the tip. A rebase changes every descendant's tree.

Invoke the **`/quality-pass`** skill once per PR — never reimplement it. It owns the test audit, the de-slop / prose audit, and the two-lens self-review loop, and it is the single source of truth for all three. It knows nothing about this run dir, so you supply:

- **Diff scope** — `git diff <base>...HEAD` (commonly `git diff main...HEAD`), with `<base>` pinned to an explicit SHA. **For a PR in a stack, `<base>` is the parent PR's head, not `main`.** Get this wrong and the pass audits the parent's work as though it were this PR's, which is the single easiest way to burn a cycle.
- **Output path** — `NN-quality-<pr>.md` in this run dir, absolute. One file per PR; the pass appends all three steps into it. Hand it the path rather than taking the reports back yourself — the tables run to hundreds of rows.
- **Surface** from `state.json`, and the worktree path.

It surfaces its own cut-candidate gate and returns residual High/Medium findings. Fold those residuals into this cycle's artifact — they're your problem now, not a future cycle's.

### 5b — Regenerate the PR description

Separate from the quality pass, and separately mandatory when the tree moved. Invoke the **`pr-description`** skill per PR, **from the diff only** — never from this cycle's context. The description has to read for someone who wasn't in the review.

### 6 — Draft the replies

One section per thread in `NN-replies-<n>.md`:

```markdown
### <PR> · <file:line> · <reviewer>
> verbatim reviewer comment

**Disposition:** taken / declined / moot / deferred to <ticket>
**Reply draft:**
<the text to paste, in the human's voice — direct, specific, no hedging, no thanks-for-the-review>
**Evidence:** file:line, or the artifact that argues it
```

Where a comment was **declined**, the draft has to carry the argument, not the conclusion. Those are the replies that get pushed back on.

### 7 — Update the README, then hand off

The README is authoritative, so it must be true before you stop. Specifically:

- Move anything reversed this cycle into the **reversals** section with a "do not restore" line.
- Update heads, bases, test counts, and the artifact map's "still accurate?" column.
- Append this round to `state.review_rounds` — round number, PRs touched, threads closed, what's still open. That array is how a cold reader knows Review is in progress; `state.phase` stays at `7_verify: done` throughout and says nothing about the tail.
- Re-state the citation convention header: which SHA every `file:line` in the README was read against. A prose or rename cycle moves line numbers by tens, and a citation read against the old head silently misses.

Then give the human: what changed, what needs their ruling, what's drafted and where, and what they need to post or file.

---

## Rebasing a stack

Bottom-up, with **explicit SHAs** — never branch names:

```
git rebase --onto <new-parent-head> <old-parent-head> <branch>
```

`rerere` will record conflict resolutions; expect conflicts wherever two PRs touched the same docstring.

### Then run the semantic-conflict sweep. Every time.

**A rebase produces conflicts Git cannot see.** Git merges by text; it has no idea that a hunk it merged cleanly is now wrong. This has happened three separate times in one cycle, and all three merged cleanly and all three were wrong:

1. **A test pinning an exact list started asserting the wrong thing.** A test asserted `tags == ["a", "b"]`. An ancestor PR added a new tag `"c"` to that emission. The rebase merged both cleanly — the test file's line was untouched by the ancestor — so the test now silently asserts that the ancestor's *new* tag is **absent**. Green locally on the branch; the assertion is backwards.
2. **An auto-merged hunk re-introduced a deleted name.** The ancestor folded metric `foo.bar.baz` into `foo.bar` + a tag. The descendant's hunk still contained the old name in a region Git took wholesale. The fold was silently undone one PR up.
3. **A test called a helper the branch had renamed.** The descendant renamed `_foo` → `_bar`; a test added on the ancestor still called `_foo`. Clean merge, `AttributeError` at runtime.

The shared shape: **the two sides never touched the same lines, so Git had nothing to flag.**

So after every rebase, before running anything:

- Sweep every exact-collection assertion (`== [`, `== {`, `assertEqual([`) in the touched test files and re-derive what the current code actually emits.
- Grep the whole stack for any name an ancestor removed, renamed, or folded away this cycle. Keep a running list of those names in the cycle artifact — that list *is* the sweep's input.
- Re-run the full test files at **every level** of the stack, not just the tip, and confirm the counts against the README.

Order-sensitive assertions are the fragile ones. If production emits the same collection in inconsistent orders across sites, normalizing production to one order is usually cheaper than maintaining the assertions.

---

## Hygiene, every cycle

Each round:
- Remove worktrees parked on superseded heads (`git worktree remove`, then `git worktree prune` — hand-deleted directories linger in `$GIT_DIR/worktrees` and keep showing in `git worktree list`).
- Reset stale local refs that lag `origin` — a stale local branch that gets pushed re-pushes an old tree.
- List backup/safety tags created this cycle in the artifact so they can be reaped later.

Debt that isn't urgent goes to the weekly sweep list (`~/development/workdiary/PIPELINE/CLEANUP.md`), not into the next cycle's prompt. **Exception:** anything that blocks a launch is not debt — surface it at the gate every single cycle until it's filed.

---

## Escalation

A thread that needs more than a contained fix like a reshape, a new abstraction, or a change that moves the architecture is **not** phase-9 work. Hand it back: return to implementing (small) or planning (if the design itself is in question), record the handoff in the cycle artifact, and say so.

Trying to absorb a reshape inside a review cycle is how a 3-PR stack becomes a 5-PR stack with approvals that no longer describe the tree.

---

## Conventions

- Cite the domain or sub-domain and `file:line` for every claim about the code. Verify before asserting.
- Ask before pushing. Push with `--force-with-lease=<ref>:<expected-sha>`, never bare `--force`.
- Never `--no-verify`.
- Reuse the parent ticket for follow-ups unless the human names a new one.
