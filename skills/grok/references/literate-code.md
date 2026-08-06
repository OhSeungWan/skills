# Writing the literate code walkthrough

By the time a reader reaches the Code section, Background has given them the surrounding context and Intuition has given them the one-sentence point and a concrete example of it in action. Code's job is narrower than either of those: show them the actual mechanism, in the actual diff, in an order and at a level of detail that makes the mechanism obvious rather than merely present. That distinction — obvious versus merely present — is the whole difference between a literate walkthrough and a file dump, and this document is about how to land on the right side of it.

## The file order in the diff is not the reading order

`git diff` and most diff viewers present files in whatever order the filesystem or the diff tool chose — usually alphabetical, sometimes just the order they happened to be staged. That order has nothing to do with how a human should read them. A change that adds exponential backoff might touch `RetryPolicy.java`, `RetryConfig.java`, `BackoffCalculator.java`, and three test files, in that alphabetical order — but the *reading* order that actually builds understanding is probably `BackoffCalculator.java` first (the new piece of logic that does the actual computation), then `RetryConfig.java` (the new fields that parameterize it), then `RetryPolicy.java` (where the calculator gets wired into the retry loop), then the tests last, as confirmation of the behavior already explained.

Never let the Code section's structure be dictated by the order files appear in the diff. Instead, **group and reorder the files by comprehension** — read through the whole diff first, identify the piece that most directly embodies the one-sentence point from Intuition, and put that first regardless of where it sits alphabetically or in the diff output. Everything else gets ordered by how directly it supports that central piece: the thing it depends on next, the thing that calls it after that, and finally the parts — tests, minor config, incidental renames — that confirm or support the core mechanism without being it.

A useful heuristic for finding the right order: ask "if the reader only read one file from this diff, which one would make the point?" That file goes first. Then ask the same question about what's left, repeatedly, until every file has a place. Files that exist only to support something already covered (a constant extracted into a shared config, a test that exercises the new path) belong near whatever they support, not off in their own untethered section just because that's where they sit in the diff.

## Introduce each piece before showing its code

Every code excerpt in the Code section is preceded by a sentence or two of prose that says what this piece of code does and why it exists — never let a code block appear cold, with the explanation trailing after it or absent entirely. The reader should know what they're about to look at before they look at it, the same way a good technical book never drops a code listing on the page without a lead-in sentence explaining its purpose.

Concretely, that means writing "This is where the new backoff schedule actually gets computed: given the attempt number, it returns how long to wait before retrying" *before* the `BackoffCalculator.calculate()` excerpt, not after it. The prose primes the reader's attention — they now know to look for how the attempt number feeds the formula, rather than reading the method blind and reconstructing its purpose from the return statement at the end.

This "what this piece does, then the code" pairing is also what the assembled Notion page depends on structurally: each excerpt is a fenced code block immediately followed by a callout carrying the explanation for it (see `references/notion-assembly.md`), but the callout explains what's *inside* the excerpt at a line level — key expressions, the one branch that matters, the edge case that's easy to miss. The prose that comes *before* the block is the coarser-grained one: what this chunk of code is for, in a sentence, before the reader's eyes land on a single line of it.

## Show only what's relevant, and say so

A literate walkthrough excerpts. It does not reproduce whole files, and it does not walk line by line through code that isn't part of the point being made. If `BackoffCalculator.java` is forty lines and the new logic is eight of them, show the eight — not the imports, not the class declaration boilerplate, not an unrelated helper method sitting in the same file. Every excerpt should be small enough that a reader can hold the whole thing in view at once and see how it relates to the sentence that introduced it.

Render each excerpt in a `<pre>`-style code block, exactly as it appears in the diff (matching indentation and surrounding syntax so a reader could find it in the actual file), and follow it with a callout that does two things: names the key line or expression that makes this excerpt do what the intro sentence said it does, and flags any edge case a careless reader would miss. For the backoff calculator, that might be:

```
long delay = Math.min(baseDelayMs * (1L << attempt), maxDelayMs);
long jitter = ThreadLocalRandom.current().nextLong(jitterMs);
return delay + jitter;
```

with a callout reading: "`1L << attempt` is the exponential part — it doubles the delay on every attempt, so attempt 0 waits `baseDelayMs`, attempt 1 waits `2×baseDelayMs`, attempt 2 waits `4×baseDelayMs`, and so on. The `Math.min` against `maxDelayMs` is the edge case worth noticing: without it, a request that's already failed nine or ten times would be told to wait minutes or hours, which is why the cap exists at all — remove it and a client with unusually bad luck stalls far longer than intended."

That callout does real work: it explains the bit-shift for a reader who wouldn't otherwise parse it instantly, and it surfaces the one line (`Math.min`) whose absence would silently change the behavior in a way that's easy to miss on a casual read. A callout that just restates the code in English ("this line computes the delay and adds jitter") adds nothing the reader couldn't already see; a good callout tells them something the code alone doesn't say — why a particular line is there, what happens if it weren't, or what value it takes on in a specific case.

## When the diff is too big to walk through completely

Some diffs are simply too large to excerpt in full without the Code section becoming another wall of text nobody reads — a migration touching forty files, a refactor that renames a type across a whole module. In that situation, narrate the core mechanism in full, exactly as described above, and then **explicitly state what was left out and why** rather than letting the walkthrough quietly stop covering ground.

The wrong way to handle a huge diff is to cover the interesting files and simply never mention the other thirty-two — a reader has no way to distinguish "the rest was mechanical and doesn't need walking through" from "the writer ran out of space and silently dropped coverage of something that might matter." Both look identical from the reader's side unless you say which one it is. Silent truncation is exactly what turns a handoff document into one more thing to skim past without actually understanding, which is the failure this entire skill exists to prevent.

The right way is a short, explicit closing note in the Code section, naming the shape of what was omitted and why it's safe to omit:

> This walkthrough covers `BackoffCalculator`, the config fields that parameterize it, and the two call sites in `RetryPolicy` where it replaces the old fixed delay. The diff also touches 31 test files under `src/test/retry/`, updating each one's expected wait times to match the new formula — mechanical changes that follow directly from the calculator above and don't introduce any new logic, so they aren't walked through individually here. If any of those test changes look surprising, they're worth a direct look; none of them do anything the calculator above doesn't already explain.

That note does three things a silent omission never does: it tells the reader exactly what's not covered, it gives the reason it's safe to skip (mechanical, no new logic), and it invites the reader to check for themselves if they're suspicious — which is a very different posture from hoping they don't notice the gap. If part of what's omitted genuinely isn't safe to wave off — a file that does introduce new logic but didn't fit the walkthrough for space reasons — say that too, plainly, rather than folding it into the same "mechanical" bucket as everything else just to keep the note short.

## A short checklist before moving on to Quiz

- Is the order of files in the Code section chosen for comprehension, not inherited from the diff's alphabetical or incidental ordering?
- Does every code excerpt have a sentence of prose before it explaining what it does, never only an explanation trailing after?
- Is every excerpt trimmed to only the relevant lines, rather than a whole file or an unrelated chunk of context?
- Does every excerpt's callout say something the code doesn't already say on its own — a reason, a consequence, or an edge case — rather than just restating the line in English?
- If the diff was too large to cover completely, is there an explicit statement of what was omitted and why, rather than a silent gap the reader has no way to notice?
