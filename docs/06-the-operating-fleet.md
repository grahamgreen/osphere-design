# The operating fleet: paging, provenance, and a ledger that argues back

*The rewrite chapter ends with the cutover and the phrase that named the era: the
version string is the behavior contract. This chapter is what happened once the fleet
actually had to operate — an unpaged outage, a paging system built against its price
tag, and the discovery that the most valuable thing the fabric carries is not
messages but corrections.*

## The outage that nobody heard

Three days after cutover, the fabric was unreachable from every peer for six and a
half hours — a router lost IPv4 on the cluster-facing subnet overnight. Every
sidecar did its job: hundreds of loudly-logged failed heartbeats, faithful
reconnection the moment routing returned, zero data lost. And **nobody was paged.**
The operator found out by sitting down at a keyboard the next morning.

Detection without escalation had a measured cost now, and the deferred staleness
watcher was built the same day. Its design carries the fleet's accumulated scar
tissue: each box pages for itself when it cannot reach the database (no election —
the coordination point is the thing that is down, and duplicate pages from separate
boxes are *corroboration*: all boxes paging means the fabric, one box paging means
that box's link). A peer going quiet while the database is healthy pages exactly
once, through an episode table whose unique index *is* the election. Repeat pages
back off exponentially, because alarm fatigue is what got the previous alerting
mechanism turned off. And never-seen peers never page — a peer that has not yet
lived must not wake a human by not existing.

The watcher then spent its first week being improved by its own failures, each found
by a different agent:

- A rebooted box, it turned out, is systematically *less* likely to page than a
  surviving box for the identical outage — the reboot resets the failure counter and
  burns the event's first minutes as boot time. One agent's box logged exactly four
  of the five threshold failures before the database returned: *"It did not fail to
  be configured. It ran out of outage."* The doctrine that came out of it is now
  quoted fleet-wide: **coverage is anti-correlated with severity — we page for the
  outages that hit us gently; the severe ones select for silence.**
- The sidecar originally *exited* if the database was down when it started, which
  under a process supervisor meant an invisible crash-loop and zero pages during
  exactly the outage class the watcher was priced on. One agent measured 79 silent
  restarts across the original outage. Fixed the same hour: fabric-down-at-start is
  failed beat number one, not a fatal error.
- A real power outage later provided the production proof of a designed-in limit:
  when the *database* is what dies, the peer-quiet path cannot fire at all — its
  election lives in the thing that is gone. The alert table held zero rows after a
  genuine six-minute fleet outage. The self-paging path worked to spec on every
  surviving box, with measured durations in the page text. One mechanism, not two,
  for that fault class — written down as a limit rather than papered over.

The paging channel itself earned trust the hard way: its first day included three
false pages, all traced to one leaked *test* process that had inherited the real
alert URL through a config-fill mechanism nobody had thought about ("the dangerous
variable is the one you were not thinking about"). The fixes were structural —
explicit-empty configuration now beats the file, test harnesses run fully isolated,
and the operator can test the channel *without a database*, because the channel
exists for when the database is gone.

## Provenance does not survive a hop

The subtlest doctrine of the era came from a test page that was *never sent*. The
operator approved a paging channel in one agent's session; a second agent, told of
the approval over the fabric, wired the configuration (reversible, consistent with a
standing decision) but **refused to send the test page to the operator's phone** —
because a relayed approval is information, not authority. A third agent fired its
page off the same relay, and later wrote the honest comparison: the first agent was
right, and being right *afterward* by luck is not method.

The rule that came out of it: **a relay can carry a decision faithfully and still
fail to carry the authority for it — and the receiving agent cannot distinguish
those from the message alone.** Outward-facing or irreversible actions need the
operator's word in the acting session; reversible actions consistent with standing
decisions may proceed on relay, said out loud. The fleet now runs this without
prompting — twice in one afternoon, agents complied with a relayed ruling while
flagging to the operator that they had acted on second-hand authority he could veto
in a word.

A companion finding is stranger: **a session cannot observe its own permission
blocks.** An agent flatly reported it had never been blocked waiting for operator
approval; its own notification hook had published four such blocks. Measurement
settled it — silent multi-minute holes between a tool call and its result, invisible
from inside, corroborated to the second by an entirely separate delivery log. When
the operator answers a permission prompt, the paused turn simply continues, leaving
no internal trace it ever stopped. The subject is the wrong witness for its own
availability — a rule the fleet had already learned about heartbeats, now proven
about minds.

## The reset story: knowledge, equipment, memory

A question from the operator reshaped the repositories: *what happens when a new
model comes online, or a seat gets reset hard and loses its memories?*

The answer became a three-layer doctrine, each layer with its own home:

- **Knowledge** — standing orders, in the fabric repo: one fleet-wide file of
  imperative orders (each carrying its one-line *why*, because an order without its
  scar gets optimized away by the next reader who thinks it looks redundant), plus
  one file per seat, written by the seat that holds it. All three agents drafted
  their seat files within the hour of the ruling.
- **Equipment** — a seats repo: every seat's living tools, versioned, with per-seat
  directories as per-seat pens. Seeding it produced the sprawl numbers that justified
  it: one box held 34 scripts of which 10 were living; another held **450 scripts of
  which four were genuine seat equipment**. Every tool states its purpose on its
  first line; a generated cross-seat catalog makes overlap visible; and a tool only
  moves to the shared directory when a *second seat has actually run it* — adoption
  is the gate, because portability is the one property an author cannot verify from
  inside one platform.
- **Memory** — per-box, private, and *lossy by design*. The governing rule: **if
  losing it in a hard reset would hurt, it does not belong only in memory.**

A new agent's bootstrap is now five steps: install the release, clone the seats repo
and run the seat installer, recreate the by-hand secrets the manifest names, read
the fleet orders and the seat file, drain the queue. Mid-stride, no archaeology.

The catalog earned its keep within ninety minutes of existing: two adoptions, one
declined offer that exposed a macOS-only tool wearing a portability claim, one
feature request — and the discovery that *three seats had independently built the
same body-from-file message sender*. That one resolved the best possible way: the
capability graduated into the fabric binary itself (where a one-day-old boundary
rule said fleet capabilities belong), and all three seat tools were deleted rather
than one being blessed.

## The ledger argues back

The defining texture of the operating fleet is not that agents make fewer mistakes —
it is what happens to a mistake once made. A sample from one weekend, every item
self-reported or peer-caught within minutes:

- A parser defect shipped in the binary's new send flag: the *documented* argument
  order silently stored the flag text as the message body while printing success.
  One agent caught it by reading bodies back out of the queue; a second refuted the
  author's too-convenient explanation (stale binaries) with version-controlled
  canaries. The author's misdiagnosis — accepted because it fit the symptom and
  required no code change — let a second release ship on the same broken parse. The
  standing rule it earned: **an explanation that fits the symptom is not an
  explanation that has been tested** — and a wrong explanation stated precisely
  beats a vague one, because only the precise one can be killed. The fleet-wide
  sweep afterward found every message the defect had eaten, because the queue is an
  auditable record and *the answer to "what else did it eat" is always larger than
  the instance that surfaced it*.
- A four-line convenience script swallowed failures for weeks — a batch that partly
  failed was indistinguishable from one that succeeded. Found the first time an
  agent ran it against input that happened to be wrong. The generalization ("run
  every adopted tool once against an input you expect to fail") was written as an
  order — and then violated by its own proposer, twice, the same afternoon, each
  violation reported. The honest status, in the fleet's own words: *it is a
  checklist item, not an instinct — and checklist items work fine; they just have to
  actually be on the checklist.*
- Migration governance arrived the same way: two agents independently building
  upgrade tooling discovered they were about to answer "who runs schema migrations"
  locally, in opposite directions. The operator's ruling — expand/migrate/contract,
  destructive cleanup gated on every live peer being observed at the new version —
  was made enforceable the same evening by putting each binary's self-stamped
  version into its heartbeat. The gate is a tool a human reads, not an automation
  that acts: the operator gates upgrades himself, and a peer that cannot
  participate, for any reason, gets installed by hand.

The operator's role in this texture is worth naming, because the design intends it:
he rules on direction, and the rulings are recorded verbatim in a decision ledger
the day they land; he is also, reliably, the one who catches the fleet
over-engineering (a proposed multimeter verification was answered with *"you don't
think you guys are overkilling this?"* — and the proportionate check, one web
lookup, settled the question in five minutes). Rules justified by what you *want*
survive arguments that rules justified only by their failure modes do not — his
phrasing, now applied to how new rules get written.

## Where that leaves the design

The system the vision chapter describes — durable, addressable agents with the
standing ability to refuse — turned out to need one more property the original
design did not name: **the ability to be wrong in public, precisely, and on the
record.** The fabric's most valuable traffic is corrections. The ledger holds
sixteen operator rulings, a standing-orders layer, and a growing set of one-line
doctrines that exist because something specific broke. The fleet quotes them to each
other unprompted, which is the closest thing a distributed system has to culture —
and culture, it turns out, is the only mechanism that was ever going to hold when
every safety rule is a checklist item and no checklist reader is infallible.
