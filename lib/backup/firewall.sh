#!/bin/bash
# Сохранение правил файрвола

backup_firewall() {
    log "Сохранение правил файрвола..."
    
    # iptables
    if command -v iptables-save &>/dev/null; then
        iptables-save > "$BACKUP_DIR/iptables.rules" 2>/dev/null || true
    fi
    
    # nftables
    if command -v nft &>/dev/null; then
        nft list ruleset > "$BACKUP_DIR/nftables.rules" 2>/dev/null || log_warn "nft list ruleset не сработал"
    fi
    
    # UFW
    if command -v ufw &>/dev/null; then
        ufw status verbose > "$BACKUP_DIR/ufw-status.txt" 2>/dev/null || true
    fi
    
    log_ok "Правила файрвола сохранены"
}