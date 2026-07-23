#!/data/data/com.termux/files/usr/bin/bash
# Dang ky dien thoai nay voi server quan ly bang 1 ma dang ky (enroll code) tao tu dashboard.
# Vi du: ./configure.sh --server "https://vps.example.com:8080" --code "AB12cd34EF" --label "Xiaomi-01"
set -euo pipefail

AGENT_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_PORT=1080
SERVER_URL=""
CODE=""
LABEL=""

while [ $# -gt 0 ]; do
  case "$1" in
    --server) SERVER_URL="$2"; shift 2 ;;
    --code) CODE="$2"; shift 2 ;;
    --label) LABEL="$2"; shift 2 ;;
    --local-port) LOCAL_PORT="$2"; shift 2 ;;
    *) echo "Tham so khong ro: $1" >&2; exit 1 ;;
  esac
done

command -v jq >/dev/null 2>&1 || { echo "Thieu jq, chay ./install.sh truoc." >&2; exit 1; }

[ -z "$SERVER_URL" ] && read -r -p "Dia chi server (vd https://vps.example.com:8080): " SERVER_URL
[ -z "$CODE" ] && read -r -p "Ma dang ky (lay tu dashboard, tab 'Ma dang ky'): " CODE
if [ -z "$LABEL" ]; then
  read -r -p "Nhan cho thiet bi nay (Enter de dung nhan mac dinh cua ma dang ky): " LABEL
fi
SERVER_URL="${SERVER_URL%/}"

echo "==> Dang goi dang ky toi $SERVER_URL ..."
payload="$(jq -n --arg code "$CODE" --arg label "$LABEL" '{code: $code} + (if $label == "" then {} else {label: $label} end)')"

http_response="$(mktemp)"
http_code="$(curl -sS -o "$http_response" -w '%{http_code}' -X POST "$SERVER_URL/api/agent/register" \
  -H "Content-Type: application/json" -d "$payload")" || {
  echo "Khong ket noi duoc toi $SERVER_URL. Kiem tra dia chi server va mang." >&2
  rm -f "$http_response"; exit 1
}
body="$(cat "$http_response")"
rm -f "$http_response"

if [ "$http_code" != "200" ]; then
  echo "Dang ky that bai (HTTP $http_code):" >&2
  echo "$body" | jq -r '.error // .' >&2 2>/dev/null || echo "$body" >&2
  exit 1
fi

PHONE_ID="$(echo "$body" | jq -r '.phone_id')"
API_KEY="$(echo "$body" | jq -r '.api_key')"
PROXY_PORT="$(echo "$body" | jq -r '.proxy.port')"
PROXY_USER="$(echo "$body" | jq -r '.proxy.user')"
PROXY_PASS="$(echo "$body" | jq -r '.proxy.pass')"
FRP_SERVER_ADDR="$(echo "$body" | jq -r '.frp.server_addr')"
FRP_BIND_PORT="$(echo "$body" | jq -r '.frp.bind_port')"
FRP_TOKEN="$(echo "$body" | jq -r '.frp.token')"
REMOTE_PORT="$(echo "$body" | jq -r '.frp.remote_port')"

cat > "$AGENT_HOME/.env" <<EOF
SERVER_URL=$SERVER_URL
PHONE_ID=$PHONE_ID
API_KEY=$API_KEY
LOCAL_SOCKS_PORT=$LOCAL_PORT
PROXY_USER=$PROXY_USER
PROXY_PASS=$PROXY_PASS
FRP_SERVER_ADDR=$FRP_SERVER_ADDR
FRP_BIND_PORT=$FRP_BIND_PORT
FRP_TOKEN=$FRP_TOKEN
REMOTE_PORT=$REMOTE_PORT
HEARTBEAT_INTERVAL_SECONDS=30
COMMAND_POLL_INTERVAL_SECONDS=20
ROTATE_TOGGLE_DELAY=5
EOF
chmod 600 "$AGENT_HOME/.env"

sed \
  -e "s/__FRP_SERVER_ADDR__/$FRP_SERVER_ADDR/g" \
  -e "s/__FRP_BIND_PORT__/$FRP_BIND_PORT/g" \
  -e "s/__FRP_TOKEN__/$FRP_TOKEN/g" \
  -e "s/__PHONE_ID__/$PHONE_ID/g" \
  -e "s/__LOCAL_SOCKS_PORT__/$LOCAL_PORT/g" \
  -e "s/__REMOTE_PORT__/$REMOTE_PORT/g" \
  "$AGENT_HOME/templates/frpc.toml.tmpl" > "$AGENT_HOME/frpc.toml"

# Escape "/" trong duong dan de dung an toan lam chuoi thay the cua sed (vd "s#a#b#").
escaped_home="$(printf '%s\n' "$AGENT_HOME" | sed 's/[&/\]/\\&/g')"
sed "s/__AGENT_HOME__/$escaped_home/g" \
  "$AGENT_HOME/termux-boot/proxy-from-mobile.sh.tmpl" > "$AGENT_HOME/termux-boot/proxy-from-mobile.sh"
chmod +x "$AGENT_HOME/termux-boot/proxy-from-mobile.sh"

echo ""
echo "==> Dang ky thanh cong."
echo "    Thiet bi ID : $PHONE_ID"
echo "    Proxy cong khai se la : <IP_VPS>:$REMOTE_PORT (SOCKS5, user=$PROXY_USER)"
echo ""
echo "Buoc tiep theo:"
echo "  1. ./scripts/start.sh                (khoi dong ngay)"
echo "  2. (tuy chon, de tu chay lai khi may reboot - can cai app Termux:Boot rieng):"
echo "       mkdir -p ~/.termux/boot"
echo "       cp \"$AGENT_HOME/termux-boot/proxy-from-mobile.sh\" ~/.termux/boot/"
