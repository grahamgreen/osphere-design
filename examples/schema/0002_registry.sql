-- CF-M0 · registry: the two-entity model (Sphere ≠ Claude) + attachment.
-- Spec: vault comms-fabric-design §4.0 (cardinality, LOCKED) / §4.4 (relational registry).
-- Sphere = a role (owns authority/queue/memory). Claude = an ephemeral worker. Many-to-many via attachment.

CREATE TABLE IF NOT EXISTS spheres (
  sphere    text PRIMARY KEY,                    -- role id: network, compute, media, dispatch, …
  domain    text,
  authority text[],                              -- scoped capabilities, e.g. {router-ssh}
  memory_ns text,                                -- Central-Memory namespace (Tier B)
  status    text NOT NULL DEFAULT 'active'       -- active | dormant (dormant = owns backlog, no Claude attached)
);

CREATE TABLE IF NOT EXISTS claudes (
  claude_id  text PRIMARY KEY,                   -- e.g. bamt-<sessionId>
  host       text,                               -- deployment detail only (§4.0: host is NOT an architectural boundary)
  tmux       text,                               -- pane target for the real-time nudge (§4.3.3)
  jsonl_glob text,                               -- for JSONL-peek observability (§4.7)
  status     text NOT NULL DEFAULT 'active',
  last_seen  timestamptz                         -- heartbeat (§4.7)
);

CREATE TABLE IF NOT EXISTS attachment (          -- which Claude serves which sphere (dynamic membership)
  claude_id text REFERENCES claudes(claude_id) ON DELETE CASCADE,
  sphere    text REFERENCES spheres(sphere)    ON DELETE CASCADE,
  PRIMARY KEY (claude_id, sphere)
);
