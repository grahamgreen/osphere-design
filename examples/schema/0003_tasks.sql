-- CF-M0 · tasks: the shared task list (Tier-A).
-- Spec: vault comms-fabric-design §4.5 — SKIP LOCKED claim + lease reclaim + dependency auto-unlock.
-- Ownership is by SPHERE; a Claude claims on its sphere's behalf. Also the overlap-ownership protocol
-- (claim before touching a shared resource: a router config, a manifest).

CREATE TABLE IF NOT EXISTS tasks (
  task_id      text PRIMARY KEY,                 -- ULID
  title        text,
  description  text,
  owner_sphere text,                             -- which sphere owns/should do it
  status       text NOT NULL DEFAULT 'pending',  -- pending | claimed | in-progress | pending-approval | done (pending-approval per §7)
  depends_on   text[],                           -- task_ids that must be 'done' first (auto-unlock via NOT EXISTS)
  claimed_by   text,                             -- claude_id holding the lease
  lease_expiry timestamptz,                      -- past → reclaimable (fixes the "stuck task" failure mode)
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS tasks_claimable_idx ON tasks (owner_sphere, status);
