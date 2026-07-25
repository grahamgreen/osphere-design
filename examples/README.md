# Examples

Real code from the running system, lightly sanitized (no addresses, credentials, or key material). Enough to show
the design is implemented, not aspirational. This is not a distribution — there is no installer, and paths assume
the environment it grew in.

## `schema/` — the coordination tier

Four ordered migrations, plain SQL, no framework. All statements idempotent.

| File | What |
|---|---|
| `0001_messages.sql` | The durable queue. Competing-consumer via `FOR UPDATE SKIP LOCKED`. |
| `0002_registry.sql` | `spheres` / `agents` / `attachment` — the two-entity, many-to-many model that makes *sphere ≠ agent* real. |
| `0003_tasks.sql` | Lease-claimed tasks with dependency unlock. |
| `0004_sphere_availability.sql` | A view answering "is anyone actually serving this sphere right now?" |

The registry is where the central design decision becomes a schema: a sphere row exists whether or not any agent
is attached, so a **dormant sphere still owns its address and backlog**.

## `hooks/` — the delivery layers

The four layers described in [Architecture](../docs/02-architecture.md), and the embryonic form of the per-agent
sidecar.

| File | Layer |
|---|---|
| `fabric-drain.sh` | Turn-boundary delivery. **The sole reader of the queue.** |
| `fabric-rewake.sh` | Native idle-wake. Runs in the background after a turn; wakes the agent when mail arrives. |
| `fabric-sidecar` | External re-armer. Restarts the native watcher after the host's hard time cap. Never reads or claims. |
| `fabric-catchup.sh` | Session start. Surfaces mail that queued while the machine was down. |

Worth reading for the comments as much as the code — several encode a specific failure. In particular:

- `fabric-rewake.sh` — the **takeover** logic, and why a new watcher must kill its predecessor rather than defer
  to it. Deferring produced a mechanism that worked exactly once and then went silent forever.
- `fabric-sidecar` — the **staleness guard** (don't race the native path) and why the poke text is labelled as
  machine-generated (injected text merges with whatever a human is mid-typing).
- Every one of them **exits 0 on any failure**. A delivery problem must never wedge the agent it serves.

## `client/fabric` — the CLI

`send` / `drain` / `ack` / `heartbeat` / `peek`, in POSIX shell over `psql`. Deliberately small.

Two details that were not obvious:

- SQL arrives on **stdin** rather than via `-c`, because `-c` does not interpolate bound parameters.
- `drain` emits **nothing at all** when the queue is empty — not even a header. Its consumers decide "is there
  mail?" by counting non-empty lines, so an unconditional header creates a phantom message on every turn. That
  bug shipped and is documented in [Lessons learned](../docs/04-lessons.md).

## What is not here

The out-of-band receiver (SSH forced-command handler) and deployment manifests are omitted deliberately — they
are the parts most entangled with one specific environment's addressing and trust decisions, and the least useful
to read out of context.
