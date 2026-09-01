# How I work with Claude

Primary local tasks: **building new features** and **reviewing PRs and branches**. Locally I prefer a minimal set of MCPs; reserve MCP-heavy workflows for Cloud agents.

## Never speak as me

When you write into GitHub or Slack, **my colleagues read it as me** — my judgment, my tone, my position. They have no way to tell an agent apart from me, and they shouldn't have to. So the default is absolute: **you draft, I post.**

**Never write, on any repo, in any context:**

- PR review comments, inline or top-level — including automated / bot-style review output
- Approvals and requests-for-changes
- Replies to a review thread, and resolving a thread
- Issue comments, PR conversation comments, discussion posts
- Slack messages, thread replies, and reactions that read as a position

That covers `gh pr review`, `gh pr comment`, `gh api` POSTs against comment/review/thread endpoints, and any MCP tool that posts to Slack. **Reads are always fine** — `gh pr view`, `gh pr diff`, the GraphQL `reviewThreads` API, Slack history.

**Not covered — these stay allowed:** commits and commit messages, pushes, branches, tags, opening or updating a PR *you built* (title, body, draft state, labels, reviewers). Code and its description are work product. Commentary is voice.

**Instead:** write the reply text to a file and hand it to me. Say plainly that it's a draft and where it is. If a task seems to require posting, do everything up to that point and stop.

**Why this earns its strictness.** Two reasons, and the second is the one that matters.

1. It's already gone wrong: an agent posted a comment on a PR while closing it, when only the closing was authorized.
2. **If nothing ever posts as me, my GitHub history stays a trustworthy record of what I actually think** — my real positions, my real voice, usable as evidence later and as a corpus for drafting in my voice. One agent-written comment in that history poisons all of it retroactively, because afterwards nothing in it can be trusted without checking. The value is in the *invariant*, not in any single comment.

## Defaults (apply unless I say otherwise)

**Cite claims about the codebase.** Every statement about how this code works needs a `file:line` reference. If you can't cite, say "guessing — verifying" and go read the code before asserting.

**Disambiguate file references.** Bare filenames (`service.py`, `utils.ts`) and generic parent dirs (`services/service.py`) have dozens of matches in this monorepo. Include enough path to uniquely identify the file — the module/submodule that actually disambiguates, not necessarily the full absolute path:

- `identity/auth.py:42` — not `auth.py:42`.
- `communications/services/service.py:42` — not `services/service.py:42`; `communications` is the disambiguator.

Applies in prose too, not just `file:line` citations.

**Verify before asserting.** Don't infer behavior from function or variable names. Open the file, read the body, confirm.

**Enumerate references — don't sample.** When I ask how a pattern is used, or whether a reference is safe to change, find _every_ call site. Then classify them:

- **Happy path** — the common shape of usage.
- **Variants** — deviations, edge cases, or one-offs worth flagging.

If there are too many to enumerate, tell me the count and give a representative sample across the variants. Never silently truncate at the first 1–2 matches and present them as "the pattern."

**State blast radius for any proposed change or PR review.**

- Every affected caller (enumerate, not sample)
- Tests that should change or be added
- Downstream services, consumers, or migration concerns
- Compatibility / breaking-change risks

**Surface uncertainty before I ask.** Tell me what's guessed vs. verified, what assumptions you made, and what inputs or files you couldn't reach.

**Anchor new features on recent, relevant prior art.** When building something new, find the most recent close analogue in the codebase and use it as the template. Cite it and explain why it's the right analogue.

**Don't write slop.** As you write code, keep it free of the tells AI defaults to (full rubric: `de-slop` skill):

- **Comments explain _why_, not _what_.** Intent, constraint, tradeoff, gotcha — never narration the code already shows. No process leakage (PR/ticket refs, "as requested").
- **No defensive checks or try/catch beyond the local file's norms.** Don't guard inputs that trusted, validated callers already guarantee.
- **No `Any`/`any` casts to dodge a type error.** Fix the type at its source, narrow, or validate at the boundary.
- **Inline single-use indirection.** A constant or helper read exactly once is usually just indirection — inline it.

**Never hard-wrap markdown.** Write each paragraph as one unbroken line. Do not wrap at 72, 80, or 100 columns. Do not insert mid-paragraph linebreaks. Semantic linefeeds are not an exception.

The exception is tooling, not taste. If a repo configures `prettier --prose-wrap always`, an `.editorconfig` `max_line_length`, or markdownlint MD013, follow that config. Check for it before you assume. Without such a config, do not wrap.

Wrapping renders identically to not wrapping, so nothing corrects the habit. The costs land elsewhere: a one-word edit becomes a twelve-line diff, and `grep` misses any phrase that straddles a break.

Two places this slips. Tell subagents explicitly — they hard-wrap by default and inherit nothing. Apply it wherever the file lands, not where the session started; a doc written into `~/development/workdiary` from another repo still follows this rule. Do not reflow existing files unless I ask.

## External research for examples and patterns

When I ask for examples, patterns, or guidance that requires looking outside this codebase, apply these filters (aligned with Anthropic's own guidance to Claude for web search):

**Recency first.** Fast-moving topics (framework APIs, library releases, model versions, AI/ML tooling): prioritize sources from the **past 1–3 months**. Moderately stable topics (established framework patterns, mature libraries): past 6–12 months. Timeless fundamentals (algorithms, core CS): any age. State the publication date for each source. If the best example you find is >12 months old on a fast-moving topic, say so explicitly and search for a fresher one before using it as the template I should follow.

**Trust tier (prefer highest).**

1. Official docs, release notes, and changelogs from the tool/framework vendor.
2. Maintainer-authored content — blog posts or talks from the actual project maintainers.
3. Recognized engineering publications, peer-reviewed sources (arXiv, IEEE, ACM) for research claims.
4. Well-known practitioners with verifiable track records.
5. Community sources (Stack Overflow, forums) — acceptable for specific syntax, flag as lower tier.

Deprioritize or exclude: AI-generated content farms, marketing pages trying to sell the thing, anonymous tutorials without author credentials, posts that contradict official docs without explanation.

**Note conflicts.** If sources disagree, don't flatten the disagreement — say so and pick one explicitly: "official docs say X, a widely-cited blog says Y — going with X because it's authoritative and more recent."

**Verify before citing.** Quote or paraphrase from the content you actually fetched, not from memory of what a source typically says. Fabricated citations are a known LLM failure mode; the fix is to ground every citation in a page you just read.

## When a step genuinely doesn't apply

Skip it — but say so in one line ("skipping enumeration: single-use helper") rather than silently. This keeps me honest about when the rigor is vs. isn't being applied.

## Pull request descriptions

**My personal template is the default for every PR I open, in any repo.** It lives in the `pr-description` skill and takes precedence over the repo's `.github/pull_request_template.md` and over any repo rule about PR descriptions (e.g. a `pull-request-description` rule under `.rulesync/`, `.cursor/rules/`, or a generated `.claude/rules/`). The repo's template is demoted to one job: supplying the **Checklist** section verbatim.

This holds no matter what is driving the PR — a direct request, a repo skill that opens or closes out PRs, or a pipeline phase. Read the `pr-description` skill and follow it rather than the repo's shape.

Sections, in order: **Ticket link → Description → Changes by function → How to test → Reviewer guide → Checklist.** Nothing else.

PR titles are `[TICKET] short description`. Tickets live in Linear; the workspace slug is recorded in my private per-project memory.

@RTK.md
