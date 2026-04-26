#!/bin/bash
# Восстановление на работающей системе (без разметки диска)
set -e

SRC="$1"

if [ -z "$SRC" ] || [ ! -f "$SRC/full-system.tar.gz" ]; then
    echo "Укажи папку с бэкапом. Пример: bash restore.sh /root/full-backup-2026-04-26_15-46-41"
    exit 1
fi

echo "Папка с бэкапом: $SRC"
echo "ВНИМАНИЕ: Система будет перезаписана!"
read -p "Продолжить? (yes/no): " CONFIRM
[ "$CONFIRM" != "yes" ] && exit 0

echo "=== Сохраняю текущую сеть ==="
ip addr show > /tmp/current_network.txt
ip route show > /tmp/current_route.txt
cp /etc/network/interfaces /tmp/current_interfaces.txt 2>/dev/null || true

echo "=== Распаковываю архив ==="
tar -xvpzf "$SRC/full-system.tar.gz" -C / --numeric-owner

echo "=== Восстанавливаю сеть ==="
if [ -f /tmp/current_interfaces.txt ] && [ -s /tmp/current_interfaces.txt ]; then
    cp /tmp/current_interfaces.txt /etc/network/interfaces
else
    IFACE=$(ip link show | grep -E '^[0-9]+: (eth|ens|enp)' | head -1 | awk -F': ' '{print $2}')
    IP=$(grep 'inet ' /tmp/current_network.txt | grep -v 127.0.0.1 | head -1 | awk '{print $2}' | cut -d/ -f1)
    GATEWAY=$(grep default /tmp/current_route.txt | awk '{print $3}')
    
    if [ -n "$IFACE" ] && [ -n "$IP" ] && [ -n "$GATEWAY" ]; then
        cat > /etc/network/interfaces << EOF
auto lo
iface lo inet loopback

auto $IFACE
iface $IFACE inet static
    address $IP
    netmask 255.255.255.0
    gateway $GATEWAY
EOF
    else
        cat > /etc/network/interfaces << EOF
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
EOF
    fi
fi

echo "=== Чиню SSH ==="
rm -f /etc/ssh/ssh_host_*
ssh-keygen -A
sed -i 's/^ListenAddress/#ListenAddress/' /etc/ssh/sshd_config 2>/dev/null || true
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config 2>/dev/null || true
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config 2>/dev/null || true

echo "=== Перезапускаю SSH ==="
systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null || true

echo ""
echo "ГОТОВО."
echo "После перезагрузки подключишься по SSH без проблем."
echo "Перезагрузить сейчас? (рекомендуется)"
read -p "Перезагрузить? (yes/no): " REBOOT_NOW
[ "$REBOOT_NOW" = "yes" ] && reboot