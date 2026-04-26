#!/bin/bash
set -e
DEST="/root/full-backup-$(date +%Y-%m-%d_%H-%M-%S)"
mkdir -p "$DEST"

echo "=== Диагностика ==="
fdisk -l > "$DEST/partition_layout.txt"
blkid > "$DEST/uuids.txt"
cat /etc/fstab > "$DEST/fstab.txt"
ip addr show > "$DEST/ip_config.txt"
iptables-save > "$DEST/iptables.rules" 2>/dev/null || true

echo "=== Полный архив ==="
tar -cvpzf "$DEST/full-system.tar.gz" \
    --exclude=/proc \
    --exclude=/tmp \
    --exclude=/mnt \
    --exclude=/dev \
    --exclude=/sys \
    --exclude=/run \
    --exclude=/media \
    --exclude=/lost+found \
    --exclude=/swapfile \
    --exclude=/var/cache/apt/archives/*.deb \
    --exclude=/root/full-backup-* \
    --exclude="$DEST" \
    /

echo "ГОТОВО: $DEST"