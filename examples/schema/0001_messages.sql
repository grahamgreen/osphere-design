-- CF-M0 · messages: the durable inbox queue (Tier-A).
-- Spec: vault comms-fabric-design §4.2 — competing-consumer claim via SELECT … FOR UPDATE SKIP LOCKED.
-- Delivered/durable the instant the INSERT commits (§4.1: durable store is the source of truth; push is only latency).

CREATE TABLE IF NOT EXISTS messages (
  id          text PRIMARY KEY,                 -- ULID (time-sortable → total order)
  to_sphere   text NOT NULL,                     -- shared-queue key: a SPHERE (§4.0), any attached Claude may claim
  to_claude   text,                              -- optional: pin to one Claude for thread continuity
  from_ref    text NOT NULL,                     -- "<sphere>" or "<sphere>#<claudeId>"
  kind        text NOT NULL,                     -- msg | task-offer | ack | heartbeat-req | approval-request | approval-result (§4.2, approval kinds per §7)
  body        jsonb NOT NULL,
  in_reply_to text,                              -- provenance / reply-path (§4.9, §7 approval bubbling)
  priority    text NOT NULL DEFAULT 'normal',    -- low | normal | high
  status      text NOT NULL DEFAULT 'new',       -- new | claimed | done  (the idempotency guard)
  claimed_by  text,                              -- claude_id that won the row
  claimed_at  timestamptz,
  created_at  timestamptz NOT NULL DEFAULT now()
);

-- Drives the claim query: WHERE to_sphere=$s AND status='new' ORDER BY priority DESC, id  FOR UPDATE SKIP LOCKED.
CREATE INDEX IF NOT EXISTS messages_queue_idx ON messages (to_sphere, status, id);
