---
name: pr-description
description: Generate a pull-request description from the code diff alone — repo-template-aware. Use when the user asks to write/draft a PR description, fill out a PR body, or "describe this branch for a PR". Reads the diff and file list (never the plan/chat/workpad) so the description reads for someone with zero prior context, defers to the repo's own PR template when one exists, and otherwise falls back to a generic 4-section shape.
user-invocable: true
---

# /pr-description — diff-only PR description

Generate a pull-request description from the **diff and the file list**, in a shape the repo
actually wants. The output reads for a reviewer with zero prior context.

## The hard constraint: diff-only

Write the description from `git diff <base>...HEAD` and the changed-file list **only**. Do
**not** read the planning doc, the chat transcript, the architecture notes, or any workpad —
even if they're available. The description must reproduce from the objective code, because
that's all a reviewer has. If you find yourself reaching for context that isn't in the diff,
that context doesn't belong in the description.

Resolve the base ref before diffing. Default to the repo's main branch (`git symbolic-ref
refs/remotes/origin/HEAD` or `main`/`master`); use the three-dot form so the diff anchors on
the merge base, which is exactly this branch's changes:

```bash
git diff <base>...HEAD --stat   # file list + magnitudes
git diff <base>...HEAD          # the change itself
```

## Step 1 — Detect the repo's own convention and defer to it

The repo's own template wins. Before writing anything, look for these, in order, and use the
first one found:

1. **`.github/pull_request_template.md`** (also check `.github/PULL_REQUEST_TEMPLATE.md`,
   `.github/PULL_REQUEST_TEMPLATE/*.md`, `docs/`, or repo root). If present, **fill that
   template's sections verbatim** — keep its section headings and order, fill each with
   specific content from the diff, check the checklist boxes that the change actually
   satisfies, and strip the template's HTML-comment instructions and any placeholder text.
2. **A repo rule about PR descriptions** — a file named like `pull-request-description`
   (commonly under `.rulesync/rules/`, `.cursor/rules/`, `.github/`, or a `CLAUDE.md` that
   references one). If discoverable, follow its specific instructions (extra sections,
   wording conventions, links it wants) on top of the template.
3. **Neither exists** → use the generic 4-section shape below.

Detect, don't hardcode: discover these at runtime in whatever repo you're in. This skill
carries no repo- or employer-specific names, URLs, or ticket prefixes.

```bash
ls .github/pull_request_template.md .github/PULL_REQUEST_TEMPLATE.md 2>/dev/null
ls .github/PULL_REQUEST_TEMPLATE/*.md 2>/dev/null
# repo PR-description rule, if any:
find . -path ./node_modules -prune -o -iname '*pull-request-description*' -print 2>/dev/null
```

When you defer to a repo template, still apply the **content quality** bar below — a repo
template tells you the *sections*; it rarely tells you to lead with *why* or to keep the
description out of file-by-file territory. Do both.

## Step 2 — The generic 4-section shape (fallback)

When the repo has no template or rule, write exactly these four sections, in this order, and
nothing else:

### Description
What changed and **why**, led by the behavior change — not a file-by-file walkthrough. Open
with the motivation (the bug, the constraint, the capability being added). Describe the fix
one level up: its *shape*, not its symbols. "Weekend appointments now skip the time-of-day
check" beats "added a validator on three request models". If a sentence wouldn't tell a
reviewer anything they couldn't get from `git diff`, cut it.

### How to test
**Always a numbered list** of concrete steps a reviewer can follow to exercise the change —
where to go, what to do, what to expect. Be specific; never "test the feature". Include the
environment/URL when relevant.

### Reviewer guide
Point reviewers at the interesting question — the one a thoughtful reviewer would ask anyway.
- **Focus areas**: the files/lines where the real decisions live (`file:line`).
- **Mechanical**: plumbing, wiring, generated code that can be skimmed.
- **Risky**: changes to auth, billing, data models, or other sensitive areas, with line refs.
- **Pattern**: if this follows an existing pattern, name it so reviewers can diff against it.

This is where genuinely load-bearing `file:line` references belong — not the Description.

### Checklist
A short checklist of what the change did/did not do (tests added, DB changed, docs updated),
using `- [x]` / `- [ ]` markdown. When deferring to a repo template, use *its* checklist
items instead.

**No other sections.** No Follow-ups, Notes, Background, or changelog sections — they leak
process and aren't what a reviewer needs.

## Content quality (applies in both modes)

Whether you filled a repo template or the generic shape, hold the same bar as the Description
section: lead with *why* not *what*, describe behavior changes (not symbol-by-symbol lists),
and cut any sentence a reviewer could get from `git diff` alone.

## Setting the body

When creating the PR, pass the body via a HEREDOC (or `--body-file`) so formatting survives:

```bash
gh pr create --title "<title>" --body "$(cat <<'EOF'
... description ...
EOF
)"
```
