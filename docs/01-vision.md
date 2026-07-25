# Vision — the claudeosphere

> A fleet of **specialized spheres of control**, hosted across home infrastructure — *not* pinned to any one box —
> sharing one brain, coordinated by communication, with conversational **front doors** that dispatch work *into*
> the fleet. You chat with an agent on your phone; it passes work out into the claudeosphere.

## Everything is a sphere

Not layers with a privileged top. Front doors, shared memory, and dispatch/routing are **each their own sphere** —
peers with bounded jobs, not infrastructure sitting *above* the workers.

| Sphere kind | Role |
|---|---|
| **Front door** (ephemeral, conversational) | Phone / desktop / voice. Understands intent, dispatches inward. |
| **Central Memory** (shared brain) | Every sphere reads and writes it, so contexts link instead of siloing per chat. A peer *service*, not a controller. |
| **Dispatch / routing** | Routes a *request* to the owning sphere and tracks status. **Routes, does not command.** A day-one concern, not a later add. |
| **Worker spheres** (persistent) | network, compute, media, home-automation, voice. Coordinate on overlaps. |

## Sphere ≠ agent, and neither is host-bound

This is the load-bearing distinction, and it took a while to see.

A **sphere is a role** — a domain plus the authority it owns. An **agent is a worker** — a running session. They
are different kinds of thing, related **many-to-many via an attachment**.

- A sphere is served by **0..N** agents. **Zero is legal** — a dormant sphere still owns its backlog, its memory,
  and its address.
- An agent serves **1..N** spheres (usually one).
- **Authority lives on the sphere; an agent borrows it while attached.** A multi-sphere agent holds the *union* of
  those authorities — audit that union, because drifting toward one agent holding everything is exactly the
  god-agent the design forbids.
- **Host is a deployment detail, not a boundary.** A sphere may *own a resource on a host* — that is
  resource-authority, and fine. It does not pin the sphere's agent to that host. **Resource-authority ≠
  worker-placement.**

**The Kubernetes framing**, which has repeatedly earned its keep:

| Kubernetes | claudeosphere |
|---|---|
| Deployment / Service (+ ServiceAccount) | Sphere |
| Pod | Agent |
| Request to a Service → any ready replica | Message to a sphere → whichever attached agent claims it |
| Sidecar container | The per-agent runtime (delivery, credentials, audit) |
| Scaling to zero | A dormant sphere with no attached agent |

**Hierarchy is forbidden *between* spheres** (no sphere rules another) and **allowed *within* one** (a coordinator
over a single sphere's agent pool).

A consequence the 1:1 assumption had been hiding: **placement becomes an explicit concern.** Something has to
decide *where* a sphere's next agent runs.

## Guardrails — no "one agent to rule them all"

The core principle is **separation of powers and least privilege, for agents.** Mechanisms, strongest first:

1. **Scope power structurally, not by rule.** A sphere's power *is* the tools and credentials it holds. The
   network sphere holds network credentials and no cluster admin; the compute sphere the reverse. A sphere
   physically cannot rule a domain it has no keys to. *(This is the one that actually works — see below.)*
2. **Dispatch routes, doesn't command.** It hands a request to the owning sphere; the owner decides.
3. **The ownership registry is a fence, not a phonebook.** Cross-boundary work goes *through* the owner, never
   reaches around it.
4. **Hierarchy forbidden inter-sphere, allowed intra-sphere.**
5. **Human-in-the-loop** for high-impact, cross-sphere, or destructive actions. The human is the circuit-breaker,
   and their approval is **non-relayable** — a sphere cannot approve on their behalf.
6. **No self-escalation.** A sphere cannot grant itself new capabilities.
7. **Mutual observability.** Any sphere can inspect any other's activity, so nobody operates in the dark.

### Why #1 outranks the rest

Guardrails 2–7 are *policy*. Guardrail 1 is *physics*. An agent that has been confused, manipulated, or is simply
wrong cannot exceed a boundary it holds no credentials for — no judgment required, no instruction to follow.

This has been tested in anger, and the practical finding is documented in
[Lessons learned](04-lessons.md): **restricting what agents can do to each other is necessary but not sufficient.**
As long as an agent runs under the human's own user account, it can read that account's credentials — so the
boundary is a matter of restraint, not structure, until that changes.

That gap is the argument for the next piece.

## The sphere sidecar — the credential broker

A set of jobs is **identical for every sphere**, whatever its domain: inbox drain, heartbeat and registry,
task claim and lease, approval routing, provenance stamping, audit, and trust enforcement. They belong in one
shared **sidecar**, written once, not rebuilt per sphere.

Taking the Kubernetes metaphor literally pays off twice:

- **Data plane vs control plane.** Sidecars are the per-sphere data plane; dispatch, the registry, shared memory
  and the fabric schema are the control plane.
- **The sidecar is the credential broker — the sharpest available guardrail.** As a service mesh proxy holds a
  pod's identity, **the sidecar holds the sphere's scoped keys and the agent never does.** A confused or
  manipulated agent then *structurally cannot* exceed its sphere. Least privilege **enforced**, not principled.

> **Agent = judgment. Sidecar = deterministic protocol, policy, and credentials.**

The must-be-correct plumbing lives in deterministic code, so that (for example) approval routing is *enforced* —
it will not proceed without a human token — rather than merely *requested of* a language model.

The delivery hooks in [`examples/hooks/`](../examples/hooks/) are the embryonic version of this: cross-cutting
behavior wrapped identically around every agent.

## Open design questions

Honest about what is *not* solved:

- **Placement / scheduling** — with spheres decoupled from hosts, something must decide where a sphere's next
  agent runs.
- **Federation across trust domains.** Internal spheres are trusted structurally, by the keys they hold. An
  agent from a *different* trust domain — say a work machine — needs explicit enrollment, revocation, strictly
  scoped capability, data-domain segregation, and provenance tags so the system knows a task came from outside.
  This is its own design track, not a membership tweak.
- **Approval bubbling.** When something needs human approval it must route two ways: *up* to the human through
  whichever front door can reach them, and *back* to the originator, which may be another sphere. Needs a durable
  `pending-approval` state (approval can take hours — never block), a provenance chain so the decision returns
  along the path it came, timeout → default-deny, and a full audit of request and decision.
- **Containment of an agent from its own operator's credentials** — see above, and
  [Lessons learned](04-lessons.md).
