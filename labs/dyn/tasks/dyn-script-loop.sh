# Dominio 8 / scripting: lacos for/while. Params: LOOP(for_files|for_users|for_args) SCRIPT
ID=dyn-script-loop
do_start() { safe_rm "$SCRIPT"; echo "$SCRIPT nao existe."; }
do_grade() {
    script_checks "$SCRIPT"
    grep -Eq '(^|[[:space:];])(for|while|until)[[:space:](]' "$SCRIPT" 2>/dev/null && grep -Eq '(^|[[:space:];])done($|[[:space:];])' "$SCRIPT" 2>/dev/null
    check $? "o script usa um laco (for/while/until ... done)"
    case "$LOOP" in
        for_files)
            run_script "$SCRIPT"
            n=$(ls /etc/*.conf 2>/dev/null | wc -l)
            [ "$RC" -eq 0 ] && echo "$OUT" | grep -qwF "$n"; check $? "imprime a quantidade de arquivos .conf diretamente em /etc ($n)" ;;
        for_users)
            run_script "$SCRIPT"
            [ "$RC" -eq 0 ] && [ "$(echo "$OUT" | sort)" = "$(cut -d: -f1 /etc/passwd | sort)" ]
            check $? "imprime cada usuario de /etc/passwd em uma linha, sem mais nada" ;;
        for_args)
            run_script "$SCRIPT" um "dois e meio" tres
            [ "$RC" -eq 0 ] && [ "$OUT" = "$(printf 'um\ndois e meio\ntres')" ]
            check $? "imprime cada argumento em uma linha (um / dois e meio / tres)" ;;
    esac
}
do_finish() { safe_rm "$SCRIPT"; echo "limpeza: $SCRIPT removido."; }
run "$@"
