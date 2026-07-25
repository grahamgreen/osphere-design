#!/bin/sh
# Stop hook — drain this box's sphere queue at the turn boundary and surface new messages.
# DEFENSIVE: any failure / slowness => exit 0 (never wedge the session).
# Portable across Linux (timeout) and macOS (gtimeout from coreutils; none => run bare).
# Sphere/claude come from ~/.config/fabric/env (the fabric client self-sources it).
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$HOME/.local/bin:$PATH"
input=$(cat)
active=$(printf '%s' "$input" | jq -r '.stop_hook_active // false' 2>/dev/null)
[ "$active" = "true" ] && exit 0
TO=""
command -v timeout  >/dev/null 2>&1 && TO="timeout 8"
command -v gtimeout >/dev/null 2>&1 && TO="gtimeout 8"
msgs=$($TO fabric drain 2>/dev/null)
[ $? -ne 0 ] && exit 0
[ -z "$msgs" ] && exit 0
n=$(printf '%s\n' "$msgs" | grep -c .)
reason=$(printf '[fabric] %s new message(s) on your sphere — read and handle these before stopping:\n%s' "$n" "$msgs")
jq -n --arg r "$reason" '{decision:"block", reason:$r}'
exit 0
