#!/bin/bash
# Сбор диагностической информации о системе

collect_system_info() {
    log "Сбор информации о системе..."
    
    # Разметка дисков
    fdisk -l > "$BACKUP_DIR/partition_layout.txt" 2>&1 || true
    blkid > "$BACKUP_DIR/uuids.txt"
    cat /etc/fstab > "$BACKUP_DIR/fstab.txt"
    
    # Сеть
    ip addr show > "$BACKUP_DIR/network.txt" 2>&1
    ip route show > "$BACKUP_DIR/routes.txt" 2>&1
    
    # Открытые порты
    ss -tulnp > "$BACKUP_DIR/ports.txt" 2>&1
    
    # Активные сервисы
    systemctl list-units --type=service --state=running > "$BACKUP_DIR/services.txt"
    
    # Загрузка модулей ядра
    lsmod > "$BACKUP_DIR/modules.txt"
    
    log_ok "Информация о системе собрана"
}