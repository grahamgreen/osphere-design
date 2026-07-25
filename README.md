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

## The one-paragraph version

Most multi-agent systems are one process spawning ephemeral helpers that vanish when the task ends. This is the
other thing: **durable, addressable, independent agents** with their own identity, their own authority, their own
memory, and the standing ability to refuse. A "sphere" is a *role* — a domain plus the authority it owns. An agent
is a *worker* that attaches to a sphere and borrows that authority while attached. They are different kinds of
thing, related many-to-many, and neither is pinned to a host. If that sounds like Kubernetes — sphere ≈ Service,
agent ≈ Pod — that is deliberate, and the metaphor has paid for itself repeatedly.

## Current state

Running, not theoretical. Three agents across three machines coordinate over a Postgres-backed message fabric with
durable queues, competing-consumer delivery, native idle-wake, and out-of-band emergency channels restricted to two
verbs by SSH forced commands. Bootstrapped and hardened over several days; the interesting failures are documented
in [Lessons learned](docs/04-lessons.md).

**Not yet built:** dispatch/routing sphere, the credential-broker sidecar, semantic-memory tier, federation with
external trust domains. Those are described in the design docs as design, and labeled as such.

## A note on the documentation

The design notes are written as a **working record**, not a retrospective tidy-up. Superseded ideas are kept and
marked as history rather than deleted, because deleting them hides *why* the current design looks the way it does.
Where something was believed and turned out wrong, it says so.

## Origin

The seed was David Brin's ***Earth*** (1990) and its "ferrets" — small autonomous programs you write, loose onto
the net to go find things, and have report back. This project is a direct result of that read, some decades later.
