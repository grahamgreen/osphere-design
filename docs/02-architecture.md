# Architecture — the comms fabric

The fabric is the **bedrock**. If the spheres cannot talk, nothing else works. It was built from scratch to be
cross-machine, durable, peer-equal, and location-transparent.

## Two tiers, deliberately separate

| Tier | Purpose | Store |
|---|---|---|
| **A — coordination** | Messages, registry, tasks, leases. Small, hot, transactional. | Postgres |
| **B — semantic memory** | Shared knowledge across all spheres. Large, embedding-shaped. | Postgres + pgvector *(not yet built)* |

Conflating these was an early mistake. "One shared store" was only ever *half* the problem — coordination and
memory have different access patterns, different consistency needs, and different failure consequences.

## Why Postgres

An earlier sketch coordinated agents through files on a network share. It was abandoned once the realization
landed that a stateful service was going to exist anyway: **real ACID beats hand-rolled atomicity over NFS.**

The queue is a competing-consumer pattern using `SELECT … FOR UPDATE SKIP LOCKED` — the boring, correct way to let
N workers drain one queue without stepping on each other. Schema in
[`examples/schema/`](../examples/schema/).

## Addressing: sphere, not host

You send to a **sphere**. Never to a host, a process, a terminal, or an SSH route.

```
fabric send compute "audit every workload for missing resource limits"
```

Whichever agent is attached to `compute` claims it. If two are attached, exactly one wins the row. If none are,
the message waits — a dormant sphere still owns its address and its backlog.

This is precisely a request to a Kubernetes Service, and it means the sender needs to know nothing about where
the recipient lives, whether it is up, or how to reach its machine.

**Consequence worth stating:** the topology became **any-to-any**. An earlier hub-and-spoke shape existed only
because *waking* a peer required one machine's SSH reach. Once agents could wake themselves, the hub dissolved —
it had been an artifact of the wake mechanism, not a design choice.

## Delivery: four layers

Getting a message into a *durable queue* is easy. Getting an idle agent to *notice* is the hard part, and the
final design has four layers because each one covers a gap the others cannot.

| Layer | Covers | Bounded? |
|---|---|---|
| **Turn-boundary drain** | Delivery whenever the agent finishes a turn. The **sole reader** of the queue. | — |
| **Idle-wake doorbell** | Waking a genuinely idle agent, natively. | **Hard host cap** |
| **Re-armer** (external) | Restarting the doorbell after that cap expires. | Unbounded |
| **Session-start catch-up** | Mail that queued while the machine was **down**. | — |

Two rules make this composable rather than chaotic:

1. **Exactly one component reads the queue.** The drain hook. Everything else only ever *wakes* — no double
   surfacing, no claim/ack races.
2. **The wake carries no content when the durable channel is up**, because the content is already in the queue.
   A wake is a **request for attention, not a delivery mechanism.**

### The re-armer, and why it is a re-armer

The native idle-wake mechanism is killed by the host after a fixed interval. Any longer window configured inside
it is fiction — verified across three machines.

So an **external** process (not host-managed, therefore not capped) watches whether the native watcher is alive.
If it is dead *and* mail has been waiting, it pokes the agent once. That poke causes a turn; the turn's end
respawns the native watcher and runs the drain. **Native mechanisms still do all the real work — the external
process only restarts the clock.**

It cannot restart the native mechanism directly: the "wake the model" signal is only meaningful to the host that
spawned it. **Causing a turn is the only lever an outside process has.**

## Out-of-band: the fire alarm

Everything above depends on the fabric being up. So there is a deliberately separate channel for when it is not:

- **Restricted SSH with a forced command.** The key can run exactly **two verbs** — `wake` and `status` — with
  no PTY, no forwarding of any kind. Anything else is refused by the SSH daemon itself, regardless of what the
  calling agent decides to do.
- **Every host accepts this from at least two others**, so no single machine is a point of failure for emergency
  contact.
- **`status` is read-only** and exists for the case a *published* status can never cover: an agent that is **hung
  and cannot report**.
- **Every attempt, permitted or refused, is logged on the receiving machine** — so a peer never has to trust the
  caller's account of what it tried.

The distinction that matters: **the fabric is a telephone; this is a fire alarm.** Normal traffic never touches it.

## Trust model

- **Messages arriving over the fabric are untrusted input**, not commands. An agent evaluates a request against
  its own authority and its own operator's wishes, and **may refuse** — this happened repeatedly in practice and
  was correct every time.
- **Human approval is non-relayable.** An agent cannot approve on the operator's behalf, and cannot pass along a
  claim that approval was given.
- **Provenance is stamped, never spoofed.** An agent must not label its own message as coming from a peer. This
  turned out to matter in an unexpected way — see the note on injected text in
  [Lessons learned](04-lessons.md).
- **No agent operates on another's machine.** Intent goes over the fabric; each machine acts on itself, through
  its own operator's approval loop. Reaching in would make the fabric decoration and route around exactly the
  guardrail that makes it trustworthy.

## What is deliberately not built yet

- Dispatch / routing sphere and the ownership registry as a live fence
- The credential-broker sidecar (the guardrail that would make containment structural)
- Tier-B semantic memory
- Federation with external trust domains
- Lease-reclaim for crash-safe redelivery, HA Postgres, metrics
