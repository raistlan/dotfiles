---
name: interactive-pr-review
description: Reviews a GitHub PR with an interactive HTML slideshow walkthrough. Generates a self-contained HTML deck at /tmp/pr-NNNNN-review.html, walks through it conversationally, accumulates inline review comments in /tmp/pr-NNNNN-comments.md as they're decided, and posts them all at the end via gh api. Use when the user asks for an interactive PR review, "walk me through this PR", a slideshow review, or wants to review collaboratively with comments batched for one-shot posting.
user-invocable: true
---

# Interactive PR review

A collaborative review workflow. You build the user a visual walkthrough of the PR, talk through it with them, and accumulate the comments they decide to raise in a side buffer. When they're done, you submit one review via the GitHub API with all the inline comments anchored to the correct lines.

## When to use

Triggers (any of):

- "Review PR #N" / "Walk me through PR #N" / "Help me review <PR URL>"
- "Interactive review", "slideshow review", "PR walkthrough"
- The user shares a GitHub PR URL with any phrasing about review

Skip when:

- The user wants automated review (bugbot, slop-review, security-review) — those are different skills.
- The user wants to _answer comments on their own PR_ — that's `resolve-pr-comments`.
- The user just wants a static diff explanation, no slideshow.

## Workflow

Be explicit with the user at each transition.

### 0. Bootstrap superpowers (opt-in)

If `superpowers:using-superpowers` appears in the loaded skills list for this session, invoke it via the `Skill` tool before starting phase 1. This activates verify-before-assert / check-related-skills rules for the rest of the review.

If superpowers isn't installed for this user, **skip this step silently** — do not call the `Skill` tool with a name that isn't in the loaded skill list (it will fail), and do not warn the user. The rest of the workflow is self-contained and works without it.

### 1. Fetch and orient

```bash
gh pr view <N> --repo <owner>/<repo> --json title,body,author,state,baseRefName,headRefName,additions,deletions,changedFiles,files,commits,url
gh pr diff <N> --repo <owner>/<repo> > /tmp/pr-<N>.diff
git fetch origin pull/<N>/head:pr-<N>     # local ref for `git show pr-<N>:<path>`
git fetch origin <baseRefName>            # refresh the base so diffs anchor on the real merge base
git diff origin/<baseRefName>...pr-<N> --stat
```

Capture: head SHA (last commit), changed files, additions/deletions, PR description. The head SHA goes into the review payload — keep it handy.

**Always diff against `origin/<baseRefName>` (refreshed), never a bare local `main`.** A stale local `main` makes work that landed since branch-off appear as phantom _added_ hunks — you'll review code that isn't in the PR (and waste a slide flagging it). `<baseRefName>` comes from the `gh pr view` JSON above; it's usually `main` but not always. The `...` (three-dot) anchors on the merge base, which is exactly the PR's changes. Cross-check magnitudes against `gh pr view`'s `files` array — if a file shows as a huge new file locally but `+small/-small` in the JSON, your base is stale.

### 2. Read every file, then triage what to surface

Read every changed file in the PR — yes, all 27 if there are 27. Skimming is fine for mechanical content (renames, boilerplate), but actually open them. The point is to avoid missing issues hiding in files that didn't look substantive from the stat.

**Exception: auto-generated files can be skipped entirely.** OpenAPI clients, codegen'd TypeScript types, lockfiles (`pnpm-lock.yaml`, `poetry.lock`), snapshot files, anything with a "DO NOT EDIT" header — there's nothing for a human reviewer to catch in these, and they bloat context. If a generated file changed, note it on the mechanical summary slide and move on.

Read from the PR ref, not main: `git show pr-<N>:<path>` or `git -C <repo> show pr-<N>:<path>`.

Triage happens at the _slideshow_ layer, not the _reading_ layer. After reading, decide which files earn their own slide vs. get rolled into a "mechanical changes" summary slide. Prioritize for slides:

- New components / modules
- State machines, contexts, hooks, services with branching logic
- Anything the PR description points at ("focus" / "reviewer guide")
- One representative call site for any mass-migration pattern (mention the others exist; don't slide each)
- New tests, to gauge coverage
- Anything you noticed during the full read that the stat _wouldn't_ have flagged

### 3. Build the HTML slideshow

Write a single file at `/tmp/pr-<N>-review.html`. See `references/slideshow-template.html` for the canonical structure — copy it and fill in slides.

Conventions:

- **Self-contained, with one exception.** No external CSS/fonts. The only allowed external dep is the highlight.js script the template loads from cdnjs for syntax coloring; if it's blocked, code still renders (unstyled). Everything else must work offline.
- **Tag code blocks with a language class** so highlight.js can color them: `<pre><code class="language-tsx">…</code></pre>`. Use `language-python`, `language-sql`, `language-bash`, `language-diff`, `language-json`, etc. — match what the changed file actually is. Blocks without a class fall back to auto-detection but explicit is better. Skip the class on the hand-rolled before/after diff blocks that use `.added`/`.removed` spans — the template's highlighter ignores those on purpose.
- **Win95 theme.** The template ships one palette (Win95 retro dark).
- **One concept per slide.** Don't cram. Long content scrolls within the slide.
- **Stable slide ids.** Give every `<section class="slide">` a unique `id` (`id="title"`, `id="d1"`, `id="info-1"`, …), assigned in content order, append-only, never renumbered. Routing keys off these ids, so inserting or dimming a slide never shifts another slide's anchor. See the template's top comment for the full convention.
- **Keyboard nav.** Arrow keys, Space, PageDown, number keys (1–9 jump to the Nth slide in DOM order). Hash routing is id-based: `#d3` selects the slide with `id="d3"`.
- **Use callouts for emphasis** — `info`, `good`, `warn`, `danger`. Spend warnings sparingly.
- **Pin filepaths and line numbers** inside code blocks with the `.filepath` span. Reviewers care where the code lives.

Suggested slide arc (adapt freely):

1. Title — PR meta (author, size, branch, ticket link).
2. What it does — one screen, in plain English.
3. Architecture / shape of the change.
4. Each substantive area (3–6 slides) — one decision per slide, with the relevant code block.
5. Call-site migration pattern, if applicable.
6. Tests.
7. Strengths.
8. Concerns / open questions.
9. Verdict + suggested asks before merge.

Open it after writing: `open /tmp/pr-<N>-review.html` (macOS) or `xdg-open` (Linux).

### 4. Walk through interactively

The user drives. They'll say "yes raise this", "drop that", "explain X", "why doesn't Y", etc. Your job:

- **Verify before asserting.** When the user pushes back on a claim ("why doesn't X handle this?"), check the code. Don't reason from names. Be honest if your earlier framing was wrong, and correct it on the slide too.
- **Accumulate comments to `/tmp/pr-<N>-comments.md`** the moment the user signals "raise this" / "yes flag that" — don't wait for the end. See the format in `references/comments-buffer-template.md`.
- **Drop comments cleanly** when the user changes their mind ("don't raise that"). Remove from the buffer, don't just mark stale.
- **Update the slideshow** to reflect the conversation when meaningful (corrected analysis, withdrawn concerns) — the user is seeing both the deck and the chat, keep them coherent.

### 5. Submit the review

When the user says "post it" / "submit" / "approve with comments":

1. Confirm event type (`APPROVE`, `REQUEST_CHANGES`, `COMMENT`) — use `AskUserQuestion` if not stated.
2. Compose the top-level review body — summarize the comments, call out which (if any) are merge-blocking.
3. **Verify each inline comment's line is on a touched diff hunk** before posting. See the gotcha section below — this trips up every first attempt.
4. Build the JSON payload at `/tmp/pr-<N>-review-payload.json`. Validate with `python3 -c "import json; json.load(open(...))"`.
5. Post via `gh api`:

   ```bash
   gh api --method POST repos/<owner>/<repo>/pulls/<N>/reviews \
     --input /tmp/pr-<N>-review-payload.json
   ```

6. Parse the response with `python3` to surface `state`, `html_url`, and `errors` (don't paste the raw JSON blob).
7. Report the review URL back to the user.

## Gotchas (the ones that bite)

### GitHub rejects inline comments not on a touched diff line

The API will return `422 "Line could not be resolved"`. **Always check which lines are in the diff before picking an anchor.**

```bash
git diff origin/<baseRefName>...pr-<N> -- <file> | grep '^@@'
```

Each `@@ -A,B +C,D @@` hunk means lines `C` through `C+D-1` on the new file are touched. Your comment's `line` must fall inside one of those ranges. If the substantive code is outside any hunk (e.g., the function body wasn't modified but you want to comment on it), anchor on the closest touched line and reference the function by name in the comment body.

### Long markdown bodies break command-line args

Use `--input <file>` with a JSON file, not `--field body=...`. Backticks, quotes, and newlines in code-fenced comments are easier to manage in a JSON file written via the Write tool.

### `commit_id` matters

Always include the head SHA in the payload. Without it, GitHub anchors the review to whatever the latest commit is at the moment of posting, which races if the author pushes between your read and your submit.

### `side: "RIGHT"` for additions

Almost always `RIGHT`. Use `LEFT` only when commenting on a line being removed (rare in this workflow).

## Files this skill writes

| Path                              | Purpose                                                                |
| --------------------------------- | ---------------------------------------------------------------------- |
| `/tmp/pr-<N>.diff`                | Full PR diff for reference.                                            |
| `/tmp/pr-<N>-review.html`         | The slideshow. User opens this in a browser.                           |
| `/tmp/pr-<N>-comments.md`         | Running review buffer. Accumulates inline comments as they're decided. |
| `/tmp/pr-<N>-review-payload.json` | Final JSON sent to `gh api`. Useful to inspect on 422s.                |

All four live in `/tmp/` — they're working artifacts, not committed. Don't manually `rm` them at the end; the OS handles cleanup.

## References

- `references/slideshow-template.html` — the canonical HTML slideshow shell (Win95 dark theme, keyboard nav, progress bar). Copy and fill in slides.
- `references/comments-buffer-template.md` — the format for `/tmp/pr-<N>-comments.md` so the buffer stays parseable as it grows.
