---
name: pr-description
description: Generate a pull-request description using my personal PR template, which takes precedence over any repo-provided template. Use when the user asks to write/draft a PR description, fill out a PR body, describe a branch for a PR, or open/update a PR. Reads the diff and file list only (never the plan/chat/workpad) so the description reads for someone with zero prior context. Produces ticket link, why+how description, line counts by function, exhaustive numbered test steps, reviewer guide, and the repo's own checklist verbatim.
effort: medium
context: fork
---

# /pr-description — my personal PR template

This template is **my default for every PR I open**, in any repo. It takes precedence over the repo's `.github/pull_request_template.md` and over any repo rule about PR descriptions.

The repo's template is not ignored — it is **demoted to one job**: supplying the Checklist section verbatim. Everything else follows the shape below.

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

**Always a numbered list.** Exhaustive: cover the happy path, each behavioral branch the diff introduces, and the negative/guard cases. A reviewer should be able to execute it top to bottom without asking me anything.

**This is the one section allowed to run long.** Never drop a case to save space — step count is fine, so add the step. What to avoid is *wordy* steps: keep each to one line, and collapse the negative/guard cases into a single step holding a two-column table (what to change → expected skip reason / outcome), which keeps every case visible for a fraction of the words.

Every step names a concrete surface — a URL, a route, an endpoint, a command. Never "test the feature". Include setup (which app to run, which test account or fixture persona, which feature flag and what to set it to) as numbered steps, not as prose preamble.

Skip the glossary. Define a term inline in the step that first uses it, in a clause, or not at all.

Pick the surface from what the diff actually touches:

- **HTTP endpoint changed** → give a runnable `curl` with the real path, method, and a payload built from the request model in the diff, plus the expected status and response shape.
- **Service, task, or workflow with no direct HTTP surface** → name the trigger (the celery task, temporal workflow, management command, or the user action that enqueues it) and the observable side effect (a DB row, a queued notification, a log line, a provider dashboard).
- **Frontend changed** → the app, the route, and the interaction; what renders before vs after.
- **Both sides changed** → both, backend first, then the UI surface that proves it end to end.

Also state how to verify it *doesn't* fire when it shouldn't — the cohort that's excluded, the flag off, the consent gate unmet. Guard cases are where these PRs actually break.

## Step 5 — Reviewer guide

Point at the interesting question — the one a thoughtful reviewer would ask anyway.

- **Focus areas** — where the real decisions live (module/submodule and `file:line`).
- **Mechanical** — plumbing, wiring, generated code that can be skimmed.
- **Risky** — auth, billing, personal information, data models, or other sensitive areas, with line refs.
- **Pattern** — if this follows existing prior art, name it so reviewers can diff against it.

Brief bullets. This is where load-bearing `file:line` references go.

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
1. <setup: app, account, flag>
2. <exercise the happy path + what to assert>
3. <exercise each behavioral branch>
4. Guard cases — each must skip with no side effect:
   | Change | Expected |
   | --- | --- |
   | ... | ... |

### Reviewer guide
- **Focus areas**: ...
- **Risky**: ...
- **Mechanical**: ...
- **Pattern**: ...

### Checklist
- [ ] <items verbatim from the repo template>
```

**These six and nothing else.** No Follow-ups, Notes, Background, Summary, or changelog sections — they leak process and aren't what a reviewer needs.

## Length budget

A reviewer skims this before reading the diff. If the body is long enough to need skimming itself, it has failed. The budget bites on the prose sections; How to test is exempt, because coverage is worth more than brevity there.

| Section | Budget |
| --- | --- |
| Ticket | 1 line |
| Description | **2–3 sentences, ≤ 60 words** — the tightest constraint here |
| Changes by function | the table, plus at most 1 sentence — usually zero |
| How to test | no step cap; one line per step, guard cases in one table |
| Reviewer guide | ≤ 4 bullets, one line each |

Judge the whole body by line count, not words — tables make word counts lie. Under **~50 lines, checklist excluded**, is the bar. Check before handing over:

```bash
wc -l <body-file>
```

Over budget → cut, don't reflow. The first things to go are context a reviewer already has, restated assertions, and parentheticals hedging a claim already made. Never buy length back by dropping a test case or a `file:line` on a risky change — compress the prose around them.

## Content bar (applies to every section)

**Terse in prose, exhaustive in coverage.** When those two pull against each other, prose loses: cut a sentence before you cut a test case.

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
