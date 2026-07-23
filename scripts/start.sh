#!/data/data/com.termux/files/usr/bin/bash
# Khoi dong proxy noi bo (microsocks) + tunnel (frpc) + vong lap heartbeat/poll-lenh.
# Goi lai script nay an toan: se bo qua thanh phan nao dang chay roi.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./common.sh

require_env PHONE_ID API_KEY PROXY_USER PROXY_PASS FRP_SERVER_ADDR FRP_TOKEN

start_loop() {
  local name="$1" script="$2"
  local pid_file="$RUN_DIR/$name.pid"
  if is_process_running "$pid_file"; then
    log "$name da chay (pid $(cat "$pid_file")), bo qua."
    return
  fi
  log "Khoi dong vong lap $name"
  nohup bash "$script" >> "$LOG_DIR/$name.log" 2>&1 &
  echo $! > "$pid_file"
}

start_microsocks
sleep 1
start_frpc
start_loop heartbeat "$AGENT_HOME/scripts/heartbeat.sh"
start_loop poll_commands "$AGENT_HOME/scripts/poll_commands.sh"

log "Da khoi dong xong. Xem log tai $LOG_DIR/, dung bang ./stop.sh"
