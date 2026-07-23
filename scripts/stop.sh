#!/data/data/com.termux/files/usr/bin/bash
# Dung toan bo tien trinh cua phone-agent (microsocks, frpc, va 2 vong lap nen).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./common.sh

for name in microsocks frpc heartbeat poll_commands; do
  stop_proc "$name"
done
