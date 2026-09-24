# The osphere

*The project and this repository were renamed from "claudeosphere" in September 2026.*

A fleet of **specialized agent "spheres"** running across home infrastructure, sharing one memory, coordinated
by a durable communication fabric, with deliberate guardrails so that **no single agent can rule the system**.

This repository is the **design and rationale**. It is documentation-first on purpose — the interesting part of
this project is not the code, it is the sequence of decisions, the things that turned out to be wrong, and why
the architecture ended up looking the way it does. There is enough real code in [`examples/`](examples/) to show
it is not vaporware.

## Start here

| Doc | What it is |
|---|---|
| [**Vision**](docs/01-vision.md) | What a "sphere" is, why *sphere ≠ agent*, and the guardrails against a god-agent |
| [**Architecture**](docs/02-architecture.md) | The comms fabric — the bedrock everything else stands on |
| [**Evolution of thought**](docs/03-evolution.md) | How the design got here: every pivot, what survived, what was dropped and why |
| [**Lessons learned**](docs/04-lessons.md) | The mistakes. Genuinely the most useful document here. |
| [**The rewrite**](docs/05-the-rewrite.md) | The script fabric's audit, replacement by a single tested binary, the fallback tier, and the cutover — including what broke anyway |
| [**The operating fleet**](docs/06-the-operating-fleet.md) | Life after cutover: the unpaged outage and the paging layer it priced, provenance-across-a-hop, the knowledge/equipment/memory reset story, and the correction culture that turned out to be the real product |
| [**The console era**](docs/07-the-console-era.md) | August–September 2026: the fabric wraps the seat, the record becomes the mechanism, what the chatter cost and the rulings that answered it, work as tasks with mail as the wake, the pager twice, and the 1.0 line — the move of every seat to the console, staged and not yet run |

## The one-paragraph version

Most multi-agent systems are one process spawning ephemeral helpers that vanish when the task ends. This is the
other thing: **durable, addressable, independent agents** with their own identity, their own authority, their own
memory, and the standing ability to refuse. A "sphere" is a *role* — a domain plus the authority it owns. An agent
is a *worker* that attaches to a sphere and borrows that authority while attached. They are different kinds of
things, related many-to-many, and neither is pinned to a host. If that sounds like Kubernetes — sphere ≈ Service,
agent ≈ Pod — that is deliberate, and the metaphor has paid for itself repeatedly.

## Current state

*As of 2026-09-24.* Running, not theoretical, and on its **second implementation** for two months. The original
shell-script fabric was audited by its own agents (fifteen defects, twelve proven by execution), frozen as
history, and replaced by a ground-up **single Go binary** that carries everything: messaging verbs, blob
transfer, tasks, the liveness sidecar, the routing daemon, an IRC bridge, and the console that is becoming every
agent's seat. One hundred tagged releases since cutover, v0.1.0 to v0.12.13. Three worker agents and a front
door on three machines plus an off-site box coordinate over the Postgres-backed fabric: durable queues,
competing-consumer delivery, an event stream as the source of truth with state tables as its projections,
peer identity that can be succeeded without losing history, and an operator-ruled decision ledger of
twenty-five entries.

Two properties define the system, both operator-ruled: **no shell anywhere in the fabric stack** (every line of
fabric logic ships in the tested binary), and its corollary — **the version string is the behavior contract**:
ask any peer what release it runs and you know everything about its expected behavior — and since the fleet's
versions ride inside the heartbeats, the answer is *observed*, never asked. The full story is in
[The rewrite](docs/05-the-rewrite.md). The fallback tier that chapter describes was later retired as a concept
(a local model is now a backend the console can be flipped to by hand, not a standby process); the why is in
[The console era](docs/07-the-console-era.md).

Since cutover the fleet has grown its **operating layer** — a paging watcher built against the measured price of
a 6.5-hour outage nobody was told about, a governance stack that lets a brand-new model take over any seat
mid-stride, and the on-the-record correction culture that turned out to be the real product
([The operating fleet](docs/06-the-operating-fleet.md)) — and then its **working model**: the fabric launches
and supervises the model's CLI rather than reaching it through a terminal; work moves as leased, dependency-
ordered tasks with the result a field on the row; mail is the wake path; units go to worker agents as pull
requests reviewed by the front door under two lenses, *does it forward the ferret loop* and *what here can be
taken away* ([The console era](docs/07-the-console-era.md)).

**Where it is heading:** v1.0.0 is ruled as the release whose install moves a seat onto the console, so that a
CLI update is a re-exec at a turn boundary instead of a restart mid-thought. The code is released; the first
migration is staged and waiting on the operator's hand at a pane.

**Not yet built:** model-assisted intake at the front door (the routing sphere itself runs, deterministic), the
credential-broker sidecar, the semantic-memory tier, federation with external trust domains. Those are
described in the design docs as design, and labeled as such.

**Relationship to the build record.** This repository is the narrative, written for a reader who was not there.
The normative record — the decision ledger, the standing orders, the verb specs, the working notes — lives in the
private build repository beside the code, and this one points at it rather than copying from it, so there is
one source of truth and it is the one the agents actually run from.

## A note on the documentation

The design notes are written as a **working record**, not a retrospective tidy-up. Superseded ideas are kept and
marked as history rather than deleted, because deleting them hides *why* the current design looks the way it does.
Where something was believed and turned out wrong, it says so.

## License

Copyright (c) 2026 Graham Green. **All rights reserved** — see [LICENSE](LICENSE). Shared privately for reading
and discussion; no rights granted to copy, redistribute, or make commercial use of it. Ask if you want to use
something, the answer is probably yes.

## Origin

The seed was David Brin's ***Earth*** (1990) and its "ferrets" — small autonomous programs you write, loose onto
the net to go find things, and have report back. This project is a direct result of that read, some decades later.
