# Dominio 2 / journalctl: limites de tamanho. Params: MAXUSE RUNMAX
ID=dyn-journal-size
CONF=/etc/systemd/journald.conf
do_start() {
    conf_save "$CONF" "$ID"; dropins_save "$ID"
    [ -e "$CONF" ] && sed -i -E '/^[#[:space:]]*(SystemMaxUse|RuntimeMaxUse)=/d' "$CONF"
    echo "limites de tamanho do journal removidos do journald.conf."
}
do_grade() {
    sys=$(journal_value SystemMaxUse); run_=$(journal_value RuntimeMaxUse)
    [ "$sys" = "$MAXUSE" ]; check $? "SystemMaxUse=$MAXUSE ativo (atual: ${sys:-nao definido})"
    [ "$run_" = "$RUNMAX" ]; check $? "RuntimeMaxUse=$RUNMAX ativo (atual: ${run_:-nao definido})"
    systemctl is-active --quiet systemd-journald; check $? "systemd-journald ativo"
}
do_finish() {
    conf_restore "$CONF" "$ID"; dropins_restore "$ID"
    journal_restart
    echo "limpeza: configuracao original do journald restaurada."
}
run "$@"
