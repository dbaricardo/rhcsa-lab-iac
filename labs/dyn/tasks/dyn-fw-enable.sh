# Dominio 7 / firewall: religar o firewalld parado e desabilitado. Sem params
ID=dyn-fw-enable
do_start() { fw_save "$ID"; systemctl disable --now firewalld &>/dev/null; echo "firewalld parado e desabilitado."; }
do_grade() {
    [ "$(systemctl is-active firewalld 2>/dev/null)" = active ]; check $? "o firewalld esta em execucao"
    [ "$(systemctl is-enabled firewalld 2>/dev/null)" = enabled ]; check $? "o firewalld esta habilitado no boot"
    [ "$(firewall-cmd --state 2>/dev/null)" = running ]; check $? "firewall-cmd --state responde running"
}
do_finish() { fw_restore "$ID"; echo "limpeza: firewalld restaurado ($(systemctl is-active firewalld))."; }
run "$@"
