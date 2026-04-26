#!/bin/bash
# Восстановление пользователей

restore_users() {
    local backup_source="$1"
    
    log "Восстановление пользователей и паролей..."
    
    # Восстанавливаем базы пользователей
    if [ -f "$backup_source/passwd" ] && [ -f "$backup_source/shadow" ]; then
        cp "$backup_source/passwd" /etc/passwd
        cp "$backup_source/shadow" /etc/shadow
        [ -f "$backup_source/group" ] && cp "$backup_source/group" /etc/group
        [ -f "$backup_source/gshadow" ] && cp "$backup_source/gshadow" /etc/gshadow
    fi
    
    # Домашние директории
    [ -f "$backup_source/home.tar.gz" ] && tar -xzf "$backup_source/home.tar.gz" -C / 2>/dev/null
    [ -f "$backup_source/root.tar.gz" ] && tar -xzf "$backup_source/root.tar.gz" -C / 2>/dev/null
    
    # SSH-ключи root
    if [ -d "$backup_source/root-ssh-keys" ]; then
        mkdir -p /root/.ssh
        cp -r "$backup_source/root-ssh-keys"/* /root/.ssh/ 2>/dev/null || true
        chmod 700 /root/.ssh
        chmod 600 /root/.ssh/id_* 2>/dev/null || true
        chmod 644 /root/.ssh/id_*.pub 2>/dev/null || true
        chmod 600 /root/.ssh/authorized_keys 2>/dev/null || true
    fi
    
    log_ok "Пользователи восстановлены"
}