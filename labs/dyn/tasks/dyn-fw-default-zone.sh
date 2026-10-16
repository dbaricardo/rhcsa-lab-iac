# Dominio 7 / firewall: trocar a zona padrao. Params: ZONE
ID=dyn-fw-default-zone
do_start() {
    fw_save "$ID"; systemctl is-active --quiet firewalld || systemctl start firewalld
    local outra=public; [ "$ZONE" = public ] && outra=work
    firewall-cmd --set-default-zone="$outra" &>/dev/null
    echo "a zona padrao e $(firewall-cmd --get-default-zone); a questao pede $ZONE."
}
do_grade() {
    [ "$(firewall-cmd --get-default-zone 2>/dev/null)" = "$ZONE" ]; check $? "a zona padrao e $ZONE (atual: $(firewall-cmd --get-default-zone 2>/dev/null))"
    grep -qx "DefaultZone=$ZONE" /etc/firewalld/firewalld.conf; check $? "DefaultZone=$ZONE esta no firewalld.conf (persistente)"
}
do_finish() { fw_restore "$ID"; echo "limpeza: zona padrao restaurada ($(firewall-cmd --get-default-zone 2>/dev/null))."; }
run "$@"
