#!/bin/bash
# Установка пакетов из бэкапа

restore_packages() {
    local backup_source="$1"
    
    log "Установка пакетов..."
    
    # Восстанавливаем репозитории
    if [ -f "$backup_source/sources.list" ]; then
        cp "$backup_source/sources.list" /etc/apt/sources.list
        
        if [ -d "$backup_source/sources.list.d" ]; then
            cp -r "$backup_source/sources.list.d"/* /etc/apt/sources.list.d/ 2>/dev/null || true
        fi
    fi
    
    apt update
    
    # Устанавливаем пакеты из сохранённого списка
    if [ -f "$backup_source/packages-manual.txt" ]; then
        # Сначала пробуем установить всё скопом
        xargs -a "$backup_source/packages-manual.txt" apt install -y --no-install-recommends 2>&1 | tee -a "$LOG_FILE" || {
            log_warn "Не все пакеты установились. Пробую по одному..."
            # Если не вышло — ставим по одному, пропуская проблемные
            while read -r pkg; do
                apt install -y "$pkg" 2>/dev/null || log_warn "Не удалось установить: $pkg"
            done < "$backup_source/packages-manual.txt"
        }
    fi
    
    log_ok "Пакеты установлены"
}