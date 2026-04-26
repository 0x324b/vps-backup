#!/bin/bash
# Бэкап конфигурационных файлов

backup_configs() {
    log "Архивирование конфигураций..."
    
    # Вся /etc кроме явно лишнего
    tar -czf "$BACKUP_DIR/etc-full.tar.gz" \
        -C / etc \
        --exclude=etc/ssl/certs \
        --exclude=etc/ssl/private \
        2>/dev/null || log_warn "Не удалось заархивировать часть /etc"
    
    # Отдельно — критически важные директории для быстрого доступа
    local critical_dirs=(
        /etc/wireguard
        /etc/openvpn
        /etc/xray
        /etc/sing-box
        /etc/strongswan
        /etc/ssh
        /etc/nginx
        /etc/apache2
        /etc/mysql
        /etc/postgresql
        /etc/systemd/system
    )
    
    for dir in "${critical_dirs[@]}"; do
        if [ -d "$dir" ]; then
            local dirname=$(echo "$dir" | sed 's|/|_|g' | sed 's|^_||')
            tar -czf "$BACKUP_DIR/config-${dirname}.tar.gz" -C / "$dir" 2>/dev/null || true
        fi
    done
    
    log_ok "Конфигурации сохранены"
}