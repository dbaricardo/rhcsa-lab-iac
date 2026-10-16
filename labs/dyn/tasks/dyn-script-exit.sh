# Dominio 8 / scripting: codigos de saida. Params: SCRIPT
ID=dyn-script-exit
T=/tmp/dyn-exit
do_start() {
    safe_rm "$SCRIPT"; safe_rm "$T"
    mkdir -p "$T"; chmod 755 "$T"
    echo ok > "$T/ok.txt"; chmod 644 "$T/ok.txt"
    echo segredo > "$T/secret.txt"; chmod 600 "$T/secret.txt"; chown root:root "$T/secret.txt"
    echo "arquivos de teste prontos em $T (ok.txt legivel, secret.txt so de root)."
}
do_grade() {
    script_checks "$SCRIPT"
    run_script runuser -u nobody -- "$SCRIPT" "$T/ok.txt"
    [ "$RC" -eq 0 ] && [ -n "$OUT$ERR" ]; check $? "arquivo que existe e e legivel: mensagem e codigo 0 (codigo $RC)"
    run_script runuser -u nobody -- "$SCRIPT" "$T/nao-existe.txt"
    [ "$RC" -eq 1 ] && [ -n "$OUT$ERR" ]; check $? "arquivo que nao existe: mensagem e codigo 1 (codigo $RC)"
    run_script runuser -u nobody -- "$SCRIPT" "$T/secret.txt"
    [ "$RC" -eq 2 ] && [ -n "$OUT$ERR" ]; check $? "arquivo que existe mas nao e legivel: mensagem e codigo 2 (codigo $RC)"
}
do_finish() { safe_rm "$SCRIPT"; safe_rm "$T"; echo "limpeza: $SCRIPT e $T removidos."; }
run "$@"
