#!/bin/bash
# Восстановление файрвола

restore_firewall() {
    local backup_source="$1"
    
    log "Восстановление правил файрвола..."
    
    # Восстанавливаем iptables
    if [ -f "$backup_source/iptables.rules" ] && command -v iptables-restore &>/dev/null; then
        iptables-restore < "$backup_source/iptables.rules" 2>/dev/null || log_warn "iptables-restore не сработал"
        # Делаем правила постоянными
        if command -v netfilter-persistent &>/dev/null; then
            netfilter-persistent save
        elif [ -d /etc/iptables ]; then
            cp "$backup_source/iptables.rules" /etc/iptables/rules.v4 2>/dev/null || true
        fi
    fi
    
    # Восстанавливаем nftables
    if [ -f "$backup_source/nftables.rules" ] && command -v nft &>/dev/null; then
        nft -f "$backup_source/nftables.rules" 2>/dev/null || log_warn "nft restore не сработал"
    fi
    
    # UFW
    if [ -f "$backup_source/ufw-status.txt" ] && command -v ufw &>/dev/null; then
        ufw --force enable 2>/dev/null || true
    fi
    
    log_ok "Правила файрвола восстановлены"
}