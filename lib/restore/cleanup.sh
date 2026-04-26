#!/bin/bash
# cleanup.sh — финальная очистка и адаптация под новый сервер

cleanup_and_repair() {
    log "Очистка артефактов и восстановление работоспособности..."

    # 1. Сохраняем ТЕКУЩИЕ рабочие настройки сети ДО замены конфигов
    log "Сохраняю текущие настройки сети..."
    local current_ip=$(ip addr show | grep 'inet ' | grep -v '127.0.0.1' | head -1 | awk '{print $2}' | cut -d/ -f1)
    local current_gw=$(ip route show default | awk '{print $3}')
    local current_iface=$(ip route show default | awk '{print $5}')
    
    echo "$current_ip" > /tmp/current_ip.txt
    echo "$current_gw" > /tmp/current_gw.txt
    echo "$current_iface" > /tmp/current_iface.txt

    # 2. Чиним SSH-ключи хоста (основная причина падения SSH)
    log "Проверяю и исправляю SSH-ключи хоста..."
    if [ ! -f /etc/ssh/ssh_host_ed25519_key ] || [ ! -s /etc/ssh/ssh_host_ed25519_key ]; then
        log_warn "SSH-ключи хоста отсутствуют или пусты. Генерирую новые..."
        rm -f /etc/ssh/ssh_host_* 2>/dev/null
        ssh-keygen -A
        log_ok "SSH-ключи сгенерированы"
    fi

    # Исправляем права на ключах
    chmod 600 /etc/ssh/ssh_host_*_key 2>/dev/null
    chmod 644 /etc/ssh/ssh_host_*_key.pub 2>/dev/null

    # 3. Убираем привязку к старому IP в sshd_config
    log "Исправляю конфигурацию SSH..."
    if grep -q "^ListenAddress" /etc/ssh/sshd_config 2>/dev/null; then
        log_warn "Найдена привязка к IP в sshd_config. Закомментирую..."
        sed -i 's/^ListenAddress/#ListenAddress/' /etc/ssh/sshd_config
    fi

    # Включаем парольную аутентификацию (на всякий случай, если ключи не сработают)
    if grep -q "^PasswordAuthentication no" /etc/ssh/sshd_config 2>/dev/null; then
        log_warn "Включаю PasswordAuthentication (временно)..."
        sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
    fi

    # Разрешаем root login
    if grep -q "^PermitRootLogin no" /etc/ssh/sshd_config 2>/dev/null; then
        sed -i 's/^PermitRootLogin no/PermitRootLogin yes/' /etc/ssh/sshd_config
    fi

    # 4. Восстанавливаем сеть
    log "Проверяю и восстанавливаю сетевые настройки..."
    local new_ip=$(cat /tmp/current_ip.txt 2>/dev/null)
    local new_gw=$(cat /tmp/current_gw.txt 2>/dev/null)
    local new_iface=$(cat /tmp/current_iface.txt 2>/dev/null)

    if [ -n "$new_ip" ] && [ -n "$new_gw" ] && [ -n "$new_iface" ]; then
        log "Восстанавливаю сеть: IP=$new_ip, GW=$new_gw, IFACE=$new_iface"
        
        # Проверяем, работает ли уже сеть
        if ! ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
            log_warn "Сеть не работает. Применяю сохранённые настройки..."
            
            ip link set "$new_iface" up 2>/dev/null
            ip addr add "$new_ip/24" dev "$new_iface" 2>/dev/null || ip addr add "$new_ip" dev "$new_iface" 2>/dev/null
            ip route add default via "$new_gw" 2>/dev/null
            
            # Прописываем в конфиг
            cat > /etc/network/interfaces << EOF
auto lo
iface lo inet loopback

auto $new_iface
iface $new_iface inet static
    address $new_ip
    netmask 255.255.255.0
    gateway $new_gw
EOF
            log_ok "Сеть настроена статически"
        else
            log_ok "Сеть уже работает"
        fi
    else
        # Если не удалось сохранить — пробуем DHCP
        log_warn "Не удалось определить настройки сети. Пробую DHCP..."
        ip link set eth0 up 2>/dev/null || true
        dhcpcd eth0 2>/dev/null || dhclient eth0 2>/dev/null || true
        
        cat > /etc/network/interfaces << 'EOF'
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
EOF
    fi

    # 5. Сбрасываем файрвол, чтобы не заблокировать себя
    log "Сбрасываю правила файрвола для безопасности..."
    iptables -F 2>/dev/null || true
    iptables -P INPUT ACCEPT 2>/dev/null || true
    iptables -P OUTPUT ACCEPT 2>/dev/null || true
    iptables -P FORWARD ACCEPT 2>/dev/null || true

    # 6. Пересобираем initramfs
    log "Пересобираю initramfs..."
    update-initramfs -u 2>/dev/null || true

    # 7. Очищаем machine-id
    if [ -f /etc/machine-id ]; then
        rm -f /etc/machine-id
        systemd-machine-id-setup 2>/dev/null || true
    fi

    # 8. Перезапускаем SSH
    log "Перезапускаю SSH..."
    systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null || true
    
    # Проверка
    if systemctl is-active --quiet ssh 2>/dev/null || systemctl is-active --quiet sshd 2>/dev/null; then
        log_ok "SSH работает"
    else
        log_error "SSH не запустился! Проверьте: sshd -t"
    fi

    # 9. Убираем временные файлы
    rm -f /tmp/current_ip.txt /tmp/current_gw.txt /tmp/current_iface.txt

    log_ok "Очистка и адаптация завершены"
}