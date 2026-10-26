# Dominio 7 / selinux: corrigir uma negacao (contexto ou booleano). Params: KIND(fcontext|boolean) TARGET TYPE
ID=dyn-selinux-denial
do_start() {
    if [ "$KIND" = fcontext ]; then
        fcontext_clear "$TARGET"; safe_rm "$TARGET"; tree_mk "$TARGET" tmp_t
        echo "$TARGET existe com o tipo errado (tmp_t)."
    else
        getsebool "$TARGET" &>/dev/null || { echo "ERRO: booleano $TARGET nao existe"; exit 1; }
        [ -e "$ST/$ID.orig" ] || semanage boolean -l | awk -v b="$TARGET" '$1==b' | sed -E 's/^[^(]*\(\s*[a-z]+\s*,\s*([a-z]+)\s*\).*/\1/' > "$ST/$ID.orig"
        setsebool -P "$TARGET" off
        echo "o booleano $TARGET esta desligado."
    fi
}
do_grade() {
    if [ "$KIND" = fcontext ]; then
        [ -d "$TARGET" ]; check $? "o diretorio $TARGET existe"
        tree_type_ok "$TARGET" "$TYPE"; check $? "o diretorio e o conteudo tem o tipo $TYPE (atual: $(ctx_type "$TARGET"))"
        [ "$(pol_type "$TARGET")" = "$TYPE" ]; check $? "a politica define $TYPE para $TARGET: a correcao e persistente e sobrevive a um relabel (atual na politica: $(pol_type "$TARGET"))"
    else
        [ "$(getsebool "$TARGET" | awk '{print $3}')" = on ]; check $? "o booleano $TARGET esta ligado agora"
        semanage boolean -l | awk -v b="$TARGET" '$1==b' | sed -E 's/^[^(]*\(\s*[a-z]+\s*,\s*([a-z]+)\s*\).*/\1/' | grep -qx on
        check $? "o booleano $TARGET esta ligado de forma persistente (setsebool -P)"
    fi
}
do_finish() {
    if [ "$KIND" = fcontext ]; then
        fcontext_clear "$TARGET"; tree_rm "$TARGET"
    elif [ -s "$ST/$ID.orig" ]; then
        setsebool -P "$TARGET" "$(cat "$ST/$ID.orig")"; rm -f "${ST:?}/${ID:?}.orig"
    fi
    echo "limpeza: $TARGET restaurado."
}
run "$@"
