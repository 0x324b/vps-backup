#!/bin/bash
# Бэкап пользовательских данных и настроек

backup_users() {
    log "Сохранение пользовательских данных..."
    
    # Базы данных пользователей
    cp /etc/passwd "$BACKUP_DIR/passwd"
    cp /etc/shadow "$BACKUP_DIR/shadow"
    cp /etc/group "$BACKUP_DIR/group"
    cp /etc/gshadow "$BACKUP_DIR/gshadow" 2>/dev/null || true
    
    # Домашние директории
    if [ -d /home ] && [ "$(ls -A /home 2>/dev/null)" ]; then
        tar -czf "$BACKUP_DIR/home.tar.gz" -C / home 2>/dev/null || log_warn "Ошибка архивации /home"
    fi
    
    # Корневая директория root (кроме наших бэкапов)
    tar -czf "$BACKUP_DIR/root.tar.gz" \
        -C / root \
        --exclude=root/vps-backup \
        2>/dev/null || log_warn "Ошибка архивации /root"
    
    # SSH-ключи
    if [ -d /root/.ssh ]; then
        cp -r /root/.ssh "$BACKUP_DIR/root-ssh-keys"
    fi
    
    log_ok "Пользовательские данные сохранены"
}