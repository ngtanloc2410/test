#!/data/data/com.termux/files/usr/bin/bash
# Xoay IP 4G cua thiet bi. Thu lan luot: root -> WRITE_SECURE_SETTINGS (khong can root) ->
# lenh tuy chinh ROTATE_IP_CUSTOM_CMD (vd Tasker HTTP trigger) neu 2 cach tren khong kha dung.
# In ra "ROTATED old=<ip> new=<ip>" khi thanh cong, "FAILED <ly do>" khi that bai. Exit code
# 0 = thanh cong, 1 = that bai - poll_commands.sh dua vao day de bao ket qua ve server.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./common.sh

TOGGLE_DELAY="${ROTATE_TOGGLE_DELAY:-5}"
VERIFY_TIMEOUT="${ROTATE_VERIFY_TIMEOUT_SECONDS:-30}"

toggle_via_root() {
  su -c 'svc data disable' >/dev/null 2>&1 || return 1
  sleep "$TOGGLE_DELAY"
  su -c 'svc data enable' >/dev/null 2>&1
}

toggle_via_secure_settings() {
  settings put global airplane_mode_on 1 2>/dev/null || return 1
  am broadcast -a android.intent.action.AIRPLANE_MODE --ez state true >/dev/null 2>&1
  sleep "$TOGGLE_DELAY"
  settings put global airplane_mode_on 0 2>/dev/null
  am broadcast -a android.intent.action.AIRPLANE_MODE --ez state false >/dev/null 2>&1
}

do_toggle() {
  if su -c 'id' >/dev/null 2>&1; then
    log "rotate_ip: dung phuong phap root (svc data disable/enable)"
    toggle_via_root && return 0
  fi
  if toggle_via_secure_settings; then
    log "rotate_ip: dung phuong phap airplane-mode qua WRITE_SECURE_SETTINGS"
    return 0
  fi
  if [ -n "${ROTATE_IP_CUSTOM_CMD:-}" ]; then
    log "rotate_ip: dung lenh tuy chinh ROTATE_IP_CUSTOM_CMD"
    eval "$ROTATE_IP_CUSTOM_CMD"
    return $?
  fi
  return 2
}

old_ip="$(current_proxy_ip || true)"
log "rotate_ip: IP truoc khi xoay = ${old_ip:-khong xac dinh}"

if ! do_toggle; then
  status=$?
  if [ "$status" -eq 2 ]; then
    echo "FAILED khong co phuong phap xoay IP nao kha dung (xem docs/PHONE_SETUP.md muc xoay IP)"
  else
    echo "FAILED lenh toggle that bai"
  fi
  exit 1
fi

deadline=$(( $(date +%s) + VERIFY_TIMEOUT ))
new_ip=""
while [ "$(date +%s)" -lt "$deadline" ]; do
  sleep 2
  new_ip="$(current_proxy_ip || true)"
  if [ -n "$new_ip" ] && [ "$new_ip" != "$old_ip" ]; then
    echo "ROTATED old=${old_ip:-?} new=$new_ip"
    exit 0
  fi
done

echo "FAILED da toggle nhung IP khong doi sau ${VERIFY_TIMEOUT}s (old=${old_ip:-?} new=${new_ip:-?})"
exit 1
