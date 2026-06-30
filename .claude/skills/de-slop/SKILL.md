---
name: de-slop
description: "Strip AI-generated slop from a change — over-comments, unneeded defensive checks/try-catch, Any/any casts that dodge types, and single-use indirection. Runs an abstraction audit and a per-comment audit table over the whole diff, then cuts. Use when the user asks to de-slop, clean up AI slop, audit comments, or tighten a diff before review."
user-invocable: true
---

# de-slop

Remove the tells AI defaults to from a change, then re-run the touched tests to confirm
behavior is preserved. This is a cutting pass — bias toward removal.

**Audit the whole change under review, not just the latest commit.** Diff against the merge
base: `git diff <base>...HEAD` (commonly `git diff main...HEAD`). Comments and abstractions an
earlier commit on the branch introduced get re-examined too — slop hides in the commits you
already moved past.

## What to cut

1. **Over-comments** — comments narrating what the code already says (full audit below).
2. **Unneeded defensive checks / try-catch** — guards and exception handling that are abnormal
   for that area of the codebase, especially on inputs that trusted, already-validated callers
   guarantee. Match the local file's norms; don't invent belt-and-suspenders the surrounding
   code doesn't use.
3. **`Any` / `any` casts that dodge a type error** — casts that exist only to silence the
   checker and don't follow the codebase's patterns. Fix the type at its source, narrow at the
   use site, or validate at the boundary instead.
4. **Single-use indirection** — see the abstraction audit.
5. **Any other style inconsistent with the surrounding file.**

## Abstraction audit (enumerate single-use indirections)

Beyond line-count tells, list *every* new module-level constant, helper, or wrapper the change
introduced and make each earn its place. A constant/helper read **exactly once** is usually
just indirection — inline it and delete the definition — **unless** it:

- (a) is referenced in **≥2 places**, or
- (b) names a genuinely cryptic literal whose meaning isn't obvious at the call site, or
- (c) is a documented config knob.

A `NAME = "literal"` or `NAME = SomeEnum.MEMBER` used in a single spot fails this. So does a
one-line helper wrapping a single expression. Enumerate them all — don't sample.

## Comment audit (enumerate, don't sample)

AI over-comments by default, and roughly 1 in 5 LLM-written comments is factually wrong, so a
comment is **guilty until it earns its place**. Build a per-comment table over *every* comment
added or changed in the diff — one row per comment:

| Comment (`file:line`) | What it says | Keep-test | Verdict |
|-----------------------|--------------|-----------|---------|

A comment **survives only if it passes all six:**

1. Explains **WHY** (intent, constraint, tradeoff, gotcha, rejected alternative) — not the
   what/how the code already shows.
2. **Delete-and-reread:** removing it makes the code meaningfully harder to understand
   *correctly*.
3. Can't be dissolved by a **better name or an extracted function** — if it can, fix the code
   and cut the comment.
4. Is **true** against the current code (don't grant unverifiable AI claims the benefit of the
   doubt).
5. Is **one line** unless the why genuinely needs more — multi-line narration of an obvious
   operation auto-fails.
6. **No development-process leakage** — no PR/ticket/chat refs, "as requested", "added per
   review", changelog/authorship, emoji. *Exception:* a `TODO` tied to a tracked ticket, or a
   citation of a durable external reason (spec section, RFC, linked bug documenting a
   workaround's why).

### "Explains why" is necessary, not sufficient

A comment can name a real reason and still be slop if it's longer than that reason needs or
narrates the adjacent operation alongside it. Compress to the single load-bearing clause; if
the why is one phrase, the comment is one line. A 3–4 line block guarding a one-line call is
almost always over-written even when its content is genuinely "why" — `Rewrite` it, don't
`Keep` it.

### Cut process-leakage labels — don't compress them

Inline planning/process labels are slop to **cut**, not shrink. A parenthetical like
`(P1 mitigation)`, `(phase 2)`, a ticket-process reference, or a "step N of the plan" tag adds
no durable why — passing rule 1 ("explains why") does not save it. Delete the label outright;
keep only the load-bearing technical reason, if any, as its own one-line comment.

## Verdict and action

Verdict ∈ `Keep` / `Rewrite` (a real why is buried in noise → compress to one line) / `Cut`.

Act hybrid: **auto-cut/auto-rewrite the unambiguous `Cut`/`Rewrite` rows**, then re-run the
touched tests to confirm still-green. Leave genuinely debatable rows in place and list them
for the user to decide.

## Output

Report concisely:
- the comment-audit table,
- the abstraction-audit findings (which single-use indirections were inlined),
- the non-comment slop removed (defensive checks, casts, style),
- the net line delta,
- any debatable rows left for the user.
