---
name: de-slop
description: "Strip AI-generated slop from a change — over-written prose (docstrings AND comments), unneeded defensive checks/try-catch, Any/any casts that dodge types, and single-use indirection. Runs an abstraction audit and a per-block prose audit table over the whole diff, then cuts. Use when the user asks to de-slop, clean up AI slop, audit comments or docstrings, or tighten a diff before review."
user-invocable: true
---

# de-slop

Remove the tells AI defaults to from a change, then re-run the touched tests to confirm behavior is preserved. This is a cutting pass — bias toward removal.

**Audit the whole change under review, not just the latest commit.** Diff against the merge base: `git diff <base>...HEAD` (commonly `git diff main...HEAD`). Comments and abstractions an earlier commit on the branch introduced get re-examined too — slop hides in the commits you already moved past.

## What to cut

1. **Over-written prose** — **docstrings and comments** that narrate what the code already says (full audit below). Docstrings count. They are usually the larger half.
2. **Unneeded defensive checks / try-catch** — guards and exception handling that are abnormal for that area of the codebase, especially on inputs that trusted, already-validated callers guarantee. Match the local file's norms; don't invent belt-and-suspenders the surrounding code doesn't use.
3. **`Any` / `any` casts that dodge a type error** — casts that exist only to silence the checker and don't follow the codebase's patterns. Fix the type at its source, narrow at the use site, or validate at the boundary instead.
4. **Single-use indirection** — see the abstraction audit.
5. **Dangling references to removed things** — when you delete code, delete what points at it; don't convert references into negations ("no longer uses X", "don't do the old Y"). A note about a state no future reader can see is just noise.
6. **Any other style inconsistent with the surrounding file.**

## Abstraction audit (enumerate single-use indirections)

Beyond line-count tells, list *every* new module-level constant, helper, or wrapper the change introduced and make each earn its place. A constant/helper read **exactly once** is usually just indirection — inline it and delete the definition — **unless** it:

- (a) is referenced in **≥2 places**, or
- (b) names a genuinely cryptic literal whose meaning isn't obvious at the call site, or
- (c) is a documented config knob.

A `NAME = "literal"` or `NAME = SomeEnum.MEMBER` used in a single spot fails this. So does a one-line helper wrapping a single expression. Enumerate them all — don't sample.

## Prose audit (docstrings AND comments — enumerate, don't sample)

AI over-writes prose by default, and roughly 1 in 5 LLM-written comments is factually wrong, so a prose block is **guilty until it earns its lines**.

### Enumerate mechanically, or you will miss most of it

**Audit docstrings and comments.** A pass that tables only `#` comments will report "nothing to cut" on a file that is 30% docstring — this is the single most common way this audit fails, and it has failed that way in practice: two passes audited 68 comments and cut **zero**, then a pass that included docstrings found 254 blocks / 911 prose lines on the same code, of which **763 lines were docstring**, and cut or rewrote 80% of them.

Enumerate with a tool, not by eye — eyeballing a diff under-counts by roughly 5×:

- **Python** — `ast` for docstrings (module, class, function), `tokenize` for `#` comments, grouping consecutive own-line comments into one block.
- **TS/JS** — the TypeScript compiler API, or `//` + `/* */` + JSDoc via a real parser.
- **Any language** — if no parser is handy, at minimum grep the block-comment delimiters separately from the line-comment ones, and state the counts so under-coverage is visible.

Report the coverage table first, so it's obvious nothing was sampled:

| file | docstring lines | comment lines | total prose | blocks audited |
|---|---|---|---|---|

### The table

One row per **block** (a docstring, or a run of consecutive comment lines):

| Block (`file:line`) | First 8 words | Lines | Fails | Verdict | Replacement |
|---|---|---|---|---|---|

### Rule codes — what a block can fail on

Cite the codes in the `Fails` column. They're faster to scan than prose and they force the docstring-specific failures to be named:

| code | meaning |
|---|---|
| `NAME` | restates the function / class / test name |
| `SIG` | restates the signature — params, return type, an `Args:`/`Returns:` block, or a frozen dataclass's field names |
| `TOC` | table of contents — lists what is below it |
| `R1` | narrates **what** the code does rather than **why** |
| `R2` | delete-and-reread: removing it costs nothing |
| `R3` | dissolvable by a better name or an extracted function |
| `R4` | **factually false or stale** against the current code |
| `R5` | over-written — the reason is real but does not need this many lines |
| `R6` | development-process leakage (ticket / review / changelog / "as requested" / emoji) |
| `D(x)` | duplicate — the same fact is stated at `x` |

`NAME`, `SIG` and `TOC` are where docstring slop concentrates, and none of them is a "comment" failure mode — which is why a comments-only audit finds nothing.

`R6` exception: a `TODO` tied to a tracked ticket, or a citation of a durable external reason (spec section, RFC, linked bug documenting a workaround's why).

### The survival test is "does this earn its lines?"

Not "is it true?" — true-but-unnecessary is the most common surviving slop. A block survives only if every line of it is load-bearing.

**"Explains why" is necessary, not sufficient.** A block can name a real reason and still be slop if it's longer than that reason needs, or narrates the adjacent operation alongside it. Compress to the single load-bearing clause; if the why is one phrase, the comment is one line. A 3–4 line block guarding a one-line call is almost always over-written even when its content is genuinely "why" — `Rewrite` it, don't `Keep` it.

**Cut process-leakage labels — don't compress them.** Inline planning/process labels are slop to **cut**, not shrink. A parenthetical like `(P1 mitigation)`, `(phase 2)`, a ticket-process reference, or a "step N of the plan" tag adds no durable why — passing "explains why" does not save it. Delete the label outright; keep only the load-bearing technical reason, if any, as its own one-line comment.

### R4 is the highest-yield check in the pass — run it against the code, not against plausibility

Read the cited code and confirm each factual claim. Don't grant an unverifiable claim the benefit of the doubt: an assertion you cannot check is an assertion to cut or soften, not to keep.

### The audit is not self-verifying

**Re-check the replacement text you write.** Replacement prose is newly generated and fails R4 at the same rate as the prose it replaces — in practice a false claim has been *introduced* by a prose audit's own suggested replacement. Before applying a `Rewrite`, verify the replacement against the code the same way you verified the original. This also applies to prose the current change introduced: audit `git diff <base>...HEAD`, so blocks an earlier commit on the branch added are re-examined, including ones added by an earlier cleanup pass.

## Verdict and action

Verdict ∈ `Keep` / `Rewrite` (a real why is buried in noise → compress) / `Cut`.

Act hybrid: **auto-cut/auto-rewrite the unambiguous `Cut`/`Rewrite` rows**, then re-run the touched tests to confirm still-green. Leave genuinely debatable rows in place and list them for the user to decide.

Expect a high cut-or-rewrite rate on AI-written code. If the pass reports under ~30%, suspect the enumeration missed docstrings rather than concluding the prose is clean.

## Output

Report concisely:
- the coverage table (so under-enumeration is visible),
- the prose-audit table,
- the abstraction-audit findings (which single-use indirections were inlined),
- the non-prose slop removed (defensive checks, casts, style),
- the net line delta,
- any debatable rows left for the user,
- any `R4` (false claim) findings called out separately — they're bugs in the record, not style.
