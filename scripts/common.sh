#!/data/data/com.termux/files/usr/bin/bash
# Nap boi cac script khac trong phone-agent/scripts/. Khong tu chay truc tiep file nay.

# Thu muc goc cua phone-agent (2 cap tren thu muc chua file nay: scripts/common.sh -> phone-agent/)
AGENT_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$AGENT_HOME/.env"
LOG_DIR="$AGENT_HOME/logs"
RUN_DIR="$AGENT_HOME/run"

mkdir -p "$LOG_DIR" "$RUN_DIR"

if [ -f "$ENV_FILE" ]; then
  set -a
  # shellcheck source=/dev/null
  source "$ENV_FILE"
  set +a
fi

log() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
  echo "$msg"
  echo "$msg" >> "$LOG_DIR/agent.log"
}

require_env() {
  for name in "$@"; do
    if [ -z "${!name:-}" ]; then
      log "LOI: thieu bien moi truong $name trong .env - chay ./configure.sh truoc."
      exit 1
    fi
  done
}

# Goi API quan ly, tu dong dinh kem Bearer api_key cua thiet bi.
agent_api() {
  local method="$1" path="$2" body="${3:-}"
  require_env SERVER_URL PHONE_ID API_KEY
  if [ -n "$body" ]; then
    curl -fsS -m 15 -X "$method" "$SERVER_URL/api/agent/$PHONE_ID$path" \
      -H "Authorization: Bearer $API_KEY" -H "Content-Type: application/json" \
      -d "$body"
  else
    curl -fsS -m 15 -X "$method" "$SERVER_URL/api/agent/$PHONE_ID$path" \
      -H "Authorization: Bearer $API_KEY"
  fi
}

# Lay IP cong khai HIEN TAI cua chinh duong truyen 4G bang cach di qua proxy SOCKS5 noi bo,
# thay vi goi thang tu may (may co the con dang di Wi-Fi song song nen se ra sai IP).
current_proxy_ip() {
  local port="${LOCAL_SOCKS_PORT:-1080}"
  curl -fsS -m 10 --socks5-hostname "127.0.0.1:$port" https://ifconfig.me 2>/dev/null
}

is_process_running() {
  local pid_file="$1"
  [ -f "$pid_file" ] && kill -0 "$(cat "$pid_file")" 2>/dev/null
}

stop_proc() {
  local name="$1" pid_file="$RUN_DIR/$name.pid"
  if [ -f "$pid_file" ]; then
    local pid
    pid="$(cat "$pid_file")"
    if kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
      log "Da dung $name (pid $pid)"
    fi
    rm -f "$pid_file"
  fi
}

# start_microsocks/start_frpc chi khoi dong THANH PHAN PROXY (khong dung toi vong lap
# heartbeat/poll_commands), de lenh "restart_proxy" tu server co the goi rieng ham nay
# ma khong tu giet chinh tien trinh poll_commands.sh dang goi no (xem poll_commands.sh).
start_microsocks() {
  local pid_file="$RUN_DIR/microsocks.pid"
  local bin="${MICROSOCKS_BIN:-$(command -v microsocks || echo "$AGENT_HOME/bin/microsocks")}"
  local port="${LOCAL_SOCKS_PORT:-1080}"
  if is_process_running "$pid_file"; then
    log "microsocks da chay (pid $(cat "$pid_file")), bo qua."
    return
  fi
  require_env PROXY_USER PROXY_PASS
  log "Khoi dong microsocks tren 127.0.0.1:$port"
  nohup "$bin" -i 127.0.0.1 -p "$port" -u "$PROXY_USER" -P "$PROXY_PASS" \
    >> "$LOG_DIR/microsocks.log" 2>&1 &
  echo $! > "$pid_file"
}

start_frpc() {
  local pid_file="$RUN_DIR/frpc.pid"
  local bin="$AGENT_HOME/bin/frpc"
  if is_process_running "$pid_file"; then
    log "frpc da chay (pid $(cat "$pid_file")), bo qua."
    return
  fi
  require_env FRP_SERVER_ADDR FRP_TOKEN
  log "Khoi dong frpc, ket noi toi $FRP_SERVER_ADDR:$FRP_BIND_PORT"
  nohup "$bin" -c "$AGENT_HOME/frpc.toml" >> "$LOG_DIR/frpc.log" 2>&1 &
  echo $! > "$pid_file"
}

restart_proxy_only() {
  log "restart_proxy: dung va khoi dong lai microsocks + frpc (khong dong vong lap agent)"
  stop_proc microsocks
  stop_proc frpc
  sleep 1
  start_microsocks
  start_frpc
}
