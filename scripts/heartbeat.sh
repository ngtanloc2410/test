#!/data/data/com.termux/files/usr/bin/bash
# Vong lap gui trang thai (IP hien tai, pin) len server dinh ky. Chay nen boi start.sh.
set -uo pipefail # khong dung -e: 1 lan that bai khong duoc lam chet ca vong lap
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./common.sh

require_env SERVER_URL PHONE_ID API_KEY

while true; do
  ip="$(current_proxy_ip || true)"

  battery=""
  if command -v termux-battery-status >/dev/null 2>&1; then
    battery="$(termux-battery-status 2>/dev/null | jq -r '.percentage // empty' 2>/dev/null || true)"
  fi

  body="$(jq -n --arg ip "${ip:-}" --arg battery "${battery:-}" '{
    public_ip: ($ip | if . == "" then null else . end),
    battery_pct: ($battery | if . == "" then null else (tonumber? // null) end)
  }')"

  if agent_api POST /heartbeat "$body" >/dev/null 2>&1; then
    log "Heartbeat OK (ip=${ip:-?})"
  else
    log "Heartbeat that bai - kiem tra ket noi toi \$SERVER_URL"
  fi

  sleep "${HEARTBEAT_INTERVAL_SECONDS:-30}"
done
