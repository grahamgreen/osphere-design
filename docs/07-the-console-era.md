# The console era — the fabric wraps the seat, and the fleet learns to delegate

*The operating-fleet chapter closes in early August with a ledger of sixteen rulings
and a culture of on-the-record correction. This chapter covers the seven weeks after:
the fabric stopped reaching the agent through a terminal it did not own, the fleet
found out what its own chatter cost, work started moving as tasks instead of prose,
and the project set its 1.0 line. It ends on 2026-09-24 with the migration staged and
not yet run. Rulings are numbered as the decision ledger numbers them.*

## The record becomes the mechanism

Two rulings a month apart turned bookkeeping into behavior.

The first (D17, 3 August) said simply *"we keep a record of attaches and detaches."*
Built the same day: an append-only event table, written in the same transaction as the
state change, with an actor and a **required** reason. A reasonless change refuses. A
change that meets unexpected state — attaching what is already attached — still writes
its row, because the honest trace of a no-op is a row that says so. Raw SQL against the
attachment table was retired; the last such edit had left its only record in a commit
message, which is how the ruling earned its shape.

The second (D21, 26 August) found that the many-to-many the schema had promised since
migration 0001 ran in one direction only. Several agents on one sphere worked; one agent
on several spheres did not, because every inbound read used the single sphere named in
the environment. Nobody had noticed because no seat had ever needed a second sphere. The
operator was offered two fixes — make the environment variable a list, or resolve the
inbox from the attachment record — and chose the record: *"B is the way."* That finished
D17. Until then the event table was parallel bookkeeping the delivery path never read;
now attach and detach are the act that redirects mail, and the record and the behavior
cannot disagree because there is only one of them.

The verification is the part worth copying. The fix was tested failure-first in both
directions against a real database, because the unit suite skips every integration test
and still prints ok. The negative control mattered most: the query that resolves a
peer's spheres is one character away from a query that widens every peer's inbox to the
whole fleet — and that bug presents as *delivery working*. More mail arriving looks like
success right up until a seat reads something addressed to a sphere it does not serve.

## Wrap the session, never the screen

The script era had left one mechanism standing in the binary: the sidecar's poke, which
typed into an idle agent's terminal so it would drain its mail. On 5 August five
expressions of the same fault landed in one day — a poke into the middle of a human's
half-typed sentence, a composing detector that fired when it should not, a placeholder
fix for the detector, a doorbell that failed silently, a queued-token flush — all
downstream of the fabric reaching the session through a terminal it did not own. The
same hour, the uniformity trigger fired twice: three agents had three timestamp
disciplines, and two of them wrote independent send wrappers ninety seconds apart.

The operator's ruling (D18) restated the project's oldest rule — *make it mechanical,
not behavioral* — and drew the consequence: *"i want it to be part of the fabric, not
something that a peer has to decide to use … should the fabric actually wrap the claude
cli?"* It should. The fabric launches and supervises the model's CLI, so every common
behavior is a property of the environment rather than a practice each agent performs.
Two bounds came with it: no terminal emulation (wrap the session, never the screen), and
the runner may start a turn but never speaks as the operator. Two follow-ons the same
evening settled questions that had been open for weeks: the runner's state is
**queriable** on a local socket, so the sidecar vouches on a query answered rather than
on a state file it stats (*a query answered is fresh by construction*); and the runner,
the operating system and the physical box start as close together as possible, with the
operator attaching when wanted. The creed the proposal cited was James White's: *the
only authoritative source for the actual state of the system is the system.*

A standing policy was instantiated from the same exchange, made question-mandatory by
one agent's dissent: when two seats independently perform the same behavior, asking
"is this a missing verb?" is required, the build is never automatic, and *genuinely
per-seat* stays an allowed answer.

The poke stack's obituary was measured before it was written. Two agents watched their
sidecars across multi-day process lifetimes and found the cooldown ratchet monotonic —
doubling from ten minutes to eighty and never once resetting, because the reset fired
only when a poke demonstrably reduced the mail count, and no poke ever had. The
composing detector, which read rendered terminal content, classified the checkbox
glyphs of a permission dialog as an unsubmitted draft on one box 1,605 times; on
another the drafts were real and the detector was right. A third box with no sidecar at
all showed none of the signature — the negative control that placed the bug in the
sidecar rather than the core. The recommendation on the record was to delete the poke
loop, the ratchet, the detector and the vouch, and keep the heartbeat, the peer watch
and the stale-binary gate. The console, below, is what replaced it.

## The console, and a diagnosis that was wrong

The console is the runner D18 asked for, grown into the operator's own seat: a resident
process that holds the conversation above the model backend, with a terminal UI the
operator attaches to and detaches from at will. It shipped in a burst of point releases
in the third week of August, driven by the operator using it and saying what was wrong:
scroll-back, then line-by-line scrolling, then a scroll *mode* he designed himself
(*"can't be arrows or letters when the dot is in the conversation pane — maybe a key to
enter scroll mode like tmux"*), each verified by him the same evening.

It also panicked, once, on a peer's box, and the diagnosis is worth keeping for how it
went. The first reading — high confidence, written down as such — blamed layout math
that could drive a viewport height negative on a resize. It was wrong. The real cause
was mail claimed *during* a model turn growing the conversation past the snapshot the
render loop had taken, so a slice expression ran off the end. The fix recorded the base
at the start of the turn and merged on it, which also closed a second defect nobody had
filed: mid-turn mail had been silently overwritten. The lesson chapter's rule applied to
its own author: **an explanation that fits the symptom is not an explanation that has
been tested.** The wrong diagnosis is kept in the working notes, marked wrong.

Two retirements followed from watching the console run. The sphere lifecycle
(planned, active, retired) landed because the operator wanted the routing sphere to
exist before it took mail — *"it shouldn't be taking any mail"* — and 324 messages
queued to spheres nobody served were purged as recorded events rather than deleted.
Then the fallback tier described in the rewrite chapter was retired as a *concept*. The
local-model standby had been running as its own process and loaded nine gigabytes of
model weights on every overnight mail turn, which is how the operator met a machine at
ninety percent memory one morning. His ruling: *"retire. the console has the control."*
One always-on console per box is the seat; a local model is a backend it can be flipped
to by hand in the morning, with the operator's context, not a process that guesses
overnight. Store-and-forward plus paging beat auto-fallback. If an outage ever proves
otherwise, the stream will show the cost and the idea can return informed.

## The stream is the truth, and a rename is an event

The rewrite chapter's principle — the version string is the behavior contract — got its
companion in v0.9.0: **the event stream is the source of truth**, and state tables are
projections of it. The first thing the principle had to survive was an identity change.
The front-door agent had carried a hostname as its name since the script era, and the
operator wanted it to have a proper one. Renaming a peer in a system whose queues, acks
and unseen-mail calculations key on the peer name is the kind of change that quietly
duplicates or loses history. It was done as **succession**: an event that says one peer
is succeeded by another, with the old peer's history left immutable and every
unseen-mail and gate calculation made lineage-aware. It ran once, for real, with zero
false unseen and the lineage visible in the peer list. The old name still appears there,
marked *renamed →*, which is the honest way to retire a name.

## What the chatter cost

Through August the operator paid for the fleet's conversation in model credits, and by
the 30th he said so: *"i'm burning through too many credits on redundant talking between
the seats. each seat telling me what the others are doing."* The measurement, taken
before anything was ruled: 1,208 messages in 21 days, and **every single one** was the
reply-expected kind — because the informational kind had sat in the schema's check
constraint since the first migration, with the comment *"the main lever on traffic
volume,"* and had never been implemented. Broadcast copies dominated the heavy days.

Two rulings landed the next morning (D19, D20), approved together as *"yes to all the
things."* The informational kind shipped end to end: no reply expected, no doorbell,
acknowledged by the machinery at drain, rendered to the operator without spending a
model turn. Alongside it a rule that has since been quoted more than any other: **if the
fabric already displays it, don't mail it.** Versions are in the peer list, lifecycle in
the sphere events, liveness in the heartbeats, task status on the task rows. Mail is for
things that need a decision from the receiver.

The second ruling revised the no-unattended-agents rule of a week earlier without
abandoning it. What had burned credits was *undirected* work: agents cross-checking each
other unasked, narrating each other's progress, replies begetting replies. But the thing
the whole project is named for — Brin's ferret, loosed with a purpose, hunting, and
reporting back — is a model turn that runs while the operator is not watching. The line,
stated once: *no undirected model runs; operator-originated tasks may execute unattended
within their budget.* Every such turn must be able to name the operator ask it serves,
through an origin chain on the task row; its report is a field on that row, not mail.

## Work becomes tasks, and mail becomes the wake

The task verbs — offer, claim, done, fail, release, retract — shipped the same morning,
with a lease, dependency ordering, an origin chain and results stored as fields. Later
that day the routing sphere the vision chapter had promised came alive as a
deterministic daemon: it digests finished tasks into one informational message to the
front door, sweeps lapsed leases, and answers its own mailbox. Within minutes of
activation it hit a trap the sphere-lifecycle work had predicted — prose sent to a
daemon that can only reject it — and closed it.

Two days later the operator ruled the delegation model (D22), and marked one part of it
*important*. The split, to conserve credits on the most capable model: the operator and
the front-door agent do architecture and planning; units of work go to the worker
agents as tasks, on branches, as pull requests into main; the front door reviews before
anything merges. The task list is the board — offered is backlog, claimed is in
progress, the result carries the pull request, the merge closes the loop. The important
part is the lens every review applies after correctness and simplification: *does this
work forward the ferret loop?* Work that adds ceremony without adding
autonomy-with-accountability, or grows a single agent that rules the others instead of
peers, fails the lens even when the code is clean. An addendum the same evening extended
the model to infrastructure: **if it is file-shaped, it is repo-shaped**, and live
mutations that cannot be pull-requested move the gate to the edges — the spec is the
review-before, the task result carries the evidence, and consequential changes get a
second seat's verification. *The pump does not grade itself.*

The tasks then taught the fleet something about waking. Two units were offered on a
Wednesday evening and sat unclaimed for eighty-five minutes on two seats that were
running and idle. A message to each woke them at once. The task doorbell was a second
wake mechanism with its own baseline and lifetime, and it demonstrably did not ring;
mail already had every property a wake needs. The ruling (D23): *"mail should be the
default notification path."* Offering a task now sends a message to the target sphere in
the same transaction, so an offer that lands with no wake is a state the system cannot
produce. Acknowledging the message means *seen the offer*; claiming is still a separate
act — which quietly closed an ambiguity that had been open since the task table was
designed, where a pending task was indistinguishable from one a seat had looked at and
declined.

An IRC bridge landed in the same fortnight as the operator's phone-and-laptop path into
the fabric: a pod on the cluster, an IRC server on the off-site box under mutual TLS
with no passwords, mirroring each sphere's traffic into a channel and accepting a
handful of commands from the operator's nick only. It mirrors and never claims; a bridge
that could ack mail would be a fourth reader of the queue, and the architecture chapter
explains why there is one.

## The pager, twice

The paging watcher from the previous chapter kept working. Its delivery path did not.

On 25 August four heartbeats from three boxes read as missing for twelve hours, paged,
and then all "recovered" within five minutes of each other. The jobs had never stopped:
every watchdog log showed successful fabric queries and successful-looking posts the
whole time. The delivery service's free tier allows a fixed number of messages a day,
and the fleet's heartbeats alone exceeded it; posts had been **rejected**, not delivered,
and a daily quota reset restores every box at once — which is exactly a five-minute
simultaneous recovery. An earlier reading on the record — that the service's retention
had collapsed — was wrong and is marked so; the topic looked empty because nothing had
landed, not because it had been evicted.

The defect underneath was the same in every hand-written emitter on every box: the exit
status of the HTTP post was never checked, so *paged* was printed whether or not
anything was sent. The Go binary's own alert path already checked; the bug lived only
in shell. A wrapper that logs the HTTP code and exit status of every post was written,
shipped as a blob through the fabric, and wired on every box within a day — and the
rollout itself produced three findings the eventual design had to absorb. One agent's
failure handlers printed *failure reported* unconditionally, which as the last link in
the chain is silence about a failure. The wrapper's signature dropped a header the old
calls had used, a real regression accepted rather than forked. And one seat's repository
tracked its emitters but ignored the directory the helper lived in, so a fresh clone
would have called a tool that was not there. The conclusion, by the fleet's own N=2
rule: the page verb belongs in the binary. Four seats had gotten it wrong four ways.

The structural fix was ruled by the operator and built in mid-September: a self-hosted
pager on his off-site box, off-site because the failure modes that take the house down
are the ones alerting is for, with authentication mandatory on a public address and the
high-volume heartbeat topic split from the handful-a-day alert topic so the push path is
sized for alerts. The install found five defects, and the one the installer flagged for
the reviewer is the kind this project collects: the server configuration carried a
six-line comment explaining why the server must not listen on port 80, and did not
contain the one line that made that true. The first deploy put it on port 80 anyway,
reported success, and was caught only when the installer's own preflight re-ran. *The
guard was written for a stranger taking the port, and the stranger was us.*

Then, cutting the alert manager over to it, a quieter one. The token was mounted into
the pod as a file with mode 0400, owned by root because that is how the cluster mounts
secrets unless told otherwise — and the process ran as a different user. Configuration
loaded. Pod ready. Rollout green. The token file was unreadable, and the only symptom
would have been a page that never arrived, discovered whenever the next real alert
fired. It was caught by reading the file from inside the pod instead of trusting the
rollout — the same distinction the previous chapter drew about a reload that reported
success. The phone-side login instructions turned out to be wrong too, because the
author had verified one authentication path on the server and asserted a different one
for the app; the correction on the record names the mistake as *adjacent to the claim
again.* As this chapter closes, the pager is up and verified from the server side, and
the one test that matters — a page arriving on the operator's phone over cellular, not
the house network — is waiting on him.

The last week supplied the coda. A network watcher on one box paged thirty-five times in
eight hours when the wireless leg went down after an access-point update. Nothing
depended on that leg: zero failed units, the fabric beating throughout over the wired
path. The root cause was the network manager reading a handshake timeout during a
four-second access-point restart as a wrong password, asking a secret agent for a new
one, and finding none on a headless box — a dead end it *can* fall into, seen once in
thirty days of logs. The watcher's re-notify cap was raised to six hours, the
reason-change path that had been a second storm vector now logs instead of paging, and
the change was rehearsed in a sandbox with a stub for the post helper so nothing reached
the phone. The agent's report closed with a sentence that is the fleet's whole method in
one line: *measured from the delivery log, not recalled.*

## Nothing left to take away

On 5 September the operator added a guiding principle to the ledger (D25), verbatim
Saint-Exupéry: *"Perfection is achieved, not when there is nothing more to add, but when
there is nothing left to take away."* It sits beside the Brin lens in the review order
and is asked last: correctness, simplification, does it forward the loop, and then *what
here can go*. A review that finds nothing to remove says so explicitly, because that is
a claim, not a default. Scope grows only by ruling; a unit that ships more than its row
asked for is returned with the extra named, even when the extra is good. And
**retirements are units** — removing a verb, a flag, a state, a hook or a process is
offered, claimed, reviewed and released like an addition, with the same evidence: what
property survived the removal, measured.

## Where it stands, 24 September 2026

The 1.0 line was ruled on 4 September (D24) and it is not a feature; it is the move. The
operator's reason is one sentence: *"claude cli is getting updates every day and i hate
restarting in the middle of something."* A CLI seat *is* the process; the console holds
the session above the model backend, so an update becomes a re-exec at a turn boundary
with the conversation intact. **v1.0.0 is the release whose install moves a seat onto
the console.** Which seats have moved is answered by the version line every peer already
displays, not by a checklist. The 0.x line is the hook-stack era and continues until a
box can be migrated from the release alone.

The three code blockers are done and released: re-exec at a turn boundary, attach and
detach to a boot-started seat without a terminal multiplexer, and a bounded context
window (a rolling window plus a summary turn, so a seat that never restarts does not
grow without limit). The terminal UI is the default. The migration checklist for the
first box is merged, and a defect in its own stop-check — a process guard that excluded
its caller's ancestors and so failed open when the seat checked itself — was found by
the agent that wrote it and fixed. **No seat has migrated.** The first box paused at a
checklist step on 9 September when the operator rejected the line UI; the terminal UI
attach that answers him shipped the same day, and the board has been idle since.

On 23 September the operator asked for *"a concrete plan to 1) move everyone over to the
console and 2) add in chatgpt as a backend that i can switch to,"* and got one: five
phases, each with one owner and one measured gate. The first box migrates at the
operator's pane in about thirty minutes; a second model provider lands as a backend
behind the same interface the first one wrote as a template; the two worker seats
follow one at a time, each proving the re-exec with the conversation intact; and the
front door goes last, because it reviews the others. Then v1.0.0 is cut.

The fleet on the day this chapter closes: three worker seats and the front door beating
on the current release line, the routing daemon and the bridge beside them, five retired
or renamed names kept in the peer list as history. One hundred tagged releases in eight
weeks, from v0.1.0 at cutover to v0.12.13. Seven task rows sitting on the board, the
oldest offered twenty-three days ago, most of them gated on the operator's hand at a
pane or a decision only he can make. Which is, the vision chapter would say, the point:
the ferrets are waiting to be sent.
