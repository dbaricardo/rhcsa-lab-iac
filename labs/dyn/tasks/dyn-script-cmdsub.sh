# Dominio 8 / scripting: substituicao de comando. Params: TASK(count_users|current_date|disk_free) SCRIPT
ID=dyn-script-cmdsub
do_start() { safe_rm "$SCRIPT"; echo "$SCRIPT nao existe."; }
do_grade() {
    script_checks "$SCRIPT"
    grep -Eq '[A-Za-z_][A-Za-z0-9_]*=("?\$\(|"?`)' "$SCRIPT" 2>/dev/null
    check $? "o script guarda a saida de um comando numa variavel (VAR=\$(comando))"
    case "$TASK" in
        count_users)
            run_script "$SCRIPT"
            n=$(wc -l < /etc/passwd)
            [ "$RC" -eq 0 ] && echo "$OUT" | grep -qwF "$n"; check $? "imprime o numero de usuarios do sistema ($n linhas em /etc/passwd)" ;;
        current_date)
            run_script "$SCRIPT"
            [ "$RC" -eq 0 ] && echo "$OUT" | grep -qxF "backup-$(date +%F).tar.gz"; check $? "imprime o nome backup-$(date +%F).tar.gz (a data de hoje)" ;;
        disk_free)
            run_script "$SCRIPT" 1
            [ "$(echo "$OUT" | squeeze)" = OK ]; check $? "com limite de 1 MB (sobra espaco): imprime OK (saida \"$OUT\")"
            run_script "$SCRIPT" 99999999
            [ "$(echo "$OUT" | squeeze)" = LOW ]; check $? "com limite de 99999999 MB (falta espaco): imprime LOW (saida \"$OUT\")" ;;
    esac
}
do_finish() { safe_rm "$SCRIPT"; echo "limpeza: $SCRIPT removido."; }
run "$@"
