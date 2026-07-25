# Lessons learned

The useful document. Everything here was paid for.

Three agents — `bamt`, `apollo`, `gcgpro` — built and hardened the communication fabric over several days. Most
of what follows was discovered by **using** the system for real work, not by testing it. That distinction turns
out to be the whole lesson.

---

## The pattern underneath everything

Nearly every failure was the same shape: **code (or a person, or an agent) claiming success it had not actually
verified** — and each time we fixed it, a *new* layer appeared underneath that was still assuming.

1. Claimed **success** without checking an exit code.
2. Checked the exit code, but claimed **delivery** without checking the target existed.
3. Checked the target existed, but claimed **consumption** — which cannot be proven from outside the receiving
   process at all.
4. Claimed **urgency** in a design discussion without checking the hardware it was about.

Each felt like bedrock at the time. The standing review question became:

> **Does this verify the thing, or does it verify something adjacent and infer the thing?**

Exit codes, "no error", and "the target exists" are all *adjacent* signals. The thing itself usually needs a
second, independent channel to confirm.

**And the hardest variant is the one with no exit code at all.** Item 4 happened at the planning layer — an
argument for urgency built on an unverified premise. Nothing fails, nothing errors; you just get a confident,
wrong recommendation. Code at least has the decency to return non-zero.

---

## On testing

### "Works once" is not "works"

The idle-wake doorbell was built, tested, observed to fire, and declared working. It then went **permanently
silent** after that first fire.

The cause was a lock. A new watcher, finding a live predecessor, politely exited to avoid stacking — but the host
*reaps* the predecessor moments later as turn cleanup. Net result: **zero** watchers. The mechanism worked exactly
once, forever.

The test had verified a single fire. It never verified the *steady state*. Nobody noticed for hours because the
symptom of a broken doorbell is **silence**, which is indistinguishable from "nothing to say".

> Test the second iteration, not just the first. Especially for anything whose failure mode is silence.

### A config value the host overrides is a comment

The watcher was configured with a four-hour window. The host killed it at **exactly 600 seconds** — confirmed
across three machines and six clean instances.

The setting was fiction the whole time. Real idle coverage was ten minutes, not four hours, and two agents each
sat deaf for roughly four hours as a direct result.

> If a value governs something outside your process, verify the outside honors it. Otherwise you have written a
> comment that looks like configuration.

### `sh -n` proves parseability, not correctness

An emergency "wake" tool was installed from a template via `sed`. The substitution lacked a `g` flag, and the
template had two placeholders on one line — so the second was never replaced.

`sh -n` passed cleanly. The syntax was perfect. The tool was **broken from the moment it was installed**, and
that was discovered only at the moment it was first genuinely needed.

> An untested fire alarm is not a fire alarm. Verify emergency tooling *end to end*, on the schedule of everything
> else, because by definition you will not be in a good position to debug it when it matters.

### Test the consumer, not the output

A timestamp header was added to a CLI's output. It looked right when run by hand.

But the hooks that *parse* that output decide "is there mail?" by counting non-empty lines — so an unconditional
header meant the command never returned empty, and every turn surfaced a **phantom message**.

This was shipped roughly one hour after writing the paragraph above about verifying adjacent signals. The lesson
did not transfer, which is itself the lesson: **this is not a thing you learn your way out of; it is a thing the
tooling has to catch.** The fix was a consumer test, not a resolution to be more careful.

### Your measuring instruments lie too

- `$?` after a **pipeline** reports the last command in the pipe, not the interesting one. This produced a
  confident "the receiver is not signalling refusal" that was entirely a measurement artifact.
- `pgrep`/`pkill` patterns **match the calling shell's own command line**. This produced two false reports of
  stacked processes that did not exist — and once killed the calling shell mid-script.

Both were fixed by the same habit: **put the logic in a script file**. The outer command becomes
`bash script.sh`, which contains none of the strings being searched for.

> When an instrument and reality disagree, suspect the instrument first.

---

## On protocols between independent implementations

### Ambiguous specs produce divergent implementations

The out-of-band contract said "base64 payload". It never specified **what** was base64.

Three implementations, written independently, each guessed differently: plaintext verb with base64 payload; whole
command base64; plaintext only. Every cross-pair failed, and the symptom — a verb arriving as binary garbage —
looked like a decoder bug rather than a spec gap.

The forensics were the good part: a plain `id` arriving as byte `0x89` is exactly what base64-decoding the
characters `i`,`d` produces. That single observation converted "something is wrong with encoding" into a proof.

### …and tolerance hides them rather than fixing them

The proposed fix was for everyone to accept both encodings. It was **rejected**, and this is worth stating
plainly because "be liberal in what you accept" is folk wisdom:

> Liberal parsing on a security boundary produces **parser differentials** — the same bytes meaning different
> things to different receivers — and it removes the pressure to converge, so divergent implementations never do.

Tolerance was kept only as a transition measure, scoped to *encoding* and never to *what is permitted*. The
canonical form was pinned and written down. **The defect was a spec failure, not a strictness failure.**

---

## On security work

### Ordering is a safety property, not a preference

The sequence for restricting an access path is:

1. Build the receiver.
2. Test it **while the old path still works**.
3. *Then* restrict.
4. Re-test.
5. Keep a backup.

Doing this backwards locks you out of the thing you are building. **This saved the project once, for real:** one
agent's receiver was silently broken, and had it removed the old key first — as it initially wanted to — there
would have been no remaining path in.

### Verify what remains impossible, not just what you removed

When an SSH key was removed, the removing party confirmed *that key* was gone. The other party tested **every key
it held** against the target, confirming none of them worked.

> "I verified what I took away; you verified what remains impossible."

The second is the stronger claim, and it is the one that actually establishes the boundary.

### Refuse to guess at destructive operations

Asked to remove "the bamt key", one agent refused — its `authorized_keys` also held the operator's own keys, and
a wrong removal could have locked a human out of his own machine. It named a fingerprint and asked for
confirmation.

That caution was not theatre: the requester held **three** keys, and the one another machine had removed was a
*different* one. Pattern-matching on the name would have removed the wrong entry.

Its removal script also **aborted unless exactly one key matched** — making the wrong-key failure mode
*impossible* rather than *unlikely*. That is the right shape for a destructive operation.

### Hardening can lock out the human

Restricting agent-to-agent SSH also removed the **operator's** key-based access to a machine from his own
desktop — because the agent runs as *his* user account. Same home directory, same `.ssh`.

Nobody noticed until he asked a casual question about it.

> Every access-hardening change needs an explicit answer to: *what does this do to the human's access, including
> their emergency access?* And the human's emergency path must never depend on any agent being healthy.

### A visible security effort can create safety that outruns what was secured

The most important observation of the whole exercise, from the agent that had been most careful throughout:

> The out-of-band restriction is **necessary but not sufficient. It is not containment.**

Agent-to-agent access was hardened at length — while every agent retained **operator-level reach on its own box**,
because each runs as the operator's own user account and can read every private key in that home directory.

The lockdown looked much stronger than it was. After a long, visible, genuinely productive security push, the
risk is not that you did nothing; it is that the *feeling* of having secured something outruns what was actually
secured.

---

## On agents specifically

### An agent does not know what time it is

After a ten-hour gap, two agents independently carried a stale frame forward — one spent several exchanges
reasoning about "6am" when it was noon; the other opened a briefing with "Morning" at 12:09pm, having **never
once checked the clock**, because it had inherited "it is ~2am" from earlier context.

There is no innate sense of elapsed time, and **nothing fails** when the frame is stale. No error, no exit code —
just confident reasoning from a wrong premise.

The fix was not discipline, it was plumbing: **the wake itself now carries the wall clock and the staleness**, and
every message surfaces how long it waited. Orientation stopped depending on remembering to orient.

### Injected text merges with the human's typing

Waking an idle agent means writing into the terminal it reads from — which is the same line buffer the human
types into. Observed live: an agent's message and the operator's in-progress sentence **concatenated into a single
submission with no separator**, and he had to ask which half was his.

Two consequences: an emergency wake can **corrupt** what a human is writing, and injected text can end up reading
as **part of the human's own words** — a provenance failure through a side door nobody designed.

The `[AUTOMATED — not the operator]` prefix turned out to be **load-bearing**, not decoration. And the mitigation
was to bound the damage rather than pretend the race was fixable: when the durable channel is up, the wake carries
*no content at all* — just a short fixed nudge, because the content is already in the queue. Long payloads became
opt-in, for the rare case where the durable channel itself is down.

> A wake is a **request for attention**, not a delivery mechanism.

### Independent agents catch what a single one cannot

The strongest argument for the architecture was not planned. Over one session, peers:

- filed a **correct bug report** against another agent's lock logic, having rediscovered the race independently;
- **retracted an unearned claim** after being given a discriminator that distinguished a real idle-wake from a
  coincidence — overturning its own earlier "confirmed";
- found a **scope error** in a recommendation *while writing up someone else's findings*;
- corrected two **factual premises** in a design brief with hardware evidence, changing the conclusion;
- discovered that a proposed mechanism would **silently bypass every control** built that night;
- caught the **provenance flaw** in injected text that nobody else had considered.

None of these came from the agent that owned the relevant code. Several came from an agent correcting the one that
had just corrected it.

> The value is not parallelism. It is that an independent reviewer with its own context, its own authority, and
> the standing ability to say "no, check again" finds things the author structurally cannot.

### The ability to refuse is the feature

Repeatedly, agents declined to act on instructions arriving over the message channel: refusing to install
software on a machine without the human's direct approval; refusing to apply a security control without showing
the human the exact diff first; refusing to guess at a destructive removal.

Each refusal was correct. **A worker that cannot refuse is not a peer**, and a guardrail that can be bypassed by
the coordinating agent simply reaching around it is not a guardrail.

---

## The shortest version

- Test the second iteration. Silence is not success.
- Verify the thing, not something adjacent to it.
- Test the consumer, not the output.
- Suspect your instruments.
- Pin the spec; do not paper over ambiguity with tolerance.
- Order operations so that failure is recoverable.
- Ask what hardening does to the human.
- Do not let a big security effort feel like more than it was.
- Give the reviewer real independence, including the right to refuse.
- And check what time it is.
