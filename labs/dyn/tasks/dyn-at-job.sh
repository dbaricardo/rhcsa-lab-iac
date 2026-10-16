# Dominio 8 / scheduling: tarefa unica com at. Params: SPEC SECS SPECDESC (comando fixo)
ID=dyn-at-job
CMDTXT='At job executed'
do_start() {
    date +%s > "$ST/$ID.t0"
    atq | awk '{print $1}' | sort > "$ST/$ID.jobs"
    rm -f /tmp/atjob.log
    systemctl is-active --quiet atd || systemctl start atd
    echo "nenhum job novo do at; atd ativo."
}
do_grade() {
    systemctl is-active --quiet atd; check $? "o servico atd esta ativo"
    local j t0 now achou=1 when ep ok=1
    t0=$(cat "$ST/$ID.t0" 2>/dev/null || echo 0); now=$(date +%s)
    for j in $(atq | awk '{print $1}'); do
        grep -qx "$j" "$ST/$ID.jobs" 2>/dev/null && continue
        at -c "$j" 2>/dev/null | grep -qF "$CMDTXT" || continue
        achou=0
        when=$(atq | awk -v j="$j" '$1==j{print $2,$3,$4,$5,$6}')
        ep=$(date -d "$when" +%s 2>/dev/null || echo 0)
        [ "$ep" -ge $((t0 + SECS - 120)) ] && [ "$ep" -le $((now + SECS + 120)) ] && ok=0
    done
    check $achou "existe um job novo do at que executa: echo \"$CMDTXT\" >> /tmp/atjob.log"
    check $ok "o job esta agendado para $SPECDESC (at \"$SPEC\")"
}
do_finish() {
    local j
    for j in $(atq | awk '{print $1}'); do
        grep -qx "$j" "$ST/$ID.jobs" 2>/dev/null || atrm "$j" 2>/dev/null
    done
    rm -f "${ST:?}/${ID:?}.jobs" "${ST:?}/${ID:?}.t0" /tmp/atjob.log
    echo "limpeza: jobs novos do at removidos."
}
run "$@"
