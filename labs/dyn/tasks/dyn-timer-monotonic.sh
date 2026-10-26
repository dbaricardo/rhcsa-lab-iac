# Dominio 6 / systemd_timers: OnBootSec + OnUnitActiveSec. Params: NAME CMD INTERVAL
ID=dyn-timer-monotonic
do_start() { unit_purge "$NAME"; echo "$NAME.service e $NAME.timer nao existem."; }
do_grade() {
    timer_files_ok "$NAME" "$CMD"
    local f=/etc/systemd/system/$NAME.timer boot act
    boot=$(unit_key "$f" OnBootSec); act=$(unit_key "$f" OnUnitActiveSec)
    [ -n "$boot" ] && [ "$(span_us "$boot")" = "$(span_us "$INTERVAL")" ]; check $? "o OnBootSec equivale a $INTERVAL (atual: ${boot:-nao definido})"
    [ -n "$act" ] && [ "$(span_us "$act")" = "$(span_us "$INTERVAL")" ]; check $? "o OnUnitActiveSec equivale a $INTERVAL (atual: ${act:-nao definido})"
    timer_state_ok "$NAME"
}
do_finish() { unit_purge "$NAME"; echo "limpeza: $NAME removido."; }
run "$@"
