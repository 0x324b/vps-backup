#!/bin/bash
# Сохранение информации о пакетах

backup_packages() {
    log "Сохранение списка пакетов..."
    
    # Все установленные пакеты с версиями
    dpkg -l > "$BACKUP_DIR/packages-full.txt"
    
    # Только явно установленные
    apt-mark showmanual > "$BACKUP_DIR/packages-manual.txt"
    
    # Для точного восстановления версий
    dpkg --get-selections > "$BACKUP_DIR/packages-selections.txt"
    
    # Список репозиториев
    cp -r /etc/apt/sources.list "$BACKUP_DIR/sources.list" 2>/dev/null || true
    cp -r /etc/apt/sources.list.d "$BACKUP_DIR/sources.list.d" 2>/dev/null || true
    
    # Ключи репозиториев
    apt-key exportall > "$BACKUP_DIR/repo-keys.gpg" 2>/dev/null || true
    
    log_ok "Информация о пакетах сохранена ($(wc -l < "$BACKUP_DIR/packages-manual.txt") пакетов)"
}