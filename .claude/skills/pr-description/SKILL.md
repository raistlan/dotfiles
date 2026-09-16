---
name: pr-description
description: Generate a pull-request description using my personal PR template, which takes precedence over any repo-provided template. Use when the user asks to write/draft a PR description, fill out a PR body, describe a branch for a PR, or open/update a PR. Reads the diff and file list only (never the plan/chat/workpad) so the description reads for someone with zero prior context. Produces ticket link, why+how description, line counts by function, test steps a reviewer can execute without guessing (12 max, one action each), a reviewer guide of at most three categories from a fixed list, and the repo's own checklist verbatim.
effort: medium
context: fork
---

# /pr-description — my personal PR template

This template is **my default for every PR I open**, in any repo. It takes precedence over the repo's `.github/pull_request_template.md` and over any repo rule about PR descriptions.

The repo's template is not ignored — it is **demoted to one job**: supplying the Checklist section verbatim. Everything else follows the shape below.

**What the body is for.** It is a reviewer's *introduction* to the PR: enough to orient them before they open the diff, plus a short path to convincing themselves the change works. It is not a QA script, a changelog, or a guided tour of the code.

## Precedence

1. **This template wins** on section set, section order, and content bar.
2. **The repo's template supplies the Checklist** — copied verbatim (see Step 4).
3. A repo rule about PR descriptions is **advisory only**. If it asks for a section this template doesn't have, skip it. If it asks for stricter content within a section I already have, honor that.

If following this template would violate something non-negotiable in the repo (a required section a bot parses, say), say so in one line and add only that section.

## The hard constraint: diff-only

Write from `git diff <base>...HEAD` and the changed-file list **only**. Do **not** read the planning doc, chat transcript, architecture notes, ticket comments, or any workpad — even when available. The description must reproduce from the objective code, because that is all a reviewer has. If you reach for context that isn't in the diff, that context doesn't belong in the description.

The one exception: the ticket's **title and URL** may come from the tracker (Step 1). Its description and comments may not.

Resolve the base ref before diffing. Use the three-dot form so the diff anchors on the merge base — exactly this branch's changes:

```bash
base=$(git symbolic-ref --quiet refs/remotes/origin/HEAD | sed 's|^refs/remotes/||')
base=${base:-origin/main}
git diff "$base"...HEAD --stat   # file list + magnitudes
git diff "$base"...HEAD          # the change itself
```

For a stacked PR, the base is the **parent branch**, not the default branch — otherwise the diff and the line counts absorb the parent's changes. Check `gt log short` / `gt state` when the repo uses Graphite, or the PR's own base ref via `gh pr view --json baseRefName`.

## Step 1 — Ticket link

Extract the ticket key from, in order: the branch name, the PR title, then commit subjects. Keys look like `[A-Z][A-Z0-9]+-[0-9]+` (e.g. `ABC-123` in `rhs/ABC-123/short-name`).

```bash
git rev-parse --abbrev-ref HEAD | grep -oE '[A-Z][A-Z0-9]+-[0-9]+' | head -1
```

Resolve it to a real URL and title. Prefer the Linear MCP `get_issue` tool — it returns the canonical `url` and `title`, which also confirms the ticket exists. Fall back to constructing `https://linear.app/<workspace>/issue/<KEY>` using the workspace slug recorded in my private per-project memory.

Render as a single line **above** the first heading:

```markdown
**Ticket:** [ABC-123 — Issue title](https://linear.app/<workspace>/issue/ABC-123)
```

No ticket key in the branch or title → omit the line entirely rather than guessing a URL, and tell me the branch has no ticket so I can decide.

## Step 2 — Description

**2–3 sentences, 60 words at the outside.** This is the section that bloats; hold the line here hardest. Cover both:

- **Why** — the motivation. The bug, the constraint, the capability, the incident. What made this PR exist.
- **How** — the *shape* of the change, one level up from the code. "Validate at the API
  boundary, format-only" beats "added a validator on three request models".

Lead with why. One sentence for why, one or two for how, stop.

Cut any sentence a reviewer could get from `git diff` alone. Do not enumerate symbols, do not walk files, do not list every consequence of the change — the interesting one goes in Reviewer guide, where `file:line` references also belong.

If the change genuinely has several independent parts, that is a signal the PR should be split, not that the Description should grow. Say so in one clause and still stop at 3 sentences.

## Step 3 — Changes by function

Run the helper and paste its markdown table verbatim. Regenerate it every time the branch changes — a stale table is worse than no table.

```bash
~/.claude/skills/pr-description/scripts/pr-line-counts.sh   # optional arg: explicit base ref
```

It emits a `| Function | Files | +Added | -Removed | % of diff |` table over the buckets `logic`, `tests`, `docs`, `config`, `generated`, `fixtures`, plus a Total row. Buckets with no churn are omitted. Renames are classified by destination path; binary files are skipped.

Add **one sentence** under the table only when the split is itself informative — a large `generated` share meaning most of the diff is codegen a reviewer can skim, a zero `tests` row on a logic change, an outsized `fixtures` share signalling a migration. If the table speaks for itself, add nothing.

The bucket names are heuristics tuned to my repos. If the classifier obviously miscategorizes a file in this diff, fix the table by hand and say so in that one sentence.

## Step 4 — How to test

**A reviewer follows this to convince themselves the change works.** Any command a developer can run belongs here — `curl`, a flag flip in LaunchDarkly, clicks in the browser, a test command, a local server, a query against a dev database, a log tail. The constraint is not the tool, it is the purpose: **every step must exercise behavior.** A step that produces no observable result is not a test step.

**Twelve steps is the ceiling, and there is no floor.** Three pointed steps beat twelve hedged ones.

### One line, one action, no decisions

Each step is one imperative sentence a reviewer executes without stopping to work out *how*. Give the literal thing:

- **`curl`** — the whole command, pasteable, and the one field in the response to check.
- **LaunchDarkly** — the literal flag key and the value to set. "Turn on `scheduling-weekend-jobs` for your user", not "enable the feature".
- **Browser** — the route, the control by its visible label, and what changes on screen.
- **A command** — the command as typed, and what passing looks like in one clause.

"Create a user relationship between two patient accounts" fails the bar — the reviewer doesn't know what to click or what to post. Give the clicks, give the `curl`, or cut the step. When a step needs a caveat to run correctly, fold it into the command instead of writing a sentence about it.

Setup is numbered steps, not prose preamble: the flag to flip, the account or persona to log in as, the host or service to point at.

### Never a test step

These read like steps but ask the reviewer to *inspect* rather than verify. Cut them — reading the diff is what a PR review already is:

- **Reading code** — "read the routing arrangement in three places", "note the old class is deleted". If it matters, it's a Reviewer guide bullet with a `file:line`.
- **Confirming the diff** — that a file moved, that codegen filed a route, that a manifest changed. The diff and the Changes by function table are the evidence.
- **Reading another PR first** — stack order lives in the base ref, not in test steps.
- **Breaking the code to watch it fail** — deleting an import, reverting a guard, then putting it back. Interesting; not QA.

### Guard cases

Fold the negative cases into one step holding a two-column table (what to change → expected outcome), four rows at the outside. That keeps every guard visible for the cost of one step, and guard cases — flag off, cohort excluded, consent gate unmet — are where these PRs actually break.

Skip the glossary. Define a term in a clause inside the step that first uses it, or not at all.

**When the change has no user-reachable surface** — an internal refactor, a task with no endpoint or UI — the test command *is* the step: one line with the command and the expected result. Don't pad it with runtimes, file inventories, or where the cases live.

### Read it back as a list

Before you hand it over, read the numbered list on its own, the way a reviewer meets it. Every step should be clear on one pass. Any step that needs a second read, or that a reviewer would have to ask you about, gets rewritten or cut.

## Step 5 — Reviewer guide

**Pick at most three categories from the fixed list below. Nothing outside the list may appear here.** The value is in the choosing — a guide that flags everything guides nobody. Fewer is fine and usually better; one sharp category beats three padded ones.

| Category | What it covers |
| --- | --- |
| **Correctness** | The logic most likely to be wrong — the invariant, the edge case, the retry or idempotency path. |
| **Blast radius** | A changed signature, contract, or shared shape, and the callers it reaches. |
| **Data** | Schema change, migration, backfill, or a write that can't be undone. |
| **Security & privacy** | Auth, permissions, tenant isolation, secrets, personal or health information. |
| **Performance** | Query count, N+1, payload size, or new work on a hot path. |
| **Rollout** | Flag gating, deploy ordering, or behavior while both versions run at once. |
| **Prior art** | The analogue this copies, so a reviewer can diff against it instead of reading cold. |
| **Tradeoff** | A decision with a real alternative, where I want a second opinion. |

One line per category, each carrying a load-bearing `file:line`. Name the question; don't summarize the code:

```markdown
- **Blast radius** — `notifications/dispatch.py:88` now requires `channel`; all four callers updated, and `billing/receipts.py:210` is the one that can still pass `None`.
```

No category genuinely applies — a rename, a dependency bump, regenerated output — then write one line saying the diff is mechanical and why. Don't reach for a category to fill the section, and don't invent `Mechanical` as one: the Changes by function table already shows the skimmable share.

## Step 6 — Checklist

Copy the checklist **items verbatim from the repo's own PR template** — same wording, same links, same order. Discover it at runtime; never hardcode or paraphrase it:

```bash
ls .github/pull_request_template.md .github/PULL_REQUEST_TEMPLATE.md 2>/dev/null
ls .github/PULL_REQUEST_TEMPLATE/*.md 2>/dev/null
```

**Verbatim applies to the items, not the heading.** The heading is mine: `### Checklist`, no trailing colon, matching the other five. Repo templates often write `### Checklist:` — don't inherit that inconsistency.

Check the boxes the change actually satisfies, based on the diff — tests added, DB touched, visual change. Leave the rest unchecked; never check a box speculatively. If a visual/UX box is checked, the screenshots have to actually be attached.

No repo template exists → use a short generic checklist (tests added, DB changed, docs updated).

## Assembled shape

```markdown
**Ticket:** [KEY — Title](https://linear.app/<workspace>/issue/KEY)

### Description
<3–5 sentences: why, then the shape of how>

### Changes by function
| Function | Files | +Added | -Removed | % of diff |
| --- | --- | --- | --- | --- |
...

### How to test
1. <setup: flag key + value, test account, host>
2. <curl / click, with the expected status or on-screen result>
3. <the next behavioral branch, same shape>
4. Guard cases — each must skip with no side effect:
   | Change | Expected |
   | --- | --- |
   | ... | ... |

### Reviewer guide
- **<Category 1>** — <the question, with `file:line`>
- **<Category 2>** — ...
- **<Category 3>** — ...

### Checklist
- [ ] <items verbatim from the repo template>
```

**These six and nothing else.** No Follow-ups, Notes, Background, Summary, or changelog sections — they leak process and aren't what a reviewer needs.

## Prose pass

Before you show me the body, run the `zinsser` skill over it with the Skill tool. Do not approximate it from memory — it is the prose standard for every section here.

Apply it to prose only. Leave commands, paths, `file:line` references, table values, and the checklist copied verbatim alone. Then check the length budget below; the zinsser pass usually buys back the lines.

## Length budget

A reviewer skims this before reading the diff. If the body is long enough to need skimming itself, it has failed. Every section is capped, How to test included — an uncapped test section grows into something nobody executes.

| Section | Budget |
| --- | --- |
| Ticket | 1 line |
| Description | **2–3 sentences, ≤ 60 words** — the tightest constraint here |
| Changes by function | the table, plus at most 1 sentence — usually zero |
| How to test | **≤ 12 steps**, one line each, guard cases in one table |
| Reviewer guide | **≤ 3 bullets**, from the fixed category list, one line each |

Judge the whole body by line count, not words — tables make word counts lie. Under **~50 lines, checklist excluded**, is the bar. Check before handing over:

```bash
wc -l <body-file>
```

Over budget → cut, don't reflow. The first things to go are context a reviewer already has, restated assertions, and parentheticals hedging a claim already made. Then drop any test step that inspects rather than exercises — it was never going to be run. Never buy length back by dropping a `file:line` on a risky change, or by cutting the guard-case table.

## Content bar (applies to every section)

**Specific over exhaustive.** Coverage is bounded by what a reviewer will actually do. One pasteable command beats a paragraph describing a scenario they'll skip; when only the automated tests pin a case, give the test command rather than narrating the case.

**Readable with zero system context.** A reviewer from another team should follow it without opening a second file. Expand an internal acronym on first use, name the module or surface a term belongs to, and say what a domain object *is* when it isn't self-evident. One clause of context beats a link.

**Faithful to the exact diff.** Every claim traces to a line in this diff. No aspirational behavior, no describing what the ticket wanted over what the code does, no carrying over text from a previous revision. When updating an existing PR, re-read the current diff and rewrite — including the line-count table — rather than patching the old body.

**Lead with why, describe behavior not symbols.** "Weekend jobs now skip the time-of-day check" over "added a validator on three request models".

## Setting the body

Pass the body via `--body-file` (or a HEREDOC) so formatting survives the shell:

```bash
gh pr create --title "[KEY] <description>" --body-file <path>
gh pr edit <n> --body-file <path>
```

Title convention: `[TICKET] short description`. Never post to GitHub without my go-ahead — draft the body to a file, show it to me, and let me run the command.
