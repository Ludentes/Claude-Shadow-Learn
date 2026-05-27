# Long-Horizon Research Discipline

Patterns for any thread that runs longer than a single Claude session — investigations, ML experiments, debugging campaigns, vendor evaluations, anything where the answer takes weeks and the human's edge over a fresh session is that they wrote things down.

If a session is short enough to fit in one context window, you don't need these rules. They become load-bearing when the conversation has to survive compaction or a human turnover.

## The Three-Layer Document Model

Separate raw evidence from interpretation from index. Each layer rots at a different rate, so mixing them creates either constant churn on stable docs or stale claims in the live index.

- **Dated evidence** (`docs/research/YYYY-MM-DD-<topic>.md`) — append-only. Each doc is a writeup of one spike, experiment, paper review, or session. Never edited substantively after it's settled — only superseded. The date encodes "this was what we believed on that day."
- **Topic indexes** (`docs/research/_topics/<topic>.md`) — mutable interpretation. One per thread. Says "here is what we currently believe and here is the chain of dated docs that got us there." Read-first on any fresh session.
- **MEMORY.md** — one-line pointers with a status icon and a slug. Triage tool, not knowledge store. Links out to a topic file or a dated doc. Don't summarize content into MEMORY.md; keep entries to one line.

## Frontmatter Trust Signals

Every research/blog doc carries enough metadata that a fresh session can tell whether to trust it:

```yaml
---
status: live | superseded | archived
topic: <topic-file-slug>
last_verified: YYYY-MM-DD       # human signature on "still true"
supersedes: <doc-name>          # optional
superseded_by: <doc-name>       # optional
---
```

For architecture docs that mirror code, also include `verified_against` (repo + commit + paths) so drift between doc and code is detectable.

For docs about open work, include `freshness` listing pending MRs/branches that might invalidate the doc soon.

## Append-Only Discipline

- Never overwrite a dated doc to fix its conclusion. A superseded conclusion gets a new dated doc plus `supersedes:` / `superseded_by:` pointers.
- The old doc stays in place. The audit trail is what lets future-you answer "why did we believe X in March?" without re-running the experiment.
- Editing wording or fixing typos in a settled doc is fine. Editing the conclusion is not.

## Falsification as a First-Class Outcome

When a hypothesis dies, that is a load-bearing finding, not a tidy-up target.

- Write a dated doc that says explicitly *why*, with the data that killed it.
- Add a `🛑 FALSIFIED` entry to MEMORY.md naming the doc and pointing at the replacement approach.
- Never delete the falsified doc. It prevents the next session from re-exploring the same dead end in three weeks.
- A topic file may pivot; falsified branches stay searchable in one hop from MEMORY.md.

## MEMORY.md Status Icons

Triage at a glance. Each entry is one line: icon + slug + one-sentence hook + link.

- `🧭` ACTIVE THREAD — currently working
- `🛑` FALSIFIED — explored, ruled out, do not re-propose
- `🚢` SHIPPED — landed in production, runbook exists
- `📚` RESEARCH — completed investigation, conclusions live in topic file
- `🆕` RULE — new project rule, applies going forward

The icon signals load-bearing-ness without reading the entry. Pick one icon per entry; if two could apply, the more recent state wins.

## Read-Order on a Fresh Session

When a new session opens on a thread, read in this order:

1. `MEMORY.md` — scan for the thread's status icon and slug
2. The linked topic file — current beliefs
3. The most recent dated doc(s) referenced by the topic file — load-bearing detail
4. The runbook, if a shipped artifact is involved
5. `git log --oneline -20` on the relevant subtree — catches anything since the topic file was last touched
6. **Only then read code**

Reading code before the topic file is how you re-propose approaches that were ruled out months ago. The cost of skipping the read-order is paid by the next session, not this one.

## Compaction-Safe Writing

The rule that makes the rest viable: **information that is not on disk does not exist.**

- Save findings the moment they are produced, not "when the session is done." By session-end the load-bearing detail may already be gone from your context, never mind the next session's.
- Long-running experiments write intermediates that fully reconstruct decision-relevant state: configs at the top of every result dir, eval logs tied to a specific holdout fingerprint, parquet tables per run.
- Generation is resumable. Skip-if-exists per output file. If a plan needs to change mid-run, append new cells and relaunch — don't kill the run to amend.

The test of a good intermediate: can the next session, with no memory of this one, pick up the thread by reading the dir? If not, the dir is incomplete.

## Verification Discipline

- Never quote a baseline from its own log. Re-eval on the current holdout. Numbers age faster than docs.
- Before quoting a metric from a dated doc, check `last_verified` against the current holdout/config fingerprint. If the fingerprint changed, the number is stale — re-evaluate or qualify the citation.
- A metric is only as good as the question it can distinguish. Symmetries in evaluation hide failure modes that downstream loss cannot recover.
- "Tests pass" without showing the green output is not evidence; it is a wish.

## Two-Strikes Refactoring

Don't backfill frontmatter, runbooks, or memory entries mechanically across the corpus.

- When a doc is substantively touched without frontmatter, add it then — the doc has earned the attention.
- Lazy/just-in-time. Each artifact earns the work when it's next touched.

## Feedback: Save the Why AND the Confirmation

Every correction memory carries three lines:

```
Rule: <the rule>
Why: <the prior incident or strong preference>
How to apply: <where this kicks in>
```

The *why* is what lets future-you judge edge cases. A rule without its reason becomes either cargo-culted blindly or rationalized away the moment it's inconvenient.

Save **confirmations** too, not just corrections. If validated approaches are only ever implicit, the agent drifts toward timidity. "Yes, the single bundled PR was right" calibrates equally important judgment.

## What Not to Do

- Don't summarize a dated doc into MEMORY.md — one-line pointer only.
- Don't delete falsified docs — they prevent re-exploration.
- Don't quote a recalled function/flag/file name without re-checking it exists now.
- Don't propose approaches without reading the topic file first.
- Don't keep destructive shortcuts as the default (`--no-verify`, `git reset --hard`, "just delete it and start over") — every one of these has burned in-progress work somewhere in a memory file.
