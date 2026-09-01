---
name: quality-pass
description: Run the three-step quality pass over a change — mutation-backed test audit, de-slop / prose audit, and a two-lens self-review loop (in-module + out-of-module). Re-runnable against a single PR after a rebase, a review cycle, or a stack split. Use when the user says /quality-pass, or asks to audit tests, de-slop and self-review a branch or PR before it goes out. Invoked by /rudolph as phase 4 and by /phase-9 once per PR touched.
allowed-tools: Bash Read Edit Write Glob Grep Agent Skill AskUserQuestion
---

# /quality-pass — audit, cut, self-review

Three steps over one change, in order. Each one spawns fresh subagents and keeps only their returned summaries, so the pass can run repeatedly without the invoking session growing.

| Step | What | Runs as | Produces |
|---|---|---|---|
| **Audit** | Test audit + necessity breakdown, mutation-backed | subagent (+ conditional gate) | test-audit report |
| **Cut** | De-slop / prose audit | `code-simplifier` + subagent | slop report |
| **Self-review** | Two-lens review→fix loop, capped at 3 rounds | subagents | self-review report |

The steps are ordered by what each one makes cheaper for the next: Audit deletes tests so Cut has less prose to read, and Cut shrinks the diff so Self-review has less surface to review. Run them in order; don't parallelise them.

## Invocation contract

This skill knows nothing about where it is being run from — no run directory, no ledger, no artifact naming convention. The caller owns all of that and supplies:

| | |
|---|---|
| **Diff scope** | `git diff <base>...HEAD` (commonly `git diff main...HEAD`). Pin `<base>` to an explicit SHA, not a ref name — refs move underneath a pass that takes this long. **In a stack, `<base>` is the parent PR's head, never `main`** — basing on `main` audits the parent's work as though it were this PR's. |
| **Surface** | `frontend` \| `backend` \| `both` — selects the testing-patterns skill in Audit. Infer it from the diff if the caller doesn't say. |
| **Output** | Where each report goes: absolute paths, or nothing. See below. |
| **Worktree** | The path to work in, if the caller is running as a background job. |

### Where the output goes

**The caller decides. This skill never invents a path or a filename.**

- **Caller supplied paths** → each step's subagent writes its report straight to the path it was given, and this skill returns only the summary. Prefer this: the subagent already holds the report, so routing hundreds of table rows back through the caller's context to be written out again is pure cost, and the callers of this skill are conductors whose whole job is staying thin.
- **Caller supplied none** → return each report inline, in full, for the caller to place. This is the standalone case: a human running `/quality-pass` on a branch wants to read the tables, not go find them.

If the caller gives **one** path for all three steps, append under a per-step heading — never overwrite. Three paths, three files; one path, one file with three sections.

Either way, always return a **≤12-line summary**: one line per step with its headline counts, then every residual that needs a human — unresolved High/Medium findings, and any cut-candidate the user declined to rule on. Never the working context.

## Step 1 — Audit (test audit + necessity breakdown)

Spawn a subagent. Directive: read the implementation record if the caller supplied one, plus `git diff <base>...HEAD`, then audit the new/changed tests against the surface's testing-patterns skill (`react-testing-patterns` / `mamba-unit-test-patterns`).

Produce a **per-case justification table** — one row per *test case*, not per file:

| Test | Case observed | Justification (regression it guards) | Mutation | Verdict |
|------|---------------|--------------------------------------|----------|---------|

Verdict ∈ `Necessary` / `Redundant (with <test>)` / `Brittle` / `Low-value`. Enumerate *every* new/changed case — don't sample. Below the table, flag any missing edge cases.

**Back the verdicts with mutation, or say plainly that you didn't.** "This test is redundant" is a claim about what would still fail if the code broke, and reasoning about that from the source is unreliable. Break the line the test claims to guard and see whether the test actually fails.

- A `Redundant` or `Low-value` verdict is **mutation-backed** or explicitly marked `reasoned, not mutation-verified` in the Mutation column. Never let the two look alike — a static-only audit reads exactly like a mutation-backed one, and only one of them justifies deleting a test.
- Mutation is what makes the cuts safe: in one run it justified removing 30 test cases with zero loss of kill, and separately disproved a claim the audit had already written down.
- **Run mutations out-of-tree.** Apply them in a private detached worktree, or by rebinding the name in the module's namespace from the test process — never by editing the shared worktree. Sibling agents have collided on this: a stray `# MUTATION-1` block appeared inside a file another agent was mid-review on, and a temp test file leaked into someone else's diff.
- Confirm the tree is clean when you're done. A surviving mutation is a shipped bug.

Then act on the verdicts **hybrid** — auto for the obvious, gate for the judgment calls:

- **Auto-cut** the unambiguous `Redundant`/`Brittle` rows; re-run the touched tests afterward to confirm still-green. Note each removal in the report.
- **Do not cut** `Low-value` or debatable-necessity rows. Leave them in place and list them as cut-candidates.

The subagent returns `N cases · X auto-cut · Y awaiting decision`, then the Y rows verbatim.

**The cut-candidate gate.** Surface those Y rows to the user one at a time, ending the turn with `--- HUMAN GATED ---`. For each "cut" answer, spawn a quick follow-up to remove the test and re-run. Skip the gate entirely when `Y = 0` — it should be silent when it doesn't fire.

## Step 2 — Cut (de-slop)

Two sequential agents — a focused simplifier, then the de-slop subagent — because `code-simplifier` is a narrow agent that won't write artifacts or run the prose audit.

**The rubric lives in the portable `de-slop` skill and that skill is the single source of truth**: the per-block prose audit (docstrings **and** comments), the rule codes, the abstraction audit, and the diff scope rule. Do not restate it here — a second copy drifts, and a drifted copy of this particular rubric is how two passes cut zero.

**2a — Simplify (trial).** Spawn Anthropic's official `code-simplifier` agent (`agentType: code-simplifier`) on the files the diff touched. It eliminates redundant code / abstractions, dense one-liners, and obvious comments while preserving behavior. Capture its returned summary. *We're trialing this — record what it caught so we can judge whether it earns its place vs. `/clean-up-ai-slop` alone.* (Needs the `code-simplifier@claude-plugins-official` plugin enabled; if the agent type is unavailable, skip 2a, note it in the report, and run only 2b.)

**2b — De-slop subagent.** Spawn a subagent. Directive: **invoke the `de-slop` skill and follow it**, then run `/clean-up-ai-slop` for the tells `code-simplifier` doesn't target — unnecessary new defensive checks / try-catch and `Any`/`any` casts the change didn't need. Re-run the touched tests after both passes; preserve behavior.

**Three things to check in the returned report, because each has been silently skipped before.** These are exit conditions for this step, not advice — a report that fails one goes back:

1. **Were docstrings enumerated?** The report must carry a coverage table with a *docstring line count*, not just a comment count. Two passes on one feature audited 68 comments and cut **zero**; a later pass on the same code found 911 prose lines of which **763 were docstring** and cut or rewrote 80% of them. If the coverage table has no docstring column, the pass didn't happen — send it back.
2. **Was the cut rate plausible?** Under ~30% cut-or-rewrite on AI-written code usually means under-enumeration, not clean prose.
3. **Were `R4` (false claim) findings listed separately?** Those are bugs in the record, not style. Across one feature the truth check caught ~16–20 false comments and stayed the highest-yield check to the final cycle — including two the *cleanup itself* introduced.

The report carries: what `code-simplifier` caught in 2a (the trial signal), the coverage table, the prose-audit table, the non-prose slop removed in 2b, the `R4` findings, and the net line delta. It goes wherever the caller said, or back inline if they said nothing.

## Step 3 — Self-review (two-lens review→fix loop)

Drive a review→fix loop, **capped at 3 rounds**, on the working branch. Each round:

1. **Review (read-only) — two agents in parallel, different lenses.** Round 1 runs both; rounds 2–3 run only the in-module lens unless the out-of-module lens had findings.

   **Lens A — in-module.** Spawn a subagent to run the `bugbot` skill in branch mode: `Skill(bugbot, "--branch")` — it reviews `git diff <base>...HEAD`, auto-discovers every in-scope `BUGBOT.md`, and reports findings with severities but makes no edits. Have the subagent return **only** the findings table (severity + `file:line` + one line each), not its working context. *(If the harness refuses the Skill call — `bugbot` is `disable-model-invocation: true` — have the subagent instead read and follow `.claude/skills/bugbot/SKILL.md` against `--branch` mode; the procedure is identical.)*

   **Lens B — out-of-module.** See below. Same output format.
2. **Check the exit condition.** If there are **zero High and zero Medium findings and no blocking `BUGBOT.md`-rule violations** → exit the loop. List any residual **Low** nits in the report for the user; do **not** force-fix them (Low churn rarely converges).
3. **Fix.** Otherwise spawn the **`developer`** agent (`agentType: developer`) to resolve the High/Medium + blocking findings. Give it **only** the findings list (with `file:line`), not the reviewer's full output. It edits, re-runs the touched linters/tests to confirm still-green, and commits with the `Co-Authored-By` trailer. Then go back to step 1.

After 3 review→fix rounds, **stop even if High/Medium remain** — do not loop indefinitely. Record the unresolved findings and return them as residuals; the caller surfaces them at its own sign-off gate. The report carries: one line per round (`round N: H·M·L counts`), what was fixed each round, and any residuals (unresolved-after-cap or listed-Low).

`bugbot` is a repo-scoped skill (it lives at `.claude/skills/bugbot/` and enforces the repo's `BUGBOT.md` rules). If neither the skill nor that path is present — e.g. a run outside the work monorepo — run lens B alone and note the absence in the report. Lens B is the one that finds High severities; it is never the lens you skip.

### The out-of-module lens

**Every other pass reads the diff. This one reads what the diff touches.** That distinction is not academic: a confirmed defect survived a test audit, two de-slop passes, a bugbot loop, and two human approvals — all of which looked at the diff and stopped at the call site — and was caught the first time anything followed the value *out* of the module. Nothing in the diff was wrong. The bug was three frames down, in a function the diff called.

Spawn a subagent, read-only, given the diff and the file list. Its whole job is to leave the files the diff touched:

1. **Trace every value the change introduces or newly shares, out to its consumers.** Not the signature — the body, and the body of what *that* calls, until you reach something that makes a decision with the value. Cite `file:line` at each hop.
2. **Enumerate sibling call sites.** For each function the change newly *calls*, find every other production caller and diff the arguments. Four callers passing a flag and one not is the cheapest defect signal there is, and it's mechanical. Note this is the inverse of the usual rule — the standing "enumerate references, don't sample" is normally applied to *callers of the code being changed*; here it's *siblings of the call being added*.
3. **Ask what differs between consumers of anything shared.**

   > **A shared resource crossing a trust boundary is the tell.** When a value is deliberately shared across channels / tenants / roles / environments, ask what *differs* between the consumers — not just what they have in common. Sharing is usually introduced as an optimization and defended as an invariant, so it reads as settled. A test named after the invariant is the artifact of the assumption, not evidence for it.

4. **Follow the change's own claims outward.** Where the diff (or its comments) asserts something about code elsewhere, go read that code.

Return the same findings table as lens A. **This lens is where High findings come from**, so anything it reports at Medium or above gets an adversarial re-derivation before it's acted on — independently re-derive the mechanism, and price the blast radius. Severities move in both directions on that pass, and both directions are useful.

## Running the pass again, later

Once a PR exists — after a rebase, after a review cycle, after a stack split — re-run the whole pass against that single PR. Nothing about the pass changes; only the diff scope does, and getting that scope right is the whole trick. **A PR's base is its parent's head, not `main`.**

**Is it worth running twice?** Running the *same* pass twice mostly re-finds the same things. What pays is running it with **different lenses** — which is what A/B in step 3 is, at roughly the cost of running it twice. Beyond that, re-run the pass whenever the tree changes underneath it (a rebase changes every descendant), and always re-run the `R4` truth check over prose the pass itself wrote. That last one is not paranoia: a cleanup pass has propagated a false claim through its own suggested replacement text.

**Re-run every PR you touched, not just the tip.** A rebase changes every descendant's tree.

## What this pass does NOT do

- **Measure the diff against a size budget.** That's the caller's — splitting is a shipping decision, and by the time a PR is open it's usually too late to act on.
- **Write or regenerate the PR description.** That's the portable `pr-description` skill, which the caller invokes directly with the diff.
- **Decide where anything lives.** No run directory, no ledger, no artifact numbering. It writes to the paths it was handed and nowhere else, so it composes with any conductor.
- **Push, or open or update a PR.** It commits fixes on the branch it was pointed at; the caller owns everything that touches the remote.
- **Post to GitHub.** No review comments, approvals, or thread replies — ever. Findings come back to the caller as a table, and drafts go to a file. See "Never speak as me" in `~/.claude/CLAUDE.md`.
