#!/bin/bash
# Восстановление конфигураций

restore_configs() {
    local backup_source="$1"
    
    log "Восстановление конфигураций..."
    
    # Создаём бэкап текущих конфигов перед заменой
    tar -czf "/root/pre-restore-etc-$(date +%s).tar.gz" /etc 2>/dev/null || true
    
    # Восстанавливаем /etc целиком, если есть полный архив
    if [ -f "$backup_source/etc-full.tar.gz" ]; then
        tar -xzf "$backup_source/etc-full.tar.gz" -C / 2>/dev/null
    fi
    
    # Восстанавливаем отдельные критичные конфиги (на случай конфликтов)
    for archive in "$backup_source"/config-*.tar.gz; do
        [ -f "$archive" ] && tar -xzf "$archive" -C / 2>/dev/null || true
    done
    
    log_ok "Конфигурации восстановлены"
}