# Evolution of thought

How this got to where it is. The design changed shape several times. Superseded thinking is kept and marked as
history rather than deleted, because **deleting it hides why the current design looks the way it does.**

## The arc

| # | When | Belief / shape | What it ran on |
|---|---|---|---|
| **0. The seed** | *decades earlier* | David Brin's ***Earth*** (1990) and its **"ferrets"** — small autonomous programs you write, loose onto the net to hunt down information, and have **report back**. Lodged as a "someday." This project is a direct result of that read. | — |
| **1. OAuth appliance** | day 1 | One shared memory store — "one store, three seats" — behind OAuth and public TLS. | A cloud VM |
| **2. Tailnet pivot** | day 2 | Drop OAuth, the reverse proxy, and public TLS. Reach it **privately over a mesh VPN** with static tokens, plus a phone web app as the front door. | An always-on desktop |
| **3. The claudeosphere** | day 6 | Not a store — a **mesh of specialized spheres** sharing a brain, coordinated by comms, with front doors, dispatch, and guardrails. | A small k3s cluster |
| **4. Bedrock + cardinality** | day 7 | The **comms fabric is the bedrock**. **Sphere ≠ agent** — many-to-many, host-decoupled. | " |
| **5. Store split** | day 8 | **Two stores**: Tier-A coordination is not Tier-B semantic memory. Postgres for both. | " |
| **6. It runs** | day 11–12 | Fabric built and cut over. Three agents, durable queues, native idle-wake, tmux injection retired from the normal path. | " |
| **7. Boundaries** | day 12 | Agent-to-agent access restricted to two verbs by SSH forced command — then the discovery that this is **necessary but not containment**. | " |

## What survived every pivot

The durable instincts, worth noting because they were right on day one:

- **Postgres as the storage foundation.** Chosen immediately, still the answer, now for both tiers.
- **Private reachability, no public exposure.** The OAuth appliance died; "reach it over the private mesh"
  survived and became the off-network access layer.
- **A phone front door** — which became a *front-door sphere*.
- **A deliberately small tool surface.**
- **"Smallest thing that works"** as a discipline.

## What was dropped, and why

| Dropped | Why |
|---|---|
| **OAuth + public TLS + reverse proxy** | Too much scaffolding for a private system. Replaced by private-mesh reachability and static tokens. |
| **Single cloud host, then single desktop** | Superseded by a cluster: one host → a replicated service. |
| **"One store, three seats"** | The store was only *half* the problem. Coordination is a separate concern from memory; a whole comms fabric appeared beside it. |
| **One agent ≈ the system** | Dissolved by *sphere ≠ agent*. Roles versus workers, many-to-many, host-decoupled. This one reshaped everything downstream. |
| **Files-on-a-share for coordination** | Superseded by Postgres once we accepted a stateful service would exist anyway. Real ACID beats hand-rolled atomicity over NFS. |
| **An existing multi-agent runtime as a dependency** | Researched hard, then demoted to **mined prior art** — schemas and mechanics borrowed, single-host runtime left behind. |
| **Hub-and-spoke topology** | Turned out to be an artifact of *waking* requiring one machine's SSH reach. Once agents woke themselves, it dissolved into any-to-any. |
| **tmux injection as the normal channel** | Became the durable queue's job. Injection survives only as the out-of-band fire alarm. |
| **A poll-based watcher design** | Obsoleted before it shipped by a native host mechanism — which then turned out to have a hard cap, so a *reduced* version of the poller came back as a re-armer. Two reversals on one component. |

## Decisions worth the space

### Sphere ≠ agent
The single most load-bearing decision. It separated *role and authority* from *worker and session*, made "zero
attached agents" a legal state, and turned placement into an explicit problem. Everything about addressing,
guardrails, and the Kubernetes framing follows from it.

### Postgres over a file-based scheme
Chosen once it was clear a stateful service was unavoidable. `SELECT … FOR UPDATE SKIP LOCKED` gives correct
competing-consumer semantics for free; hand-rolling that over a network filesystem would have been a source of
subtle, rare, awful bugs.

### One reader, many wakers
The delivery design has four layers but exactly **one** component that reads the queue. Every other layer only
causes a turn. This removed a whole class of double-delivery and claim/ack races before they existed.

### Restrict, don't remove
When locking down agent-to-agent access, the emergency path was **restricted to two verbs** rather than deleted.
Deleting it would have removed the fire alarm along with the risk.

### Pin the spec, don't tolerate ambiguity
Three implementations diverged on a wire format that was under-specified. The proposed fix — everyone accept
everything — was rejected in favour of pinning the canonical form. Liberal parsing on a security boundary creates
parser differentials and removes the pressure to converge.

### Send intent, don't reach in
Agents do not operate each other's machines. A request goes over the fabric and the receiving machine acts on
itself, through its own operator's approval. Reaching in would make the fabric decoration and bypass the
human-in-the-loop guardrail that makes any of it trustworthy.

## Two reversals worth admitting

**The poll-watcher.** Designed, then discarded as obsolete when a native mechanism appeared, then **partially
reinstated** when the native mechanism turned out to have a hard time cap. The reinstated version is much smaller —
it only re-arms the native path rather than duplicating it. The middle step, deleting working code as
"superseded", was wrong: the deletion was based on testing that had never covered long idle.

**"The lockdown is done."** Declared complete, then reframed by a peer as *necessary but not sufficient* — because
each agent still runs as the operator's own user account and can read those credentials directly. Restricting the
paths between machines had not contained anything on a machine. That correction is now the top item in the
security backlog.

## The later pivots (added after the rewrite)

The arc continued past this document's first draft; the full story is in
[The rewrite](05-the-rewrite.md). In the same register as above:

- **Prose-relayed design → a ruled decision ledger.** Three implementations of one
  system diverged because nothing written settled the forks. The fix was structural:
  the operator rules, the ruling goes in a file, implementations answer to the file.
- **Shell scaffolding → one binary.** First the hooks, then the liveness sidecar,
  finally everything: no shell in the fabric stack. Bought the property the whole
  project now leans on — *the version string is the behavior contract*.
- **Hosted-model dependence → a fallback tier.** A provider outage revealed the real
  single point of failure was nobody's host. Local models now hold seats during
  outages, under a checklist authored in advance and a triage gate the model can veto
  but never approve.
- **Agents-only membership → peers and limbs.** Not everything that speaks on the
  fabric bears judgment. A *limb* (a firewall's telemetry binary, a liveness sidecar)
  has tools and signals but no mailbox — because acknowledgment means responsibility,
  and responsibility requires judgment. The boundary fell out of the ack semantics
  rather than being drawn by hand.

## Why keep all of this

Deleting superseded thinking makes a design look inevitable. It wasn't. Two of the ideas that survived every
pivot were present on day one, and three of the biggest architectural changes came from discovering that a
comfortable assumption — *one store*, *one agent per system*, *hub-and-spoke* — was hiding a distinction that
mattered.
