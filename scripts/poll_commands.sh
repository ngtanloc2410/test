#!/data/data/com.termux/files/usr/bin/bash
# Vong lap lay lenh dang cho tu server (rotate_ip, restart_proxy) va bao ket qua ve.
# Chay nen boi start.sh. Luu y: restart_proxy chi dung/khoi dong lai microsocks+frpc
# (qua restart_proxy_only trong common.sh), KHONG duoc goi ./stop.sh o day vi stop.sh
# se giet ca chinh tien trinh poll_commands.sh nay truoc khi no kip khoi dong lai gi ca.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./common.sh

# Kiem tra cau hinh NGAY TAI DAY (ngoai command substitution) de neu thieu se exit that su
# thay vi bi "nuot" ben trong subshell cua $(...) o vong lap phia duoi.
require_env SERVER_URL PHONE_ID API_KEY

run_command() {
  local cmd_id="$1" command="$2"
  local result status

  case "$command" in
    rotate_ip)
      result="$(./rotate_ip.sh 2>&1)"
      status=$?
      ;;
    restart_proxy)
      result="$(restart_proxy_only 2>&1)"
      status=$?
      ;;
    *)
      result="Lenh khong ho tro: $command"
      status=1
      ;;
  esac

  local ack_status="done"
  [ "$status" -ne 0 ] && ack_status="failed"

  local body
  body="$(jq -n --arg status "$ack_status" --arg result "$result" '{status: $status, result: $result}')"
  agent_api POST "/commands/$cmd_id/ack" "$body" >/dev/null 2>&1
  log "Lenh $command (#$cmd_id) => $ack_status"
}

while true; do
  response="$(agent_api GET /commands 2>/dev/null || echo '{"commands":[]}')"
  echo "$response" | jq -c '.commands[]?' 2>/dev/null | while read -r item; do
    cmd_id="$(echo "$item" | jq -r '.id')"
    command="$(echo "$item" | jq -r '.command')"
    log "Nhan lenh moi: $command (#$cmd_id)"
    run_command "$cmd_id" "$command"
  done
  sleep "${COMMAND_POLL_INTERVAL_SECONDS:-20}"
done
