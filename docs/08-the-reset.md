# The reset — heartbeats become state, and a seat that answered nothing for forty-two days

*The console-era chapter closes on 2026-09-24 with the migration staged and the board
idle. This chapter covers the six weeks after: three more idle weeks, a one-paragraph
reset from the operator, the week of motion it bought, the finding that the first
migrated seat had been silent since the day it moved, and where the 1.0 line stands on
2026-11-05. Rulings are numbered as the decision ledger numbers them; the ledger did
not grow in this period, and that is part of the story.*

## Three idle weeks, and a reset

Nothing closed on the board between 23 September and 14 October. The fleet beat, the
dispatcher sent its nightly digest, and every digest said the same thing. Then, at one in
the morning on 15 October, the operator wrote one paragraph:

> *"i want to get osphere up and running 100% including a router/dispatcher. lets
> cleanup our todos and focus on that and keep w/ the Brin vision."*

The board was cleaned the same night. A pager row that had been open since August was
retracted as done, because it was: every publisher had moved off the public notification
service the day before. That service had been rate-limiting the house by source address
every afternoon since late August, which meant a page raised between lunch and dinner
could be dropped with a 429 and nobody would know. The replacement is a self-hosted
server with a write-only token per box and one reader — the front door, which watches
the heartbeat topic because it is the absence detector. One parked item was parked
again. What remained was a list of ten rows in order, each with an owner, a gate and a
*needs* column, and a sentence at the top saying everything else in the file was history.

The word *router* needed a ruling before it needed code, and the ruling was already on
the record from 1 September: assignment stays explicit, *"i enjoy determinism."* The
dispatcher routes nothing. It sweeps expired leases, digests terminal task events into
one note to the front door, and refuses mail that is not a task. So a router in this
system is not a binding table that decides which sphere gets which message; it is the
operator's intent reaching the right sphere as a recorded offer, from the console or the
phone, without the operator typing the verb. That is intake, and it became row 3.

The reset also closed the driver-seat question. The front door had been forbidden from
reaching other boxes since the script era, when an agent shelling into a peer was the
system's main provenance hole. With the fabric carrying every message and every task,
the operator suspended the rule for the seat he drives from: one key, proven on every
box in the fleet, with the router reachable as a read-only user and the network sphere
still the only hand that changes it.

## Heartbeats become state

Row 2 was the oldest idea on the list and the one the pager story had made urgent. The
fleet's job-level heartbeats — a feed watcher and a lag watcher among them — had been
posting to a notification topic every few minutes, which is how a system with no
quota problem of its own inherited one from a third party. The fix is a verb: `fabric
pulse <name>` records one beat of a named job as a row in the fabric, with an
*expectation* registered beside it, and the sidecar judges absence against the
expectation. A missing beat pages once per episode; the recovery notifies only if the
episode paged. No quota, no third party, and every watcher can read it, because a beat
is now state rather than a message that was consumed when it was delivered.

The acceptance was measured on the network box, from the box's own delivery log:

- The two emitters moved to the verb. The posting rate to the old topic went from about
  a hundred and ten a day to zero, with the last post at 15:17 on 20 October.
- A kill test: the feed watcher's timer was stopped at 15:23. MISSING fired at 15:43,
  twenty seconds past the expectation plus one beat. The timer was restored at 15:44 and
  RECOVERED fired thirty-three seconds later — and only because that episode had paged.

The same release carried a smaller fix with the same shape. Both long-lived daemons, the
dispatcher and the bridge, had treated a dead database connection as permanent: the
process stayed up, looked alive to its supervisor, and did nothing. Now a dead connection
ends the process and the supervisor restarts it. The proof was done the way the
operating-fleet chapter said proofs should be done, with a negative control first. On
the front-door box, killing a throwaway database session left the dispatcher untouched;
terminating the dispatcher's own session produced the expected error at the next tick,
an exit, a restart by launchd, a new session re-taking the advisory lock, and an unmoved
cursor — thirty-seven seconds from kill to recovery. On the cluster, the same pair of
kills left the bridge pod at zero restarts and then one, with the new session on the
network two seconds after the kill and the seven channels mirroring again.

Row 1 closed on 21 October, on fields. Row 2 flipped on 20 October and owes one closing
read — a full day with no rate-limit errors in the delivery log — before the network
seat marks it done. v0.12.14 was the release that carried both. By the morning of
21 October every live peer reported it.

## Forty-two days of a seat that answered nothing

The console-era chapter says no seat had migrated. That was the board's understanding,
and it was wrong in the more uncomfortable direction.

On 21 October, working the migration row for the first box, the front door found that
the box's console resident had been running since 9 September — the day the checklist
paused. It had been launched by the operating system at boot, exactly as designed. It
drained its mail. It beat. It reported its version into the peer list, so the fleet's
version line, the *observed* contract the rewrite chapter is proud of, showed a healthy
seat on a current release. And every turn it took had failed in the first second,
because the launcher's environment had no path to the model's CLI, and the environment
loader could not add to a variable the launcher had already set. Forty-two days of a
seat that claimed mail and answered nothing. The error was visible on exactly one
surface: an attach pane that nobody had attached.

The fix was one line in a launch manifest. The second trap landed the same night, and
it is the better lesson because it is the same lesson. The operator logged the seat in
from inside a terminal multiplexer, which has no access to the keychain, so the fresh
token went to a file; the resident's child process, launched by the system and
keychain-capable, kept reading the expired token that the first run had migrated into
the keychain weeks earlier. Two processes on one box, two credential stores, one of them
lying. Cleared by deleting the keychain item; the next turn re-saved the fresh token.
At 01:09 the seat answered a peer's message from the resident — its first completed
turn in six weeks.

What the system had been measuring was liveness: the box is up, the process is up, the
version is this. What it had not been measuring was *work*: did the last turn produce an
answer. Those are different questions, and the fleet had excellent instruments for the
first and none for the second, which is how a dead seat passed every check for six
weeks while its operator assumed the migration had not happened yet. The pulse verb that
shipped the same week is the shape of the answer — a beat per job, judged against an
expectation — and the row that remains is to give a seat's *turns* that shape. The
rewrite chapter's line holds: the version string is the behavior contract, and the
answer is observed, never asked. It only has to be added that a contract is a statement
about what a thing will do, and observing that the thing is present is not observing
that it did it.

## Intake: the operator's words become a row

Row 3 was written as a standing order rather than code, seven rules in a read-do
procedure: the operator says what he wants, at the pane or in the chat bridge; the seat
turns it into one task offer with a budget and an origin; and reads it back from the row,
not from memory. The gate was *one real offer made this way*, and it was met the same
night without anyone arranging it. At 00:40 the operator, attached to the first migrated
seat, said that the terminal UI's F3 binding is Mission Control on a Mac and never
reaches the application. The front door offered that sentence to the compute sphere as a
row with a budget, read it back, and the pull request giving every F-key a Ctrl primary
was merged at 00:56. Sixteen minutes from a remark to a merged change, with the row as
the only handoff. The status bar got its own fix in the same hour, after the operator
read the backend's name beside the console's version as a version of the backend.

v0.12.15 was cut at 01:23 with those two changes, and three seats took it within the
hour. Its image step then hung for twenty-four minutes on a push to the container
registry — the registry answered an unauthenticated probe in a fifth of a second, so it
was not reachability — and was killed. The bridge, which runs from that image, stays on
v0.12.14 *by decision*: the release touches no bridge code, and rolling a pod to change
nothing is exactly the kind of addition D25 says to leave out. The cause of the hang is
a small row for the next release the bridge actually needs.

## Where it stands, 5 November 2026

The fleet today: the front door, the dispatcher, the first migrated seat and the compute
seat on v0.12.15; the network seat and the bridge on v0.12.14; the retired and renamed
names kept in the peer list as history. One hundred and one tagged releases from v0.1.0
at cutover to v0.12.15. The decision ledger still ends at D25; the reset was a plan, not
a ruling, and the week it bought needed no new ones.

That week is the whole of the period's motion. Between 20 and 21 October, rows 1 and 3
closed, row 2's code shipped with one read still owed, row 4's release was cut with the
front door's own flip onto it still owed, and the first migrated seat's row was all but
closed by the finding above — one strict observation, a peer answered with *no* client
attached, remains. Since 21 October nothing has moved. The dispatcher's digest has said *eight sitting, nothing
completed* every night for two weeks: the second model provider as a backend, the live
backend switch that depends on it, the two worker-seat migrations that are the 1.0 line,
the heartbeat row waiting on one closing read from the network box, and three smaller
ones. Every one of them is gated on either a worker seat claiming it or the operator's
hand at a pane.

This is the second time the chapter ends this way, and it is worth saying plainly rather
than framing it as a pause. The fleet does not generate its own work; that is a ruling
(D20), and the reasons for it are in the vision chapter. So the system moves at the
speed of one person's attention, in bursts: a ruling, a week, idle. The burst in October
shipped two durable properties — beats as state, and a daemon that dies rather than
lingers — and found a seat that had been dead since the day it moved. Both were found by
working the list, not by the instruments. The instruments are the next row.
