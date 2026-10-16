# Dominio 8 / scripting: script basico. Params: PURPOSE(list_users|disk_usage|system_info) SCRIPT
ID=dyn-script-basic
do_start() { safe_rm "$SCRIPT"; echo "$SCRIPT nao existe."; }
do_grade() {
    script_checks "$SCRIPT"
    run_script "$SCRIPT"
    check_rc() { [ "$RC" -eq 0 ]; check $? "o script termina com sucesso (codigo $RC)"; }
    check_rc
    case "$PURPOSE" in
        list_users)
            [ "$(echo "$OUT" | sort)" = "$(cut -d: -f1 /etc/passwd | sort)" ]
            check $? "a saida e a lista de usuarios de /etc/passwd, um por linha, sem mais nada" ;;
        disk_usage)
            echo "$OUT" | grep -Eq '^[0-9.,]+[KMGTP]?[[:space:]]+/home$'
            check $? "a saida e o resumo de uso de disco de /home, legivel por humanos (como du -sh /home)" ;;
        system_info)
            [ "$(echo "$OUT" | sed -n 1p)" = "$(hostname)" ] && echo "$OUT" | sed -n 2p | grep -qxF "$(uname -r)"
            check $? "a saida tem o hostname na 1a linha e a versao do kernel na 2a" ;;
    esac
}
do_finish() { safe_rm "$SCRIPT"; echo "limpeza: $SCRIPT removido."; }
run "$@"
