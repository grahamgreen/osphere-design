#!/bin/sh
# SessionStart hook — surface mail that queued while this Claude was DOWN.
#
# Closes the restart-bootstrap gap: the asyncRewake doorbell only arms at a turn END, so a
# freshly started Claude that sits idle would never see queued mail. This drains at session
# start and injects it as context immediately. It is what makes retiring the tmux bootstrap safe.
#
# DEFENSIVE: any failure => exit 0 silently. Never block a session from starting.
export PATH="/opt/homebrew/opt/libpq/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$HOME/.local/bin:$PATH"
cat >/dev/null 2>&1   # consume the hook's stdin JSON
. "${FABRIC_CONF:-$HOME/.config/fabric/env}" 2>/dev/null || exit 0

TO=""
command -v timeout  >/dev/null 2>&1 && TO="timeout 8"
command -v gtimeout >/dev/null 2>&1 && TO="gtimeout 8"

msgs=$($TO fabric drain 2>/dev/null) || exit 0
[ -z "$msgs" ] && exit 0
n=$(printf '%s\n' "$msgs" | grep -c .)
echo "[fabric catch-up $(date '+%Y-%m-%d %H:%M %Z')] $n message(s) arrived while this box was offline. Note the clock: you may have been down a long time - do not assume continuity with your last session. Read and handle these:"
printf '%s\n' "$msgs"
exit 0
