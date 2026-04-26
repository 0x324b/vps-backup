#!/bin/bash
# Очистка артефактов старой системы

cleanup_old_artifacts() {
    log "Очистка артефактов старой системы..."
    
    # Перегенерируем SSH-ключи хоста
    rm -f /etc/ssh/ssh_host_* 2>/dev/null || true
    dpkg-reconfigure -f noninteractive openssh-server 2>/dev/null || true
    
    # Очищаем machine-id (важно для systemd)
    if [ -f /etc/machine-id ]; then
        rm -f /etc/machine-id
        systemd-machine-id-setup 2>/dev/null || true
    fi
    
    # Пересобираем initramfs
    update-initramfs -u 2>/dev/null || true
    
    log_ok "Артефакты очищены"
}