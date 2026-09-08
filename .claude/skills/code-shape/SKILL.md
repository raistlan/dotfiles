---
name: code-shape
description: How to decompose code so the public function reads as a narrative. Extract policy, not mechanism; name helpers with verbs; closed sets as enums; comments as facts on the line they govern; locals named for what they hold. Rules, a spectrum for when repetition earns a helper, the reviewer's questions, and anonymized before/after pairs. Load while writing code (the developer agent), and run its shape audit inside de-slop and quality-pass. Use when asked about code shape, decomposition, whether a helper earns its place, helper naming, or why a function is hard to follow.
user-invocable: true
---

# code-shape

The tell this fixes: **AI decomposes by mechanism; a good reader decomposes by narrative.**

The default failure looks like this. Every repeated expression and every nameable concept becomes a small, noun-named private helper. Each helper is clean in isolation. The public function becomes a chain of opaque names, and because no single place tells the story, the *why* scatters into a comment on each helper. A reader who wants to answer "what makes this check fail?" jumps through four definitions to reconstruct what one function would have said in twelve lines. Nine private helpers for two public functions is the shape to expect, and it has happened.

The target: **the public function is the story.** Read top to bottom, its statements are the algorithm. Helpers exist to hide a *policy* a reader would want to inspect on its own, and every call site reads as an English clause.

This is a writing discipline first and an audit second. `de-slop` catches single-use indirection after the fact; most of what this skill catches has two or three callers and survives that rule. Follow it while writing.

## The test at the call site

A helper earns its place when both hold:

1. **The call site reads as a clause of the story.** `if _can_see_user(auth, user)`, `gate_results, read_failures = _parse_stored_gate_results(stored)`. If you have to open the helper to know what the line means, the name failed or the helper should not exist.
2. **The body hides something worth inspecting on its own.** An authorization rule. A parsing contract with a degradation policy. A loop with a real invariant. Not a shorter spelling of a six-token expression.

## Rules

1. **The entry point reads as a narrative.** A reader who opens only the public function understands the whole behavior without jumping. Load, early-return the null case, compute, log, build the result. In that order, in that function.
2. **Extract policy, not mechanism.** Extract when the body is a rule that can change independently and deserves its own comment or cross-reference. Do not extract a shorter spelling of an expression. Test: would a reviewer want to read this in isolation? See the spectrum below for repetition.
3. **A helper's name completes "this function ___".** A verb or a predicate: `parse_stored_gate_results`, `can_see_user`, `matching_rows`. A noun phrase (`_outcome`, `_not_an_adult_reasons`, `_gate_name`) is a smell regardless of caller count. The public entry point is named for what it returns: `get_user_relationship_integrity`, not `get_verdict`.
4. **Locals say what they hold.** `missing` what? `missing_identity_fields`. `reads`? `parsed_entries`. A bare category noun forces the reader to look at the assignment.
5. **A static table plus a wrapper function is an `if`/`elif` in a costume.** Two or three fixed entries looked up once are branches. Write the branches, or a `match`. A dict is for data that varies at runtime or has many entries.
6. **Closed sets are enums, not strings assembled in code.** Reasons, failure kinds, field names that get logged. Free-text reason strings built with f-strings, or literals sprinkled across four helpers, are the tell. A `StrEnum` with a one-line comment per member is the fix, and it doubles as the documentation the helper docstrings were trying to be.
7. **Comments are facts on the line they govern.** A comment that *argues* for a decision ("so the log must not say so") is cut. A fact that applies to one branch sits on that branch, not in a block above the whole table. A fact about a column's storage behavior sits on the line that reads the column.
8. **Docstrings are one-sentence contracts.** State the invariant about inputs and outputs: "A relationship with no integrity row reads as NOT_VERIFIED, not an error." Reasoning paragraphs about rollout theory go in the PR description. A passthrough *does* get a docstring, one line, saying what it passes through to.
9. **Parallel functions stay parallel.** Two evaluators with the same shape carry the same TODOs, the same log keys, the same naming. A TODO on one and not the other is a defect, not style.
10. **No speculative surface.** A `*_by_id` variant, a loader wrapper, or an extra public function that nothing in this change calls does not ship. Add it in the change that needs it.

## Repetition is a spectrum

"Used more than once" does not settle whether something is a helper. Weigh body size against call count, and check for an existing utility before writing any helper.

| Body | Callers | Verdict |
|---|---|---|
| One line, one expression | 2 or 3 | **Inline.** `value is None or not value.strip()` three times is fine. The name adds nothing the expression lacks. |
| One line | Dozens, across modules | **Helper**, and it is probably a public util, so look for the existing one first. |
| Several lines of policy | 1 | **Depends on what the caller keeps.** If the caller would be left with only load, log, and return, fold the policy in; the caller is the story. Keep the helper only if the caller has its own narrative or the policy is genuinely expected to grow. Say that expectation in the PR, not in a comment. |
| Several lines of policy | 2 or more | **Helper.** Name it with a verb. |
| A loop, a `try`/`except`, or a `match` with a real invariant | 1 or more | **Helper is fine** if the call site reads as a clause. `_parse_entry` wrapping the try/except is a unit; `_outcome` wrapping a ternary is not. |

The developer agent's old rules ("if/else branches → extract a function", "loops → map/filter with small callbacks", "separate pure logic from side effects") produce the mechanism-decomposed shape directly. They are retired. Separation of pure logic from side effects is still right when the pure part is a policy with its own callers; it is wrong when it leaves the caller with nothing but a log line.

## The reviewer's questions

Ask these of every private helper, constant, and local before the code leaves your hands. They are the questions a human reviewer has actually asked, verbatim or nearly.

- Do we really need a whole private helper for this? Is there an existing public util that does it?
- Does the name have a verb? Does the call site read as a clause and contribute to the narrative?
- If this is only used once and the caller would be left with load, log, return, does the logic fit in the caller?
- If we expect this to grow, is that the reason it is separate? Then say so where the reviewer will see it.
- `missing` what? `reads` what? Name the local for what it holds.
- Why isn't the entry point named for what it returns?
- This comment: is it a fact about the line below it, or an argument for a decision nobody questioned?
- Is the parallel function shaped the same? Same TODOs, same log keys?
- What does an instance of this value look like, and when would it happen? If a reader has to find the tests to answer that, the type is too loose. Make it an enum.

## Examples

All three are anonymized from real changes. The structure, helper count, comment placement, and naming are preserved exactly; only the domain nouns changed.

### A. A gate evaluator: mechanism-decomposed, then rewritten as a narrative

**Before.** Nine private helpers for two public functions in the original; this is the half for one gate.

```python
def _is_blank(value: str | None) -> bool:
    # The column type trims padding on write but persists a whitespace-only
    # value as an empty string, not NULL. An `is None` check alone would
    # therefore miss a blank name.
    return value is None or not value.strip()


# `UNKNOWN` covers a future date and an age past the plausible maximum; both
# fail the check, but neither is "too young", so the log must not say so.
_NOT_AN_ADULT_REASONS = {
    AgeBand.MINOR: "under_18",
    AgeBand.UNKNOWN: "date_of_birth_implausible",
}


def _not_an_adult_reasons(date_of_birth: date | None) -> list[str]:
    # A missing date is already reported as `date_of_birth`; labeling it here
    # too would blur "no data" with the age reasons in the log.
    if date_of_birth is None:
        return []
    reason = _NOT_AN_ADULT_REASONS.get(age_band_for(date_of_birth))
    return [reason] if reason else []


def _missing_profile_fields(profile: Profile | None) -> list[str]:
    # A missing row reports every field, so the log names the same fields
    # whether the row is absent or blank.
    if profile is None:
        return ["first_name", "last_name", "date_of_birth"]
    missing: list[str] = []
    if _is_blank(profile.first_name):
        missing.append("first_name")
    if _is_blank(profile.last_name):
        missing.append("last_name")
    if profile.date_of_birth is None:
        missing.append("date_of_birth")
    return missing


def _missing_owner_fields(owner: Account, profile: Profile | None) -> list[str]:
    missing: list[str] = []
    if _is_blank(owner.email):
        missing.append("email")
    missing.extend(_missing_profile_fields(profile))
    if profile is not None:
        missing.extend(_not_an_adult_reasons(profile.date_of_birth))
    return missing


def _outcome(missing: list[str]) -> CheckOutcome:
    if missing:
        return CheckOutcome.FAILED
    return CheckOutcome.PASSED


def evaluate_owner_check(account: Account) -> CheckResult:
    profile = profile_repository.get_by_account_id(account.id)
    missing = _missing_owner_fields(account, profile)
    if missing:
        logger.warning(
            "Owner check failed",
            extra={"account_id": account.id, "missing": missing},
        )
    return CheckResult(check=Check.OWNER, outcome=_outcome(missing))
```

What a reviewer said about it, per line:

- `_is_blank`: "Do we really need a whole private helper to do this? Do we not have a public util?" Rule 2. Three callers, one expression. And the comment reveals the helper guards a case the column type already rules out.
- `_NOT_AN_ADULT_REASONS` comment: "The second sentence isn't valuable. Take the `UNKNOWN` fact and put it on the `UNKNOWN` line." Rule 7.
- `_not_an_adult_reasons`: "This comment doesn't make sense. Do we really need a whole private helper? Give it a verb and contribute to the narrative." Rules 3 and 5: a two-entry dict plus a wrapper is an `if`/`elif`.
- `missing`: "`missing` what? Rename to `missing_identity_fields`." Rule 4, three times.
- `_outcome`: "Feels like we don't need this to be a private method by itself." Rule 2. Two callers, one ternary.
- `_missing_owner_fields`: "If it's only used here and the only thing the rest of the caller does is get the profile and log, seems like the logic fits there? If we expect it to grow, maybe keep it." The spectrum's third row.

**After.** One public function that is the story, one enum that is the documentation.

```python
class OwnerCheckFailure(StrEnum):
    """Why an owner check fails. Logged, never shown to the account holder."""

    EMAIL = "email"
    FIRST_NAME = "first_name"
    LAST_NAME = "last_name"
    DATE_OF_BIRTH = "date_of_birth"
    UNDER_18 = "under_18"
    # `AgeBand.UNKNOWN` is a future date or an age past the plausible maximum.
    DATE_OF_BIRTH_IMPLAUSIBLE = "date_of_birth_implausible"


def evaluate_owner_check(account: Account) -> CheckResult:
    """An owner passes when email, legal name, and an adult date of birth are all present."""
    profile = profile_repository.get_by_account_id(account.id)

    failures: list[OwnerCheckFailure] = []
    # The column type strips whitespace on write and stores "" rather than NULL,
    # so `not` covers every blank.
    if not account.email:
        failures.append(OwnerCheckFailure.EMAIL)
    if profile is None or not profile.first_name:
        failures.append(OwnerCheckFailure.FIRST_NAME)
    if profile is None or not profile.last_name:
        failures.append(OwnerCheckFailure.LAST_NAME)
    if profile is None or profile.date_of_birth is None:
        failures.append(OwnerCheckFailure.DATE_OF_BIRTH)
    else:
        match age_band_for(profile.date_of_birth):
            case AgeBand.MINOR:
                failures.append(OwnerCheckFailure.UNDER_18)
            case AgeBand.UNKNOWN:
                failures.append(OwnerCheckFailure.DATE_OF_BIRTH_IMPLAUSIBLE)

    if failures:
        logger.warning(
            "Owner check failed",
            extra={"account_id": account.id, "failures": failures},
        )
    return CheckResult(
        check=Check.OWNER,
        outcome=CheckOutcome.FAILED if failures else CheckOutcome.PASSED,
    )
```

Zero private helpers, and the reader answers "what fails the owner check" without leaving the function. The one place the spectrum would pull a helper back out: if a second check (say, for a dependent account) shares the three name and date-of-birth branches, `_missing_profile_fields(profile) -> list[OwnerCheckFailure]` is several lines of policy with two callers, so it earns a verb-named helper. Everything else stays inline.

### B. Parsing a stored blob: the same helpers, reshaped after review

This one kept three helpers, because each is a real unit. What changed is the naming, the types, and where the prose went.

**Before.**

```python
def _read_step_results(stored: object) -> tuple[list[StepResult], list[str]]:
    """Read the stored blob into steps, paired with the reasons any read degraded.

    A blob that is not a list reads as no steps at all. Unlike the entry-level
    cases, no rolling deploy can produce that: the column only ever holds what
    a writer persisted through the typed create model. It still degrades rather
    than raises, so a single corrupt row cannot take the endpoint down for that
    run, and the reason it carries is what stops that hiding.
    """
    if not isinstance(stored, list):
        return [], [f"non-list payload: {type(stored).__name__}"]
    entries = cast("list[object]", stored)
    reads = [_read_step_result(entry) for entry in entries]
    return (
        [result for result, _ in reads],
        [reason for _, reason in reads if reason is not None],
    )


def _read_step_result(stored: object) -> tuple[StepResult, str | None]:
    """An entry this deploy cannot act on reads as SKIPPED, not an error.

    A newer pod can write a step name or an outcome value this one does not
    have, so this deploy may report SKIPPED for a step that pod calls FAILED.
    `status` is untouched, so the verdict stays honest and only the list of
    steps a caller can act on turns conservative. The cost is that
    `step_results` reads differently depending on which pod answers, and that
    beats one of them serving a permanent 500 for the run.

    The second element names why the entry degraded, so a caller can report
    that it happened without reporting what the entry held.
    """
    try:
        parsed = StepResult.model_validate(stored)
    except ValidationError:
        return _skipped(_step_name(stored)), "unparseable entry"
    if parsed.known_step is None:
        return _skipped(parsed.step), "unknown step name"
    return parsed, None


def _step_name(stored: object) -> str:
    match stored:
        case {"step": str(step)}:
            return step
        case _:
            return ""


def _skipped(step: str) -> StepResult:
    return StepResult(step=step, outcome=StepOutcome.SKIPPED)


def get_verdict(sync_run_id: int) -> SyncStatusRead:
    ...
```

What a reviewer said: "Why isn't this `get_sync_status`?" "This docstring is using weird jargon and the big paragraph is hard to grok." "It's hard to understand from looking at this what an instance of the reasons list might look like and when it would happen."

**After.**

```python
class StepReadFailure(StrEnum):
    """Every way a stored `step_results` blob can fail to read. The set is closed:
    what grows over time is the set of step names this deploy knows, not this.
    """

    # The typed create model only writes a list, so this is corruption.
    NOT_A_LIST = "not a list"
    # An entry that does not validate as a StepResult: not an object, no
    # outcome, or an outcome value only a newer deploy writes.
    UNPARSEABLE_ENTRY = "unparseable entry"
    # A valid entry naming a step only a newer deploy has.
    UNKNOWN_STEP = "unknown step name"


def _parse_stored_step_results(
    blob: object,
) -> tuple[list[StepResult], set[StepReadFailure]]:
    """Every entry yields a step, in its stored slot, so one bad entry degrades
    to a placeholder instead of 500ing the endpoint for that run.
    """
    if not isinstance(blob, list):
        return [], {StepReadFailure.NOT_A_LIST}
    # A decoded JSON array's element type is not something `isinstance` states.
    entries = cast("list[JsonValue]", blob)

    step_results: list[StepResult] = []
    read_failures: set[StepReadFailure] = set()
    for entry in entries:
        step_result, read_failure = _parse_entry(entry)
        step_results.append(step_result)
        if read_failure is not None:
            read_failures.add(read_failure)
    return step_results, read_failures


def _parse_entry(entry: JsonValue) -> tuple[StepResult, StepReadFailure | None]:
    try:
        parsed = StepResult.model_validate(entry)
    except ValidationError:
        return _skipped_step_result(entry), StepReadFailure.UNPARSEABLE_ENTRY
    if parsed.known_step is None:
        return _skipped_step_result(entry), StepReadFailure.UNKNOWN_STEP
    return parsed, None


def _skipped_step_result(entry: JsonValue) -> StepResult:
    # The entry's own step name if it has one, else "". Never str(entry): that
    # would put the stored contents in the response.
    match entry:
        case {"step": str(step)}:
            pass
        case _:
            step = ""
    return StepResult(step=step, outcome=StepOutcome.SKIPPED)


def get_sync_status(sync_run_id: int) -> SyncStatusRead:
    """A run with no status row reads as NOT_STARTED, not an error."""
    ...
```

What moved and why:

- The free-text reasons became `StepReadFailure`. A reader now sees every possible value and when each happens without opening the tests. Rule 6.
- The seven-line rollout essays became one-sentence contracts. The per-member comments on the enum carry the facts the essays were burying. Rules 7 and 8.
- `_read_step_results` became `_parse_stored_step_results`, `_read_step_result` became `_parse_entry`, `_skipped` became `_skipped_step_result`. Each call site now reads as a clause. Rule 3.
- `_step_name` folded into `_skipped_step_result`, which is its only caller. The `match` still exists; it just lives where it is used. Spectrum, third row.
- `get_verdict` became `get_sync_status`: named for what it returns.
- The list comprehension pair over `reads` became one loop that names both outputs. Rule 4: `reads` said nothing.

### C. A lookup endpoint written narrative-first

Hand-written after two rounds of failing to get the mechanism-decomposed version there. Six helpers, and every one hides a policy.

```python
def _matching_rows[Row: (Customer, Vendor)](
    lookup: LookupRequest,
    by_id: Callable[[int], Row | None],
    by_email: Callable[[str], Row | None],
) -> list[Row]:
    """Dedupe the rows, not the results, so the per-customer visibility check
    runs once per row rather than once per lookup that found it.
    """
    candidates: list[Row | None] = []
    if lookup.id is not None:
        candidates.append(by_id(lookup.id))
    if lookup.email is not None:
        candidates.append(by_email(lookup.email))

    matches: dict[int, Row] = {}
    for row in candidates:
        if row:
            matches.setdefault(row.id, row)
    return list(matches.values())


def _customer_result(customer_id: int) -> LookupResult:
    return LookupResult(
        type=LookupResultType.CUSTOMER, id=customer_id, path=f"/customers/{customer_id}"
    )


def _vendor_result(vendor_id: int) -> LookupResult:
    return LookupResult(
        type=LookupResultType.VENDOR, id=vendor_id, path=f"/vendors/{vendor_id}"
    )


def _can_search_customers(auth: AuthContext) -> bool:
    # Matches Customer Search (GET /customer-search): support staff and account managers.
    return access_control.is_support_staff(auth) or access_control.is_account_manager(auth)


def _can_search_vendors(auth: AuthContext) -> bool:
    # Matches Vendor Search (GET /vendor-search): any admin user, evaluated on
    # token_user like that endpoint does.
    return access_control.is_admin_user(auth.token_user)


def _can_see_customer(auth: AuthContext, customer: Customer) -> bool:
    # Deliberately tighter than Customer Search, which also grants unscoped
    # visibility to any admin. Here an admin without support-staff access sees
    # only what their account-manager assignment already covers.
    if access_control.is_support_staff(auth):
        return True
    return access_control.has_account_manager_access(auth.token_user, customer.id)


@router.post("/quick-lookup")
def quick_lookup(auth: AuthContext, lookup: LookupRequest) -> list[LookupResult]:
    """Look up customers and vendors by exact id or email for the admin command palette.

    Returns a flat list, customers before vendors. A numeric id can match one
    customer and one vendor because the two id spaces are independent.
    """
    can_search_customers = _can_search_customers(auth)
    can_search_vendors = _can_search_vendors(auth)
    if not (can_search_customers or can_search_vendors):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN)

    results: list[LookupResult] = []

    if can_search_customers:
        customers = _matching_rows(
            lookup, customer_repository.get_by_id, customer_repository.get_by_email
        )
        results.extend(
            _customer_result(c.id) for c in customers if _can_see_customer(auth, c)
        )

    if can_search_vendors:
        vendors = _matching_rows(
            lookup, vendor_repository.get_by_id, vendor_repository.get_first_by_email
        )
        results.extend(_vendor_result(v.id) for v in vendors)

    return results
```

Why this reads:

- The body is five beats: compute two permissions, 403, customers, vendors, return. A security reviewer reads the endpoint in one screen.
- The three `_can_*` predicates are policies. Each carries a comment citing the endpoint whose rule it mirrors, or the way it deliberately differs. That is the *why* a reviewer wants, on the line that implements it.
- `_matching_rows` has two callers with different row types and a real reason for its shape, stated in one sentence.
- `_customer_result` and `_vendor_result` are constructors that keep each generator expression on one line. They are the closest thing to mechanism here, and they earn it by keeping the beats readable. Reasonable people could inline them.
- Every call site reads as a clause: `if _can_see_customer(auth, c)`, `customers = _matching_rows(...)`.

## Shape audit (for de-slop and quality-pass)

Run this over `git diff <base>...HEAD` after the prose audit. Enumerate mechanically, do not sample: every new private helper, every new module-level constant, and every local whose name is a bare category noun (`missing`, `reads`, `result`, `data`, `items`).

| Name (`file:line`) | Kind | Callers | Body lines | Policy or mechanism | Call site reads as a clause? | Verdict |
|---|---|---|---|---|---|---|

Verdict is one of `Keep`, `Rename` (give it a verb, or name the local for what it holds), `Inline` (into its caller or callers), `Enum` (a closed set of strings becomes a `StrEnum`), `Fold` (a lookup table plus wrapper becomes branches). Apply the spectrum table for anything with two or three callers; a caller count above one is not a pass by itself.

Then check the public functions: does each read top to bottom as the algorithm? Are parallel functions shaped the same, with the same TODOs and log keys? Is anything public that nothing in this change calls?

Act on the unambiguous rows, re-run the touched tests, and list the debatable rows (usually the spectrum's third row, "several lines, one caller") for the user with the question stated: does the caller keep a story of its own, or is this expected to grow?

Report the table, the counts by verdict, and the net helper count before and after.
