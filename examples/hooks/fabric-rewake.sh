#!/bin/sh
# fabric-rewake — NATIVE idle-wake doorbell for Claude Code (no tmux).
#
# Registered as a Stop hook with "asyncRewake": true, so Claude Code runs it in the
# BACKGROUND after a turn ends and wakes the model when it exits 2. That gives a real
# push-wake while idle, with none of the tmux send-keys fake-typing.
#
# CONTENTLESS DOORBELL: it only detects that mail exists and wakes. It never drains or
# claims — the Stop drain hook remains the SOLE reader, so no double-surface:
#     idle + arrival -> rewake -> WAKE        turn-end -> drain hook -> DELIVER
#
# Exits: 2 = mail waiting (wake the model) | 0 = nothing (window closed quietly).
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$HOME/.local/bin:$PATH"
. "${FABRIC_CONF:-$HOME/.config/fabric/env}" 2>/dev/null || exit 0
cat >/dev/null 2>&1   # consume hook stdin

# The watcher is bounded per-turn: after WINDOW with no mail it exits and this Claude is
# deaf until its next turn. Keep it generous (hours). LISTEN/NOTIFY would remove the poll.
WINDOW="${FABRIC_REWAKE_WINDOW:-14400}"   # 4h of idle coverage after each turn
POLL="${FABRIC_REWAKE_POLL:-10}"
LOCK="$HOME/.cache/fabric/rewake.lock"
LOG="$HOME/.cache/fabric/rewake.log"
mkdir -p "$HOME/.cache/fabric" 2>/dev/null
wlog() { echo "$(date '+%Y-%m-%d %H:%M:%S') [$$] $*" >> "$LOG"; }
wlog "SPAWN (window=${WINDOW}s poll=${POLL}s)"

# NEWEST WATCHER WINS (takeover, not deference).
# Earlier this deferred to a live predecessor and exited — which lost the doorbell entirely:
# at turn end the host spawns W2 while W1 is still alive, W2 exited, then W1 got reaped as
# turn cleanup, leaving ZERO watchers armed. Taking over guarantees exactly one, always the
# freshest, so every turn end re-arms the doorbell.
if [ -f "$LOCK" ]; then
  old=$(cat "$LOCK" 2>/dev/null)
  case "$old" in
    ''|*[!0-9]*) : ;;
    *) if [ "$old" != "$$" ] && kill -0 "$old" 2>/dev/null; then
         wlog "TAKEOVER - retiring previous watcher $old"
         kill "$old" 2>/dev/null
       fi ;;
  esac
fi
echo $$ > "$LOCK"
# Guarded cleanup: only clear the lock if WE still own it, so a dying predecessor can never
# delete the new owner's lock.
unlock() { cur=$(cat "$LOCK" 2>/dev/null); [ "$cur" = "$$" ] && rm -f "$LOCK"; }
trap 'wlog "EXIT signal - killed by host (turn start / session end)"; unlock; exit 0' INT TERM HUP
trap 'unlock' EXIT

elapsed=0
while [ "$elapsed" -lt "$WINDOW" ]; do
  sleep "$POLL"
  elapsed=$((elapsed + POLL))
  n=$(printf '%s' "SELECT count(*) FROM messages WHERE to_sphere=:'vs' AND status='new' AND (to_claude IS NULL OR to_claude=:'vc');" \
      | psql "$FABRIC_PGURL" -qtAX -v vs="$FABRIC_SPHERE" -v vc="$FABRIC_CLAUDE" 2>/dev/null | tr -d ' \n')
  case "$n" in
    ''|*[!0-9]*) continue ;;   # DB blip -> keep watching
    0) continue ;;
  esac
  wlog "FIRE - $n message(s) waiting, waking the model (exit 2) after ${elapsed}s"
  # Orient on the clock: a woken Claude does not know what time it is or how long it slept.
  echo "[fabric $(date '+%Y-%m-%d %H:%M %Z')] $n new message(s) arrived after ${elapsed}s idle - run fabric drain to read them" >&2
  exit 2                        # <- wakes the model
done
wlog "EXIT - window expired after ${elapsed}s with no mail"
exit 0
