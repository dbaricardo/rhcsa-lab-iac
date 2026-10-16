# Dominio 8 / scheduling: script em /etc/cron.daily|hourly|weekly. Params: CRONDIR SCRIPT FREQ
ID=dyn-cron-dir
do_start() { safe_rm "$CRONDIR/$SCRIPT"; echo "$CRONDIR/$SCRIPT nao existe."; }
do_grade() {
    local f=$CRONDIR/$SCRIPT
    [ -f "$f" ]; check $? "o script $f existe"
    [ -x "$f" ]; check $? "o script e executavel"
    head -1 "$f" 2>/dev/null | grep -qx '#!/bin/bash'; check $? "o script comeca com #!/bin/bash"
    bash -n "$f" 2>/dev/null; check $? "o script tem sintaxe valida"
    run-parts --test "$CRONDIR" 2>/dev/null | grep -qxF "$f"
    check $? "o run-parts vai executar o script (nomes com ponto, como .sh, sao ignorados)"
}
do_finish() { safe_rm "$CRONDIR/$SCRIPT"; echo "limpeza: $CRONDIR/$SCRIPT removido."; }
run "$@"
