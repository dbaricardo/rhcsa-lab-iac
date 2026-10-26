# Dominio 7 / firewall: configuracao completa. Params: ZONE SERVICES PORTS
ID=dyn-fw-full-setup
do_start() {
    fw_save "$ID"
    local outra=public; [ "$ZONE" = public ] && outra=work
    systemctl disable --now firewalld &>/dev/null
    sed -i -E "s/^DefaultZone=.*/DefaultZone=$outra/" /etc/firewalld/firewalld.conf
    echo "firewalld parado e desabilitado; a zona padrao e $outra."
}
do_grade() {
    [ "$(systemctl is-active firewalld 2>/dev/null)" = active ] && [ "$(systemctl is-enabled firewalld 2>/dev/null)" = enabled ]
    check $? "o firewalld esta em execucao e habilitado no boot"
    [ "$(firewall-cmd --get-default-zone 2>/dev/null)" = "$ZONE" ]; check $? "a zona padrao e $ZONE (atual: $(firewall-cmd --get-default-zone 2>/dev/null))"
    local s p
    for s in $SERVICES; do
        [ "$(firewall-cmd --permanent --zone="$ZONE" --query-service="$s" 2>/dev/null)" = yes ] && [ "$(firewall-cmd --zone="$ZONE" --query-service="$s" 2>/dev/null)" = yes ]
        check $? "o servico $s esta na zona $ZONE (permanente e ativo)"
    done
    for p in $PORTS; do
        [ "$(firewall-cmd --permanent --zone="$ZONE" --query-port="$p" 2>/dev/null)" = yes ] && [ "$(firewall-cmd --zone="$ZONE" --query-port="$p" 2>/dev/null)" = yes ]
        check $? "a porta $p esta aberta na zona $ZONE (permanente e ativa)"
    done
}
do_finish() { fw_restore "$ID"; echo "limpeza: configuracao do firewalld restaurada."; }
run "$@"
