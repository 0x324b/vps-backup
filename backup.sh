#!/bin/bash
# ======================================================================
# backup.sh — Полный бэкап Debian VPS
# Часть проекта vps-backup: https://github.com/ваш_юзер/vps-backup
# ======================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# Подключаем модули
source "$SCRIPT_DIR/lib/backup/system-info.sh"
source "$SCRIPT_DIR/lib/backup/packages.sh"
source "$SCRIPT_DIR/lib/backup/configs.sh"
source "$SCRIPT_DIR/lib/backup/users.sh"
source "$SCRIPT_DIR/lib/backup/firewall.sh"

# --- Главная процедура ---
main() {
    echo "=============================================="
    echo "  VPS Backup Tool v1.0"
    echo "  $(date)"
    echo "=============================================="
    echo ""
    
    check_root
    init_backup_dir
    check_disk_space 1024
    
    log "Начинаю создание бэкапа..."
    
    # Сбор информации
    collect_system_info
    backup_packages
    backup_configs
    backup_users
    backup_firewall
    
    # --- Полный образ системы (опционально) ---
    echo ""
    read -p "Создать ПОЛНЫЙ образ всей системы (tar.gz)? Может занять много времени (y/N): " FULL_BACKUP
    
    if [[ "$FULL_BACKUP" =~ ^[Yy]$ ]]; then
        log "Создание полного образа системы..."
        tar -cvpzf "$BACKUP_DIR/debian-full-system.tar.gz" \
            "${EXCLUDES[@]}" \
            --exclude="$BACKUP_DIR" \
            / 2>&1 | tee -a "$LOG_FILE"
        
        if [ ${PIPESTATUS[0]} -eq 0 ]; then
            log_ok "Полный образ создан: $BACKUP_DIR/debian-full-system.tar.gz"
        elif [ ${PIPESTATUS[0]} -eq 1 ]; then
            log_warn "Образ создан, но некоторые файлы изменились — это нормально"
        else
            log_error "Ошибка создания образа (код: ${PIPESTATUS[0]})"
        fi
        
        # Контрольная сумма
        sha256sum "$BACKUP_DIR/debian-full-system.tar.gz" > "$BACKUP_DIR/sha256sum.txt"
    fi
    
    # --- Итог ---
    local size=$(du -sh "$BACKUP_DIR" | cut -f1)
    
    echo ""
    echo "=============================================="
    log_ok "Бэкап завершён!"
    echo "   Расположение: $BACKUP_DIR"
    echo "   Размер: $size"
    echo ""
    echo "   Для скачивания выполните на локальной машине:"
    echo "   scp -r root@$(hostname -I | awk '{print $1}'):$BACKUP_DIR ."
    echo ""
    echo "   Для восстановления на новом сервере:"
    echo "   1. Скопируйте папку на новый VPS"
    echo "   2. Запустите restore.sh из этой папки"
    echo "=============================================="
}

main "$@"