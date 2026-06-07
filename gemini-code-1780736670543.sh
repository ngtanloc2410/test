#!/bin/bash

echo "=========================================="
echo "BẮT ĐẦU CÀI ĐẶT TRAFFMONETIZER"
echo "=========================================="

# 1. Cài đặt các môi trường cần thiết
export DEBIAN_FRONTEND=noninteractive
echo ">> Đang cập nhật hệ thống và cài đặt phần mềm cần thiết..."
apt-get update -y
apt-get install jq docker.io iptables-persistent -y

echo "=========================================="
echo "Đang chờ VNIC thứ 2 được gắn vào máy..."
echo "(Vui lòng vào giao diện Oracle Console -> Attached VNICs -> Create VNIC)"
echo "=========================================="

# 2. Vòng lặp chờ VNIC 2 xuất hiện (Kiểm tra mỗi 15 giây)
while true; do
    VNICS=$(curl -s -H "Authorization: Bearer Oracle" -L http://169.254.169.254/opc/v2/vnics/)
    MAC_ENS5=$(echo $VNICS | jq -r '.[1].macAddr')

    # Nếu thấy địa chỉ MAC của card thứ 2, thoát vòng lặp để đi tiếp
    if [ "$MAC_ENS5" != "null" ] && [ ! -z "$MAC_ENS5" ]; then
        echo ">> Đã nhận diện được VNIC 2 (MAC: $MAC_ENS5). Bắt đầu cấu hình!"
        break
    fi
    echo "Vẫn đang chờ VNIC 2... (Sẽ kiểm tra lại sau 15 giây)"
    sleep 15
done

# 3. Lấy IP và Gateway
echo ">> Đang lấy thông tin IP và Gateway..."
IP_ENS3=$(echo $VNICS | jq -r '.[0].privateIp')
IP_ENS5=$(echo $VNICS | jq -r '.[1].privateIp')
GATEWAY=$(echo $IP_ENS5 | awk -F. '{print $1"."$2"."$3".1"}')
MAC_LOWER=$(echo "$MAC_ENS5" | tr '[:upper:]' '[:lower:]')

# 4. Ghi cấu hình Netplan cho card ens5
echo ">> Đang cấu hình mạng (Netplan) cho VNIC 2..."
cat <<EOF > /etc/netplan/60-secondary-vnic.yaml
network:
    version: 2
    ethernets:
        ens5:
            match:
                macaddress: "${MAC_LOWER}"
            set-name: ens5
            dhcp4: false
            addresses:
                - ${IP_ENS5}/24
            routing-policy:
                - from: ${IP_ENS5}
                  table: 200
            routes:
                - to: default
                  via: ${GATEWAY}
                  table: 200
EOF

netplan apply
echo ">> Đang chờ mạng ổn định..."
sleep 5 # Chờ vài giây để card mạng mới ổn định

# 5. Triển khai Docker và Iptables
TOKEN="tbOBkhRHWXCl8NHzr+/GF5qHDrWRo43PFU1XzPe+GGM="
DEVICE_NAME="oracle"

echo ">> Đang thiết lập Docker Network và IPTables..."

# Dọn dẹp sạch sẽ trước khi tạo
docker rm -f tm_1 tm_2 2>/dev/null || true
docker network rm my_network_1 my_network_2 2>/dev/null || true
iptables -t nat -D POSTROUTING -s 192.168.33.0/24 -j SNAT --to-source $IP_ENS3 2>/dev/null || true
iptables -t nat -D POSTROUTING -s 192.168.34.0/24 -j SNAT --to-source $IP_ENS5 2>/dev/null || true

# Tạo Network
docker network create my_network_1 --driver bridge --subnet 192.168.33.0/24
docker network create my_network_2 --driver bridge --subnet 192.168.34.0/24

# Gắn Iptables
iptables -t nat -I POSTROUTING -s 192.168.33.0/24 -j SNAT --to-source $IP_ENS3
iptables -t nat -I POSTROUTING -s 192.168.34.0/24 -j SNAT --to-source $IP_ENS5
netfilter-persistent save

# Khởi chạy Node Traffmonetizer
echo ">> Đang chạy Container Traffmonetizer 1..."
docker run -d --restart always --network my_network_1 --name tm_1 traffmonetizer/cli_v2 start accept --token "$TOKEN" --device-name "$DEVICE_NAME"

echo ">> Đang chạy Container Traffmonetizer 2..."
docker run -d --restart always --network my_network_2 --name tm_2 traffmonetizer/cli_v2 start accept --token "$TOKEN" --device-name "$DEVICE_NAME"

echo "=========================================="
echo ">> CÀI ĐẶT HOÀN TẤT THÀNH CÔNG!"
echo "=========================================="
