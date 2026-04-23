# How I work with Claude

Primary local tasks: **building new features** and **reviewing PRs and branches** in the Acme monorepo. Locally I prefer a minimal set of MCPs; reserve MCP-heavy workflows for Cloud agents.

## Defaults (apply unless I say otherwise)

**Cite claims about the codebase.** Every statement about how this code works needs a `file:line` reference. If you can't cite, say "guessing — verifying" and go read the code before asserting.

**Disambiguate file references.** Bare filenames (`service.py`, `utils.ts`) and generic parent dirs (`services/service.py`) have dozens of matches in this monorepo. Include enough path to uniquely identify the file — the module/submodule that actually disambiguates, not necessarily the full absolute path:
- `identity/auth.py:42` — not `auth.py:42`.
- `communications/services/service.py:42` — not `services/service.py:42`; `communications` is the disambiguator.

Applies in prose too, not just `file:line` citations.

**Verify before asserting.** Don't infer behavior from function or variable names. Open the file, read the body, confirm.

**Enumerate references — don't sample.** When I ask how a pattern is used, or whether a reference is safe to change, find *every* call site. Then classify them:
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
