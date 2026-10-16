# Dominio 8 / scripting: script com argumentos. Params: TASK(greet|file_check|user_info) SCRIPT
ID=dyn-script-args
do_start() { safe_rm "$SCRIPT"; echo "$SCRIPT nao existe."; }
do_grade() {
    script_checks "$SCRIPT"
    run_script "$SCRIPT"
    [ "$RC" -eq 1 ] && [ -n "$ERR" ]; check $? "sem argumento: mensagem de erro no stderr e codigo de saida 1 (codigo $RC)"
    case "$TASK" in
        greet)
            run_script "$SCRIPT" Maria
            [ "$RC" -eq 0 ] && echo "$OUT" | grep -q 'Maria'; check $? "com o argumento Maria: imprime uma saudacao com o nome e termina com 0" ;;
        file_check)
            run_script "$SCRIPT" /etc/passwd
            [ "$RC" -eq 0 ] && [ "$(echo "$OUT" | squeeze)" = exists ]; check $? "com um arquivo que existe: imprime exists (codigo $RC, saida \"$OUT\")"
            run_script "$SCRIPT" /nao/existe/dyn
            [ "$(echo "$OUT" | squeeze)" = "not found" ]; check $? "com um arquivo que nao existe: imprime not found (saida \"$OUT\")" ;;
        user_info)
            run_script "$SCRIPT" root
            [ "$RC" -eq 0 ] && [ "$OUT" = "$(getent passwd root)" ]; check $? "com o usuario root: imprime a linha dele do /etc/passwd"
            run_script "$SCRIPT" usuario_dyn_inexistente
            [ "$RC" -eq 1 ]; check $? "com um usuario que nao existe: termina com codigo 1 (codigo $RC)" ;;
    esac
}
do_finish() { safe_rm "$SCRIPT"; echo "limpeza: $SCRIPT removido."; }
run "$@"
