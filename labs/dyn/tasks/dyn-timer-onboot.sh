# Dominio 6 / systemd_timers: timer monotonico OnBootSec. Params: NAME CMD DELAY
ID=dyn-timer-onboot
do_start() { unit_purge "$NAME"; echo "$NAME.service e $NAME.timer nao existem."; }
do_grade() {
    timer_files_ok "$NAME" "$CMD"
    local mine; mine=$(unit_key "/etc/systemd/system/$NAME.timer" OnBootSec)
    [ -n "$mine" ] && [ "$(span_us "$mine")" = "$(span_us "$DELAY")" ]
    check $? "o OnBootSec equivale a $DELAY (atual: ${mine:-nao definido})"
    ! grep -qs '^OnCalendar=' "/etc/systemd/system/$NAME.timer"; check $? "o timer e monotonico: nao usa OnCalendar"
    timer_state_ok "$NAME"
}
do_finish() { unit_purge "$NAME"; echo "limpeza: $NAME removido."; }
run "$@"
