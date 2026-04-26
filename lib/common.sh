#!/bin/bash
# common.sh — общие функции, переменные и настройки

set -euo pipefail  # Строгий режим: ошибки, неинициализированные переменные, пайпы

# --- Цвета для вывода ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- Переменные ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"
BACKUP_ROOT="/root/vps-backup"
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
BACKUP_DIR="$BACKUP_ROOT/$TIMESTAMP"
LOG_FILE="$BACKUP_DIR/backup.log"

# Исключения для tar (виртуальные ФС и временные файлы)
EXCLUDES=(
    --exclude=/proc
    --exclude=/sys
    --exclude=/dev
    --exclude=/run
    --exclude=/tmp
    --exclude=/mnt
    --exclude=/media
    --exclude=/lost+found
    --exclude=/swapfile
    --exclude=/var/cache/apt/archives/*.deb
    --exclude=/var/log/journal
    --exclude=/root/vps-backup
)

# --- Функции логирования ---
log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $*" | tee -a "$LOG_FILE"
}

log_ok() {
    echo -e "${GREEN}[OK]${NC} $*" | tee -a "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" | tee -a "$LOG_FILE" >&2
}

# --- Проверка прав ---
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "Этот скрипт должен запускаться от root!"
        exit 1
    fi
}

# --- Создание директории бэкапа ---
init_backup_dir() {
    mkdir -p "$BACKUP_DIR"
    log "Директория бэкапа: $BACKUP_DIR"
    touch "$LOG_FILE"
}

# --- Проверка свободного места ---
check_disk_space() {
    local required_mb=${1:-1024}  # минимум 1GB по умолчанию
    local available_mb=$(df /root --output=avail | tail -1)
    available_mb=$((available_mb / 1024))
    
    if [ "$available_mb" -lt "$required_mb" ]; then
        log_error "Недостаточно места! Доступно: ${available_mb}MB, требуется: ${required_mb}MB"
        exit 1
    fi
    log_ok "Свободного места: ${available_mb}MB"
}