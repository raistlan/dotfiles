# Grilling decisions — <topic>

Deck: /tmp/grill-<topic>-deck.html

Single source of truth for the session: the deck is a read-only projection of this file, and
chat is the only input. Change status here first, then patch the deck. Full protocol lives in
the interactive-grilling SKILL — this is just the shape.

Fields: **id** (`D1`..`Dn`, ask-order, never reused or renumbered) · **question** · **status**
(`open` | `answered` | `pruned` | `reopened`) · **answer** · **recommendation** · **pruned_by**
(set only when pruned) · **guard** / `active_if` (live-when condition; empty = always active;
pruned when its guard evaluates false after an answer).

---

## Decisions

### D1
- **question:** <the first question>
- **status:** answered
- **recommendation:** <your recommended answer>
- **answer:** <the user's answer>
- **pruned_by:** —
- **guard:** —

### D2
- **question:** <branching question — its answer gates later ids>
- **status:** answered
- **recommendation:** A
- **answer:** A
- **pruned_by:** —
- **guard:** —

### D3
- **question:** <only relevant if D2 = A>
- **status:** open
- **recommendation:** <your recommended answer>
- **answer:**
- **pruned_by:** —
- **guard:** D2 ∈ {A}

### D6
- **question:** <made moot by D2's answer>
- **status:** pruned
- **recommendation:** <n/a>
- **answer:**
- **pruned_by:** D2
- **guard:** D2 ∈ {B}

---

## Informational notes

Context slides, not questions. Ids `info-1`, `info-2`, … (append-only, no status).

### info-1
- **title:** <slide title>
- **body:** <one-paragraph context the user needs before the next decisions>
