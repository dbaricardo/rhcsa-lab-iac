# Dominio 8 / scripting: if/else. Params: CONDITION(file_type|user_exists|service_status) SCRIPT
ID=dyn-script-cond
do_start() { safe_rm "$SCRIPT"; echo "$SCRIPT nao existe."; }
esperado() {  # esperado <rotulo> <saida certa> <args...>
    local rot=$1 certo=$2; shift 2
    run_script "$SCRIPT" "$@"
    [ "$(echo "$OUT" | squeeze)" = "$certo" ]; check $? "$rot: imprime \"$certo\" (saida: \"$(echo "$OUT" | head -1)\")"
}
do_grade() {
    script_checks "$SCRIPT"
    grep -Eq '(^|[[:space:];])if[[:space:]\[]' "$SCRIPT" 2>/dev/null && grep -Eq '(^|[[:space:];])fi($|[[:space:];])' "$SCRIPT" 2>/dev/null \
        && grep -Eq '(^|[[:space:];])(else|elif)($|[[:space:];])' "$SCRIPT" 2>/dev/null
    check $? "o script usa a estrutura if/then/else/fi"
    case "$CONDITION" in
        file_type)
            esperado "com um arquivo (/etc/hostname)" file /etc/hostname
            esperado "com um diretorio (/etc)" directory /etc
            esperado "com um caminho inexistente" "does not exist" /nao/existe/dyn ;;
        user_exists)
            esperado "com um usuario que existe (root)" exists root
            esperado "com um usuario que nao existe" "does not exist" usuario_dyn_inexistente ;;
        service_status)
            esperado "com um servico ativo (sshd)" running sshd
            esperado "com um servico que nao existe" "not running" servico-dyn-inexistente ;;
    esac
}
do_finish() { safe_rm "$SCRIPT"; echo "limpeza: $SCRIPT removido."; }
run "$@"
