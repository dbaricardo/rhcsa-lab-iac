#!/bin/bash
set -u
FAIL=0
check() { if [ "$1" -eq 0 ]; then echo "OK: $2"; else echo "FALHOU: $2"; FAIL=1; fi; }

rpm -q logger &>/dev/null; check $? "pacote logger instalado (via timer.repo)"
[ -x /usr/local/bin/logger ]; check $? "/usr/local/bin/logger existe e e executavel"

unit_svc=$(systemctl list-units --all --type=service --no-legend 2>/dev/null | awk '{print $1}' | grep -i 'examsim15\|logger' | head -1)
[ -n "$unit_svc" ]; check $? "existe unit systemd .service para o script (encontrado: '$unit_svc')"

unit_timer=$(systemctl list-units --all --type=timer --no-legend 2>/dev/null | awk '{print $1}' | grep -i 'examsim15\|logger' | head -1)
[ -n "$unit_timer" ]; check $? "existe unit systemd .timer associado (encontrado: '$unit_timer')"

if [ -n "$unit_timer" ]; then
    systemctl is-enabled "$unit_timer" &>/dev/null
    check $? "timer $unit_timer habilitado para iniciar no boot"
    systemctl is-active "$unit_timer" &>/dev/null
    check $? "timer $unit_timer ativo"
    timer_definition=$(systemctl cat "$unit_timer" 2>/dev/null)
    if echo "$timer_definition" | grep -Eq '^[[:space:]]*(OnUnitActiveSec|OnUnitInactiveSec)[[:space:]]*=[[:space:]]*(1min|60s)(ec)?[[:space:]]*$' || \
       echo "$timer_definition" | grep -Eq '^[[:space:]]*OnCalendar[[:space:]]*=.*\*:\*'; then
        interval_ok=0
    else
        interval_ok=1
    fi
    check "$interval_ok" "timer $unit_timer agenda a execucao a cada minuto"
fi

if [ -n "$unit_svc" ]; then
    systemctl start "$unit_svc" &>/dev/null
    sleep 1
fi

[ -s /var/tmp/ex200 ]; check $? "/var/tmp/ex200 recebeu log do script"
[ -s /root/lookup_directory/ex200 ]; check $? "/root/lookup_directory/ex200 recebeu a saida do script"

[ -f /var/tmp/fstab ]; check $? "/var/tmp/fstab existe"
[ ! -f /var/tmp/fstab ] || cmp -s /etc/fstab /var/tmp/fstab
check $? "/var/tmp/fstab e copia fiel de /etc/fstab"

if [ -f /var/tmp/fstab ]; then
    acl=$(getfacl -p /var/tmp/fstab 2>/dev/null)
    owner=$(stat -c %U:%G /var/tmp/fstab)
    [ "$owner" = "root:root" ]; check $? "/var/tmp/fstab pertence a root:root (atual: $owner)"
    echo "$acl" | grep -Eq '^user::rw-$'; check $? "dono sem execucao (user::rw-)"
    echo "$acl" | grep -Eq '^group::r--$|^group::---$'; check $? "grupo sem execucao"
    echo "$acl" | grep -Eq '^user:natasha:rw-$'; check $? "ACL natasha: rw-"
    echo "$acl" | grep -Eq '^user:harry:---$'; check $? "ACL harry: --- (sem acesso)"
    echo "$acl" | grep -Eq '^mask::rw-$'; check $? "mask nao restringe o rw- concedido a natasha"
    echo "$acl" | grep -Eq '^other::r--$'; check $? "outros (atuais e futuros) tem leitura via other::r--"
else
    echo "FALHOU: /var/tmp/fstab nao existe"
    FAIL=1
fi

[ "$FAIL" -eq 0 ] && echo "RESULTADO: PASSOU" || echo "RESULTADO: FALHOU"
exit $FAIL
