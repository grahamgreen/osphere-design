-- CF-M0 · sphere_availability: per-sphere availability derived from per-Claude heartbeats.
-- Spec: vault comms-fabric-design §4.7 — liveness is per-Claude (heartbeat column), availability is per-sphere (this view).
-- A sphere is available iff at least one attached Claude has heartbeat within the window.

CREATE OR REPLACE VIEW sphere_availability AS
  SELECT s.sphere,
         bool_or(c.last_seen > now() - interval '2 minutes') AS available
  FROM spheres s
  LEFT JOIN attachment a ON a.sphere = s.sphere
  LEFT JOIN claudes    c ON c.claude_id = a.claude_id
  GROUP BY s.sphere;
