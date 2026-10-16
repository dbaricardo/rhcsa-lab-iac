# Dominio 6 / systemd_timers: timer que nao dispara. Params: NAME CMD SCENARIO(bad_oncalendar|missing_service|not_enabled|wrong_unit)
ID=dyn-timer-troubleshoot
do_start() {
    unit_purge "$NAME"
    local svc=/etc/systemd/system/$NAME.service tmr=/etc/systemd/system/$NAME.timer
    printf '[Unit]\nDescription=Servico de laboratorio %s\n\n[Service]\nType=oneshot\nExecStart=%s\n' "$NAME" "$CMD" > "$svc"
    printf '[Unit]\nDescription=Timer de laboratorio %s\n\n[Timer]\nOnCalendar=*-*-* 03:30:00\nPersistent=true\n\n[Install]\nWantedBy=timers.target\n' "$NAME" > "$tmr"
    case "$SCENARIO" in
        bad_oncalendar)  sed -i 's/^OnCalendar=.*/OnCalendar=every day at 3am/' "$tmr" ;;
        missing_service) rm -f "$svc" ;;
        wrong_unit)      sed -i "s/^\[Timer\]/[Timer]\nUnit=${NAME}missing.service/" "$tmr" ;;
    esac
    systemctl daemon-reload
    [ "$SCENARIO" = not_enabled ] || systemctl enable --now "$NAME.timer" &>/dev/null
    echo "defeito injetado no timer $NAME.timer: $SCENARIO."
}
do_grade() {
    local svc=/etc/systemd/system/$NAME.service tmr=/etc/systemd/system/$NAME.timer
    [ -f "$tmr" ]; check $? "o arquivo $tmr existe"
    [ -f "$svc" ]; check $? "o arquivo $svc existe"
    [ "$(unit_key "$svc" ExecStart)" = "$CMD" ]; check $? "o servico executa $CMD"
    timer_state_ok "$NAME"
    local alvo; alvo=$(systemctl show "$NAME.timer" -p Unit --value 2>/dev/null)
    [ "$alvo" = "$NAME.service" ] && [ -f "/etc/systemd/system/$alvo" ]; check $? "o timer aciona uma unidade que existe (atual: ${alvo:-nenhuma})"
    [ -n "$(systemctl show "$NAME.timer" -p NextElapseUSecRealtime --value 2>/dev/null)" ]; check $? "o timer tem uma proxima execucao agendada (a expressao OnCalendar e valida)"
}
do_finish() { unit_purge "$NAME"; echo "limpeza: $NAME removido."; }
run "$@"
