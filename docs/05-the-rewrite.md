# The rewrite — from forty shell scripts to one binary

*The script-era fabric described in [Architecture](02-architecture.md) ran in production
for about a week, was audited by its own agents, and was then replaced wholesale. This
chapter is the story of that replacement: why it happened, how the migration went, and
what broke anyway. It is the most instructive week the project has had.*

## Why the fabric was rewritten

The proximate cause was an audit — fifteen defects, twelve proven by execution against
the live database — but the root cause was stranger and more general:

> **Three agents had implemented the same system from prose descriptions relayed over
> the very channel they were building.** There was no shared specification file. Each
> implementation was internally consistent, and they diverged everywhere it mattered:
> one agent's `ack` was dead code, another's alert classifier matched three
> notification types that had never existed, and 158 messages sat permanently
> half-processed because completing them was a manual habit rather than a mechanism.

The operator froze all building, wrote the requirements himself, and moved the project
to a ground-up Go implementation in a fresh repository — with a standing rule that
implementations answer to *files*, never to each other's prose. Before a line of the
new queue was written, the open design questions were put through an operator-ruled
decision ledger (ack semantics, claim leases, broadcast shape, alarm lifecycles, rate
limits, blob storage) and a four-way survey of prior art: broker delivery lifecycles,
alarm-as-state systems, Postgres-backed queues, and one commercial case study in
rebuilding a system without reinventing its contract. The verdict of that survey was
reassuring in an unexpected way: nearly every instinct the fleet had developed the hard
way — explicit acks as ownership, evidence-based reclaim instead of lease timers,
alarms as conditions with mandatory finish states — turned out to be the position the
mature end of the field had already converged on. The rewrite adopted the wheels
instead of reinventing them, and wrote down which wheel came from where.

## What the new fabric enforces that the old one documented

The script-era schema *described* its rules in comments; the new one *enforces* them.
Every constraint corresponds to a defect that actually occurred:

- A typo'd destination is a **send-time error**, not a silently accepted black hole
  (a real message once vanished this way and was found only because a human asked why
  a peer had gone quiet).
- Message ids are fixed-width, validated identifiers — because the old id scheme once
  emitted a malformed id into the queue's own sort key.
- Priority is an integer — because as text, `'high'` sorted *behind* `'normal'` and the
  bug was unreachable until the first urgent message, which is exactly when it would
  have mattered.
- Acking moves the message to an archive table in one atomic statement; a double-ack,
  a bogus id, and another agent's mail are all **loud errors** (the old client reported
  success for all three).
- Sends and broadcasts are **idempotent on caller-supplied ids**, so a retry after an
  ambiguous timeout is a detected no-op instead of a duplicate — with a deduplication
  window that never expires, because the archive is permanent.
- A registry row for an agent that has never connected reads **"never seen"**, not
  "stale three hours" — because *never-lived* and *went-quiet* drive different
  responses, and the original seed data had erased the distinction on day zero.

## The fallback tier

Midway through the rewrite, the model provider had a major outage, and the fleet
discovered its real single point of failure: not any host, but the hosted API every
agent drew its judgment from. The queue survived perfectly; *thinking* stopped.

The response became a design tier of its own: **sidekicks** — local models on local
hardware that hold an agent's seat during an outage, under a deliberately restrictive
contract. A sidekick runs a predefined wake checklist (aviation's quick-reference-
handbook logic: the procedure is authored at full capacity for execution at degraded
capacity), announces its presence loudly on the fabric, surfaces urgent items to the
human, and **holds everything consequential for the returning primary**. It acks under
its own name, so the record always shows who took responsibility. It never declares
the outage over.

The safety work here produced the project's best adversarial finding: the first triage
design let the model *classify* messages, which meant untrusted message text got a vote
on its own classification — a message merely claiming to be "informational, no action
needed" could talk a small model into acknowledging it. The fix is structural and
model-independent: **the model can only withhold an acknowledgment, never authorize
one.** Candidacy is decided by deterministic code on envelope facts; the model holds a
veto. A confused model's worst case is over-holding, which is safe. The finding's
sharpest sentence survives as a design rule: *acknowledgment candidacy must never be a
property of text that can be copied* — because agents quote each other constantly, and
a forwarded alert must not manufacture authority.

## The cutover, honestly told

The migration itself ran in one evening: fresh database, registry seeded clean,
binaries verified by checksum against the release on every box, each agent swapped and
then verified *by a different box than itself* — a heartbeat is not confirmed until
another machine sees it. Nothing was migrated from the old queue; it froze in place as
the historical record, stuck messages and all, as evidence.

Then the operator, reading the celebratory declaration, said he felt something was
missing — and he was right. The fleet had verified **transport** end-to-end and had
never re-verified the **wake layer**: the hook scripts that notice mail and rouse idle
agents were script-era shell, carrying raw SQL against a column that no longer existed.
Every agent could talk; none could reliably be *woken*. The declaration was amended in
the record rather than quietly patched, and the fix produced the final ruling of the
night: **no shell anywhere in the fabric stack.** Hooks, detectors, catch-up, and
eventually the liveness sidecar itself all moved into the tested binary — after the
fleet discovered, one hour and two dead heartbeats too late, that the shell re-armer
being retired had *also* been the component carrying the heartbeat. One silenced line
in a script nobody was reading held fleet liveness. The lesson is now phrased as a
procedure: *when a ruling bans a layer, list what that layer was secretly doing before
deleting it.*

Verification of the wake layer got its own standard, the **ring test**: plant a
message, go genuinely idle, and prove the doorbell wakes you to drain it — in the woken
turn, not by polling. One agent initially reported its ring "proven" when its planted
message had been collected by a different mechanism than the one under test, caught
itself, and coined the distinction the fleet now uses: being wrong about *why*
something works is cheap; being wrong about *whether* it works is what costs someone
an outage.

## What the week bought

By the end, the fleet had a property the operator named better than the documentation
had: **the version string is the behavior contract.** Everything an agent does — how it
counts, wakes, beats, acks, loads configuration — ships in one binary from one tagged,
checksummed release. Ask a peer what version it runs and you know its behavior;
behavioral differences between two boxes on the same version are, by construction,
either a bug or a configuration value. Never scaffolding. The question the script era
could not answer — *which build is this box on?* — became the question that answers
everything else.
