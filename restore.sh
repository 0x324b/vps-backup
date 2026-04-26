#!/bin/bash
# Восстановление: распаковка на работающей системе + chroot + grub + автофикс SSH и сети
set -e

SRC="$1"
DISK="${2:-/dev/sda}"
ROOT="${DISK}1"

if [ ! -f "$SRC/full-system.tar.gz" ]; then
    echo "Архив не найден: $SRC/full-system.tar.gz"
    exit 1
fi

echo "Диск: $DISK, раздел: $ROOT"
read -p "ВСЁ БУДЕТ СТЁРТО. Продолжить? (yes/no): " CONFIRM
[ "$CONFIRM" != "yes" ] && exit 0

echo "=== Сохраняю текущую сеть ==="
ip addr show > /tmp/current_network.txt
ip route show > /tmp/current_route.txt
cat /etc/network/interfaces > /tmp/current_interfaces.txt 2>/dev/null || true

echo "=== Разметка ==="
wipefs -a "$DISK"
parted "$DISK" mklabel msdos
parted "$DISK" mkpart primary ext4 1MiB 100%
parted "$DISK" set 1 boot on
mkfs.ext4 -F "$ROOT"

echo "=== Монтирование ==="
mount "$ROOT" /mnt

echo "=== Распаковка ==="
tar -xvpzf "$SRC/full-system.tar.gz" -C /mnt --numeric-owner

echo "=== Восстанавливаю сеть ==="
# Копируем текущие настройки сети в новую систему
cp /tmp/current_network.txt /mnt/root/ 2>/dev/null || true
cp /tmp/current_route.txt /mnt/root/ 2>/dev/null || true

# Если interfaces был — восстанавливаем
if [ -f /tmp/current_interfaces.txt ] && [ -s /tmp/current_interfaces.txt ]; then
    cp /tmp/current_interfaces.txt /mnt/etc/network/interfaces
else
    # Если не было — создаём по данным из ip addr/route
    IFACE=$(ip link show | grep -E '^[0-9]+: (eth|ens|enp)' | head -1 | awk -F': ' '{print $2}')
    IP=$(grep 'inet ' /tmp/current_network.txt | grep -v 127.0.0.1 | head -1 | awk '{print $2}' | cut -d/ -f1)
    GATEWAY=$(grep default /tmp/current_route.txt | awk '{print $3}')
    
    if [ -n "$IFACE" ] && [ -n "$IP" ] && [ -n "$GATEWAY" ]; then
        cat > /mnt/etc/network/interfaces << EOF
auto lo
iface lo inet loopback

auto $IFACE
iface $IFACE inet static
    address $IP
    netmask 255.255.255.0
    gateway $GATEWAY
EOF
    else
        # DHCP fallback
        cat > /mnt/etc/network/interfaces << EOF
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
EOF
    fi
fi

echo "=== Чиню SSH ==="
# Убираем старые ключи и генерируем новые
rm -f /mnt/etc/ssh/ssh_host_*
chroot /mnt ssh-keygen -A

# Убираем привязку к старому IP
sed -i 's/^ListenAddress/#ListenAddress/' /mnt/etc/ssh/sshd_config 2>/dev/null || true

# Разрешаем вход root по паролю (на всякий случай)
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /mnt/etc/ssh/sshd_config 2>/dev/null || true
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /mnt/etc/ssh/sshd_config 2>/dev/null || true

echo "=== chroot и загрузчик ==="
mount --bind /dev /mnt/dev
mount --bind /proc /mnt/proc
mount --bind /sys /mnt/sys
chroot /mnt grub-install "$DISK"
chroot /mnt update-grub

echo "=== Размонтирование ==="
umount -l /mnt/dev /mnt/proc /mnt/sys
umount /mnt

echo ""
echo "ГОТОВО. Перезагружай: reboot"
echo "После перезагрузки SSH будет работать на порту 22 с тем же паролем root."