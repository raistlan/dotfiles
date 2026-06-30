# PR #<N> — review comments to post

PR: <url>
Branch: <head-ref>
Head SHA: <head-sha>

Format below maps to `gh api` inline review comments. Each comment names the file, the line on the **PR's head SHA** (must be inside a touched diff hunk), the side (`RIGHT` for additions), and the body. Posted as a single review at the end.

---

## Review summary (review body)

```
<one-paragraph framing of the review — what's strong, what you're flagging, whether anything is gating merge>
```

---

## 1. <short title>

**File:** `path/to/file.tsx`
**Line:** <N on head SHA> (RIGHT — `<sample of the line so you can re-verify>`)
**Severity:** suggestion / nit / **please land before merging**

**Body:**

```
<the comment text the PR author will see, in their inline thread>
```

---

## 2. <short title>

**File:** `path/to/other.tsx`
**Line:** <M> (RIGHT)
**Severity:** ...

**Body:**

```
<...>
```

---

<!--
Conventions for this buffer:

- One H2 section per inline comment, numbered in the order they were raised.
- The "Body:" fenced block is what gets sent as the comment body verbatim.
  Keep it self-contained — the reader sees it without the surrounding context
  in the buffer.
- When the user changes their mind, *delete* the section. Don't strikethrough
  or mark stale — the JSON payload is generated from this file.
- Severity is for your own bookkeeping; it doesn't go to GitHub directly,
  but blockers should also be called out in the review summary.
- Always re-pin line numbers to the current head SHA before generating the
  JSON payload — if the author pushes a new commit mid-review, lines shift.
-->
