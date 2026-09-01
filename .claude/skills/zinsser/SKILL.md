---
name: zinsser
description: Write and edit prose in Simplified Technical English (ASD-STE100) crossed with William Zinsser's On Writing Well — short sentences, active verbs, one word per meaning, no clutter. Use when drafting or revising any prose in this repo: docs, READMEs, PR descriptions, Jira tickets, tech specs, RFCs, commit bodies, code comments, Slack drafts, or when asked to "zinsser this", tighten writing, cut clutter, or make text plainer.
---

# Zinsser × Simplified Technical English

Two traditions, one goal: the reader understands on the first pass.

- **ASD-STE100** (Simplified Technical English) supplies the hard, checkable constraints. It exists so aircraft maintenance manuals cannot be misread, including by non-native readers. Its rules are mechanical and you can verify them.
- **Zinsser** (*On Writing Well*) supplies the judgment: what to cut, what to trust the reader with, how not to sound like a machine.

When they conflict, STE wins for procedures, warnings, API reference, and runbooks. Zinsser wins for narrative prose — PR descriptions, specs, docs that explain *why*.

## Scope

Applies to prose. Does **not** apply to:

- Code identifiers, variable names, or anything the compiler reads.
- Direct quotes, log output, error strings you are reproducing verbatim.
- Existing text you were not asked to touch. Do not rewrite neighboring paragraphs for style.

Never change a number, a table value, a command, or a path while editing for style.

## The hard rules (STE)

**Words**

1. One word, one meaning. Pick a term and repeat it. Do not vary the wording for elegance — "the request", then "the call", then "the payload" reads as three things.
2. One meaning, one word. If "session" means two different things in the doc, rename one.
3. Prefer the short, common word. `use` not `utilize`. `start` not `initiate`. `about` not `approximately`. `so` not `accordingly`.
4. No slang, no idioms, no jargon the reader has not been given. Metaphors are a Zinsser tool, not an STE one — use them in explanatory prose, never in a procedure.

**Verbs**

5. Active voice. Name the actor. "The worker retries the job", not "the job is retried".
6. Simple tenses only: simple present, simple past, simple future. Avoid perfect and progressive forms where a simple tense works.
7. Avoid `-ing` forms. Recast gerunds and participles as finite verbs or separate sentences.
8. Verbs, not nominalizations. `decide` not `make a decision`; `fails` not `results in failure`.

**Sentences**

9. Procedures and instructions: 20 words maximum. Explanatory prose: 25.
10. One instruction per sentence. Two actions get two sentences, or two numbered steps.
11. Noun clusters: three words maximum. `batch job retry delay override` becomes `the retry-delay override for a batch job`.
12. Paragraphs: six sentences maximum. One topic each, stated in the first sentence.
13. Sequential actions go in a numbered list, in the order the reader performs them.

**Safety and consequence**

14. Put the warning before the step it applies to, never after.
15. State the condition first, then the action: "If the lock is held, retry." Not "Retry if the lock is held."

## The judgment rules (Zinsser)

16. **Strip every sentence to its cleanest components.** Ask of each word whether it is doing work. Most are not.
17. **Kill the qualifiers.** `very`, `quite`, `rather`, `somewhat`, `a bit`, `sort of`, `pretty much`, `basically`, `essentially`, `actually`, `really`, `just`, `simply`. Zinsser: do not hedge your prose with little timidities. `simply` is the worst offender in engineering writing — it tells a stuck reader they are stupid.
18. **Kill the throat-clearing.** `It is important to note that`, `It should be mentioned`, `In order to`, `At this point in time`, `The fact that`, `There is/are ... that`. Start at the sentence's actual subject.
19. **Most adverbs and adjectives are redundant.** If the verb is right, the adverb is not needed. `effortlessly easy`, `completely eliminate`, `carefully consider`.
20. **Trust the reader.** Do not explain the same point twice in different words, and do not signpost what the next paragraph will say when the reader is one line from reading it.
21. **The lead does the most work.** First sentence: what this is and why it matters. Not background, not scope-setting, not a restatement of the title.
22. **Unity.** One tense, one person, one level of formality throughout a document.
23. **No exclamation points.** No emoji-as-punctuation. No em-dash pileups.
24. **Rewriting is the writing.** Draft, then cut. Expect the second pass to remove 25–50% of the words with no loss of meaning.
25. **Be a person.** Concision is not coldness. A plain, direct human voice beats both padding and a robot.

## Procedure

When drafting:

1. Write the draft without stopping to edit.
2. Run the revision pass below.
3. Read the result aloud. Anything you stumble on, the reader stumbles on too.

When revising existing text (`/zinsser <target>`):

1. Read the whole target before changing anything. Note its type — procedure, explanation, or persuasion — because that sets whether STE or Zinsser dominates.
2. Pass one, delete: qualifiers, throat-clearing, redundant adjectives and adverbs, sentences that restate the previous sentence.
3. Pass two, convert: passive → active, nominalization → verb, `-ing` → finite verb, long sentence → two sentences.
4. Pass three, unify: one term per concept across the whole document. List the terms you standardized on.
5. Pass four, structure: sequential actions become numbered lists, paragraphs get topic sentences, warnings move above their steps.
6. Report the word count before and after, and flag anything you deliberately left alone and why.

Show the edit, do not just describe it. For a short target, give the rewritten text. For a long one, give the rewritten text plus a short list of the recurring problems so the author stops making them.

## Examples

**Nominalization, passive, throat-clearing**

> It should be noted that in the event that validation of the submitted payload is not successful, an error response will be returned by the API to the caller.

> If the payload fails validation, the API returns an error.

31 words to 9.

**Noun cluster, hedging, doubled meaning**

> This PR basically just adds some additional batch job retry delay override handling logic, which should hopefully fix the issue.

> This PR handles the retry-delay override for batch jobs. It fixes the wrong timestamps in notification emails.

**One instruction per sentence, warning placement**

> Run the migration and then restart the worker, but be careful because restarting during a run will drop in-flight jobs.

> Restarting during a run drops in-flight jobs. Confirm no jobs are in flight, then:
>
> 1. Run the migration.
> 2. Restart the worker.

**Term drift**

> The job pulls the record, then the handler enriches the row, and finally the entity is written back.

Three names for one thing. Pick `record` and use it three times.

## Relationship to other writing skills

- A readability-scorecard skill scores a document against readability standards. Use it for a review pass on a finished doc. Use `zinsser` when you want the text itself rewritten in this style.
- A repo's own product-copy or brand-voice skill covers user-facing copy. That takes precedence for anything an end user reads in the product. `zinsser` is for internal and technical writing.
- A repo's own PR-description skill or rule (e.g. under `.rulesync/`, `.cursor/rules/`) defines PR description *structure*. `zinsser` governs the prose inside that structure; it does not override the required sections.
