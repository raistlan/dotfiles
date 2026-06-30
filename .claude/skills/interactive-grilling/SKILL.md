---
name: interactive-grilling
description: HTML slideshow grilling. Stress-tests a plan or design one question at a time with informational and decision slides, recommends an answer for each, and accumulates resolved decisions to a buffer that drives a dark-mode HTML deck. Use for "interactive grill", "grill me with slides", "visual grilling", or any grill request that should be presented as a deck.
user-invocable: true
---

# Interactive grilling

A presentation-style variant of `grill-me`. You interview the user relentlessly about a
plan or design — one question at a time, each with a recommended answer — and you maintain
a visual deck alongside the conversation. The deck is a **read-only projection** of a
decisions buffer; the chat is where every answer is given.

## When to use

Triggers (any of):

- "Interactive grill", "grill me with slides", "visual grilling", "slideshow grill"
- A grill request where the user wants the design tree shown as a deck

Skip when:

- The user wants a plain text grilling with no deck — that's `grill-me`.
- The user wants a PR review deck — that's `interactive-pr-review`.

## Core behavior (inherited from grill-me)

- **One question at a time.** Wait for the answer before continuing. Asking multiple at
  once is bewildering.
- **Always recommend an answer.** Every decision slide carries your recommended choice and
  the reasoning, not just open options.
- **Walk the design tree.** Resolve dependencies between decisions in order; branch as
  answers come in.
- **Explore the codebase instead of asking** when a question is answerable from the code.
  Cite `file:line`; don't ask the user something the repo already settles.

## The three-layer model (load-bearing — read this)

Three separate layers, never collapsed:

- **Buffer** = state / single source of truth: `/tmp/grill-<topic>-decisions.md`. Holds each
  decision's `id`, `question`, `status`, `answer`, `recommendation`, `pruned_by`, and a
  `guard` (`active_if`). Schema and a fillable template:
  `references/decisions-buffer-template.md`.
- **Chat** = the ONLY input. You ask; the user answers in chat. There is no other way to
  answer a question.
- **HTML deck** = a read-only *view* of the buffer. Static HTML — no forms, no inputs, no
  file writes from the page. A pruned question has no answer box because the deck cannot be
  answered at all. This is what makes the deck safe: it is pure projection.

If the buffer and the deck disagree, the buffer wins; patch the deck to match.

## The asking loop (execute these steps deterministically)

1. **Pick the next question.** Scan the buffer for the **lowest-id** decision with
   `status: open` (or `reopened`) whose `guard` is satisfied by the current answers. If none
   qualify, the grilling is done — go to "Finishing".
2. **Ask it in chat**, with your recommended answer and the reasoning. One question only.
3. **Record the answer** in the buffer: set `status: answered` and fill in `answer` with the
   user's choice.
4. **Recompute every guard** against the updated answers. For each still-`open`/`reopened`
   decision whose guard now evaluates **false**, set `status: pruned` and `pruned_by` to the
   id of the decision whose answer obsoleted it. A pruned question is NEVER asked, so it can
   never be answered through this loop.
5. **Append any new branch questions** the answer opened as the next free ids (`D12`, `D13`,
   …). Never insert between existing ids; never reuse or renumber an id.
6. **Patch the deck** to mirror the buffer (new answers shown, newly pruned slides dimmed,
   new branch slides appended), then tell the user "reload to see D4 updated." Do this only
   at this decision boundary — see "Deck update discipline".
7. **Repeat** from step 1.

**Reopening is explicit.** The user must ask to revisit a question. When they do, set that
decision's `status: reopened`, clear its `pruned_by` if it was pruned, and it re-enters the
loop at step 1. Reopening never happens by accident or as a side effect of another answer.

## Building the deck

Write a single file at `/tmp/grill-<topic>-deck.html`. Copy `references/slideshow-template.html`
(a committed relative symlink to the shared template) and fill in slides.

- **Win95 theme.** The shared template is the Win95 theme (one `:root` palette); copy it as-is.
- **Open it ONCE**, after the first build, with `open /tmp/grill-<topic>-deck.html` (macOS).
  Never run `open` again for the rest of the session.
- **Stable ids, append-only.** Decision slides get `id="d1"`, `id="d2"`, … in ask order.
  Informational slides get `id="info-1"`, `id="info-2"`, …. Assign in content order,
  append-only, never renumber. `#d6` must keep resolving for the life of the deck. (See the
  template's top comment for the full routing contract.)
- **Counter shows active reality.** Render `Question N of M active · K pruned` — never
  "of total raised". The user should never expect to answer an obsolete question.

### Two slide kinds

- **INFORMATIONAL** (`id="info-N"`) — context/background the user needs before a cluster of
  decisions. Title + a `.callout` or prose. No question.
- **DECISION** (`id="dN"`) — one question per slide: the question as the `h2`, your
  recommended answer in a `.callout good` ("recommendation"), and the options below. This is
  display only; the answer arrives in chat.

### Pruned decision slides — INLINE + DIMMED (R-B4a)

A pruned decision slide **stays in its original ask-order position** (its `#dN` anchor still
resolves) and is rendered greyed-out so it reads as archival, not actionable:

- Add an unmistakable banner at the top of the slide — reuse `.callout` with a muted label,
  e.g. `N/A — pruned by D2 = A`.
- Dim the whole slide. Add a small grilling-specific helper to **your `/tmp` deck only** (not
  the shared template). For example, in the deck's `<style>`:

  ```css
  .slide.pruned { opacity: 0.45; filter: grayscale(0.7); }
  .slide.pruned .callout.pruned-banner { border-left-color: var(--muted); background: rgba(152,162,179,0.08); }
  ```

  and set `<section class="slide pruned" id="d6">` on the pruned slide. The dimming must be
  strong enough that the slide reads as obsolete at a glance.

## Deck update discipline (no auto-refresh, no forced re-open)

- The deck is **static**. It only changes when the **user reloads** in the browser.
- After patching the file at a decision boundary, tell the user what changed and to reload —
  e.g. "Patched the deck: D2 answered, D6/D8 pruned. Reload to see them dimmed."
- **Never run `open` again** mid-session and never steal focus. The single `open` is at first
  build only.
- **Update only at decision boundaries** — after an answer is recorded and guards recomputed.
  Never patch the file mid-read while the user is still on a slide thinking.

## Finishing

When no open/reopened question has a satisfied guard, summarize: the answered decisions in
order, and the pruned ones with what obsoleted them. The buffer is already the record.

## Integration with rudolph (R-B6)

The answered-decisions buffer is a **drop-in feed for rudolph phase 1** (`00-plan.md`). The
final plan lists the **answered** decisions (id, question, resolved answer) as the plan body;
the **pruned** decisions go in an appendix (id, question, `pruned_by`) for the record. Point
rudolph at `/tmp/grill-<topic>-decisions.md`.

## References

- `references/slideshow-template.html` — committed relative symlink to the shared slideshow
  shell (`../../interactive-pr-review/references/slideshow-template.html`), the Win95 dark
  theme. Copy to `/tmp` and fill in slides; grilling-specific styling (the `.pruned` helper)
  lives only in your `/tmp` copy.
- `references/decisions-buffer-template.md` — the buffer schema (id / question / status /
  answer / recommendation / pruned_by / guard) and a fillable starting point.
