#!/bin/bash
# packages.sh — установка пакетов из бэкапа с автофиксом ключей

restore_packages() {
    local backup_source="$1"
    
    log "Установка пакетов..."
    
    # --- 1. Восстанавливаем репозитории ---
    if [ -f "$backup_source/sources.list" ]; then
        cp "$backup_source/sources.list" /etc/apt/sources.list
        
        if [ -d "$backup_source/sources.list.d" ]; then
            cp -r "$backup_source/sources.list.d"/* /etc/apt/sources.list.d/ 2>/dev/null || true
        fi
    fi
    
    # --- 2. Фикс проблемных GPG-ключей ДО apt update ---
    fix_gpg_keys
    
    # --- 3. Обновляем списки пакетов ---
    log "Обновляю списки пакетов..."
    apt update 2>&1 | tee -a "$LOG_FILE" || {
        log_warn "apt update завершился с ошибкой. Пробую с --allow-insecure-repositories..."
        apt update --allow-insecure-repositories 2>&1 | tee -a "$LOG_FILE" || true
    }
    
    # --- 4. Устанавливаем пакеты ---
    if [ -f "$backup_source/packages-manual.txt" ]; then
        log "Устанавливаю пакеты из сохранённого списка..."
        
        # Сначала пробуем установить всё скопом
        xargs -a "$backup_source/packages-manual.txt" apt install -y --no-install-recommends 2>&1 | tee -a "$LOG_FILE" || {
            log_warn "Не все пакеты установились. Пробую по одному..."
            while read -r pkg; do
                apt install -y "$pkg" 2>/dev/null || log_warn "Не удалось установить: $pkg"
            done < "$backup_source/packages-manual.txt"
        }
    fi
    
    log_ok "Пакеты установлены"
}

# --- Фикс проблемных GPG-ключей ---
fix_gpg_keys() {
    log "Проверяю и исправляю GPG-ключи репозиториев..."
    
    # NodeSource (самый частый источник проблем в Debian 13)
    if grep -r "nodesource" /etc/apt/sources.list.d/ 2>/dev/null; then
        log "Обновляю ключ NodeSource..."
        
        # Определяем, какой инструмент доступен (Debian 13 использует sq вместо gpg)
        if command -v sq &>/dev/null; then
            curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key 2>/dev/null | \
                sq keyring merge --output=/usr/share/keyrings/nodesource.gpg 2>/dev/null || {
                    log_warn "Не удалось обновить ключ NodeSource через sq"
                }
        elif command -v gpg &>/dev/null; then
            curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key 2>/dev/null | \
                gpg --dearmor -o /usr/share/keyrings/nodesource.gpg --yes 2>/dev/null || {
                    log_warn "Не удалось обновить ключ NodeSource через gpg"
                }
        else
            log_warn "Нет ни sq, ни gpg. Устанавливаю sq..."
            apt install -y sq 2>/dev/null || true
            if command -v sq &>/dev/null; then
                curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key 2>/dev/null | \
                    sq keyring merge --output=/usr/share/keyrings/nodesource.gpg 2>/dev/null
            fi
        fi
        
        # Проверяем, что ключ создался
        if [ -f /usr/share/keyrings/nodesource.gpg ]; then
            log_ok "Ключ NodeSource обновлён"
        else
            log_warn "Ключ NodeSource не удалось создать. Репозиторий может не работать."
        fi
    fi
    
    # Docker (если используется)
    if grep -r "download.docker.com" /etc/apt/sources.list.d/ 2>/dev/null; then
        log "Обновляю ключ Docker..."
        curl -fsSL https://download.docker.com/linux/debian/gpg 2>/dev/null | \
            gpg --dearmor -o /usr/share/keyrings/docker.gpg --yes 2>/dev/null || \
            sq keyring merge --output=/usr/share/keyrings/docker.gpg 2>/dev/null || true
    fi
    
    # Добавьте сюда другие репозитории по мере необходимости
}