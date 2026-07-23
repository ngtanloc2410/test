#!/data/data/com.termux/files/usr/bin/bash
# Cai dat cac thanh phan can thiet tren dien thoai (chay trong Termux). Chi can chay 1 lan.
# Sau khi chay xong, dung ./configure.sh de dang ky thiet bi voi server.
set -euo pipefail

AGENT_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$AGENT_HOME/bin"
mkdir -p "$BIN_DIR"

if [ ! -d "/data/data/com.termux" ]; then
  echo "Canh bao: co ve nhu ban khong chay trong Termux. Script nay danh rieng cho Termux tren Android." >&2
fi

echo "==> Cap nhat danh sach goi Termux"
pkg update -y

echo "==> Cai cac goi can thiet (curl, git, jq, clang/make de du phong build microsocks, termux-api)"
pkg install -y curl git jq clang make termux-api

# Kiem tra ngay curl co THUC SU chay duoc khong (khong chi la da cai) - tren mot so may Termux
# moi cai/nhieu ngay chua upgrade, curl bi loi "CANNOT LINK EXECUTABLE ... SSL_set_quic_tls_
# transport_params" do goi openssl va libngtcp2 lech phien ban nhau. Loi nay se lam hong ca
# buoc build microsocks (can git clone qua https) lan buoc tai frpc ben duoi, nen phai bao
# ngay tai day thay vi de nguoi dung thay 2-3 loi khac nhau don don, kho doan nguyen nhan that.
if ! curl --version >/dev/null 2>&1; then
  echo "" >&2
  echo "LOI: curl da cai nhung khong chay duoc (thu vien openssl/libngtcp2 tren may dang lech" >&2
  echo "phien ban voi nhau - hay gap sau khi cai Termux hoac lau chua upgrade)." >&2
  echo "Cach sua, chay lan luot roi thu lai ./install.sh:" >&2
  echo "  1. termux-change-repo   (chon 1 mirror cu the, dung de trong/mac dinh)" >&2
  echo "  2. pkg update -y && pkg upgrade -y" >&2
  echo "  3. curl --version       (kiem tra da het loi CANNOT LINK EXECUTABLE chua)" >&2
  exit 1
fi

echo "==> Cai microsocks (SOCKS5 server nhe, dung lam proxy noi bo tren may)"
if pkg install -y microsocks; then
  echo "    Da cai microsocks tu kho goi Termux."
else
  echo "    Khong co san trong kho goi, build tu source (rofl0r/microsocks)..."
  tmp_dir="$(mktemp -d)"
  git clone --depth 1 https://github.com/rofl0r/microsocks "$tmp_dir/microsocks"
  make -C "$tmp_dir/microsocks"
  cp "$tmp_dir/microsocks/microsocks" "$BIN_DIR/microsocks"
  chmod +x "$BIN_DIR/microsocks"
  rm -rf "$tmp_dir"
  echo "    Da build xong, dat tai $BIN_DIR/microsocks"
fi

echo "==> Tai frpc (reverse tunnel client, ban moi nhat tu github.com/fatedier/frp)"
ARCH_RAW="$(uname -m)"
case "$ARCH_RAW" in
  aarch64|arm64) FRP_ARCH="arm64" ;;
  armv7l|armv8l|arm) FRP_ARCH="arm" ;;
  x86_64|amd64) FRP_ARCH="amd64" ;;
  i686|i386) FRP_ARCH="386" ;;
  *) echo "Kien truc chua ho tro: $ARCH_RAW" >&2; exit 1 ;;
esac

# Doc TOAN BO output cua curl vao 1 bien truoc, roi moi grep tren bien do - khong duoc pipe
# thang "curl | grep -m1" vi grep -m1 se dong pipe ngay khi tim thay dong dau tien, con curl
# thi van dang co du lieu con lai can ghi tiep => curl bao loi "(23) Failure writing output"
# (viet duoc 1 phan roi vo pipe) ngay ca khi mang hoan toan binh thuong.
FRP_RELEASE_JSON="$(curl -fsSL https://api.github.com/repos/fatedier/frp/releases/latest)"
FRP_VERSION="$(echo "$FRP_RELEASE_JSON" | grep -m1 '"tag_name"' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"
if [ -z "$FRP_VERSION" ]; then
  echo "Khong lay duoc phien ban frp moi nhat (co the bi GitHub gioi han rate-limit), thu lai sau." >&2
  exit 1
fi
echo "    Phien ban: v$FRP_VERSION, kien truc: $FRP_ARCH"

tmp_tar="$(mktemp)"
curl -fsSL -o "$tmp_tar" \
  "https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/frp_${FRP_VERSION}_linux_${FRP_ARCH}.tar.gz"
tmp_extract="$(mktemp -d)"
tar -xzf "$tmp_tar" -C "$tmp_extract" --strip-components=1
cp "$tmp_extract/frpc" "$BIN_DIR/frpc"
chmod +x "$BIN_DIR/frpc"
rm -rf "$tmp_tar" "$tmp_extract"

echo ""
echo "==> Cai dat xong."
echo "Neu muon xoay IP tu dong khong can root, cap quyen dieu khien cai dat he thong cho Termux"
echo "bang lenh sau tren MAY TINH da bat 'go loi USB'/'go loi khong day' va cai adb:"
echo "    adb shell pm grant com.termux android.permission.WRITE_SECURE_SETTINGS"
echo ""
echo "Buoc tiep theo: chay ./configure.sh --server \"https://dia-chi-vps:8080\" --code \"MA_DANG_KY\""
