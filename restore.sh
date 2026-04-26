#!/bin/bash
# ======================================================================
# restore.sh — Восстановление Debian VPS из бэкапа
# Часть проекта vps-backup: https://github.com/0x324b/vps-backup
#
# ВАЖНО: Этот скрипт нужно запускать НА НОВОМ СЕРВЕРЕ!
# Он восстановит данные из указанной папки с бэкапом.
# ======================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

source "$SCRIPT_DIR/restore/packages.sh"
source "$SCRIPT_DIR/restore/configs.sh"
source "$SCRIPT_DIR/restore/users.sh"
source "$SCRIPT_DIR/restore/firewall.sh"
source "$SCRIPT_DIR/restore/cleanup.sh"

# --- Главная процедура ---
main() {
    echo "=============================================="
    echo "  VPS Restore Tool v1.0"
    echo "  $(date)"
    echo "=============================================="
    echo ""
    
    check_root
    
    # Проверяем, откуда восстанавливать
    if [ -n "${1:-}" ]; then
        BACKUP_SOURCE="$1"
    elif [ -d "./backup" ]; then
        BACKUP_SOURCE="./backup"
    else
        echo "Доступные бэкапы:"
        ls -1 /root/vps-backup/ 2>/dev/null || echo "  (нет сохранённых бэкапов)"
        echo ""
        read -p "Введите путь к папке с бэкапом: " BACKUP_SOURCE
    fi
    
    if [ ! -d "$BACKUP_SOURCE" ]; then
        log_error "Папка с бэкапом не найдена: $BACKUP_SOURCE"
        exit 1
    fi
    
    # Проверяем, что это действительно папка с бэкапом
    if [ ! -f "$BACKUP_SOURCE/packages-manual.txt" ]; then
        log_warn "Похоже, это не папка с бэкапом (нет packages-manual.txt)"
        read -p "Продолжить? (y/N): " CONFIRM
        [[ "$CONFIRM" =~ ^[Yy]$ ]] || exit 0
    fi
    
    echo ""
    echo "Будет восстановлено из: $BACKUP_SOURCE"
    echo "ВНИМАНИЕ: Текущие конфиги будут сохранены в /root/pre-restore-*.tar.gz"
    echo ""
    read -p "Продолжить? (y/N): " CONFIRM
    [[ "$CONFIRM" =~ ^[Yy]$ ]] || exit 0
    
    # Создаём лог
    mkdir -p /root/vps-backup/logs
    LOG_FILE="/root/vps-backup/logs/restore-$(date +%Y-%m-%d_%H-%M-%S).log"
    touch "$LOG_FILE"
    
    log "Начинаю восстановление..."
    
    # Восстановление
    restore_packages "$BACKUP_SOURCE"
    restore_configs "$BACKUP_SOURCE"
    restore_users "$BACKUP_SOURCE"
    restore_firewall "$BACKUP_SOURCE"
    cleanup_old_artifacts
    
    # --- Итог ---
    echo ""
    echo "=============================================="
    log_ok "Восстановление завершено!"
    echo ""
    echo "   Следующие шаги:"
    echo "   1. Настройте сеть (IP мог измениться):"
    echo "      nano /etc/network/interfaces"
    echo ""
    echo "   2. Замените старый IP на новый в конфигах:"
    echo "      grep -r 'СТАРЫЙ_IP' /etc/"
    echo "      find /etc -type f -exec sed -i 's/СТАРЫЙ_IP/НОВЫЙ_IP/g' {} \\;"
    echo ""
    echo "   3. Перезагрузите сервер:"
    echo "      reboot"
    echo ""
    echo "   Лог восстановления: $LOG_FILE"
    echo "=============================================="
}

main "$@"