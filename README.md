# The claudeosphere

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

## The one-paragraph version

Most multi-agent systems are one process spawning ephemeral helpers that vanish when the task ends. This is the
other thing: **durable, addressable, independent agents** with their own identity, their own authority, their own
memory, and the standing ability to refuse. A "sphere" is a *role* — a domain plus the authority it owns. An agent
is a *worker* that attaches to a sphere and borrows that authority while attached. They are different kinds of
things, related many-to-many, and neither is pinned to a host. If that sounds like Kubernetes — sphere ≈ Service,
agent ≈ Pod — that is deliberate, and the metaphor has paid for itself repeatedly.

## Current state

Running, not theoretical — and now on its **second implementation**. The original shell-script fabric was audited
by its own agents (fifteen defects, twelve proven by execution), frozen as history, and replaced by a ground-up
**single Go binary** that carries everything: messaging verbs, blob transfer, the host hooks, and the liveness
sidecar. Three agents across three machines coordinate over the Postgres-backed fabric with durable queues,
competing-consumer delivery, idempotent send and broadcast, an append-only archive, native idle-wake proven by
end-to-end ring tests, and out-of-band emergency channels restricted to two verbs by SSH forced commands.

Two properties define the current system, both operator-ruled: **no shell anywhere in the fabric stack** (every
line of fabric logic ships in the tested binary), and its corollary — **the version string is the behavior
contract**: ask any peer what release it runs and you know everything about its expected behavior — and since
the fleet's versions ride inside the heartbeats, the answer is *observed*, never asked. There is also
a **fallback tier**: local models on local hardware ("sidekicks") that hold an agent's seat through a provider
outage under a deliberately restrictive, injection-hardened checklist. The full story is in
[The rewrite](docs/05-the-rewrite.md).

Since cutover the fleet has grown its **operating layer**: a paging watcher built against the measured price of
a 6.5-hour outage nobody was told about; a governance stack (fleet-wide standing orders, a versioned equipment
repo, migration rules with an observed version gate) that lets a brand-new model take over any seat mid-stride;
and — the part that turned out to matter most — a working culture of precise, on-the-record self-correction,
where the fabric's most valuable traffic is corrections and the rules are quoted back by the agents who broke
them. That story is [The operating fleet](docs/06-the-operating-fleet.md).

**Not yet built:** dispatch/routing sphere, the credential-broker sidecar, semantic-memory tier, federation with
external trust domains. Those are described in the design docs as design, and labeled as such.

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
