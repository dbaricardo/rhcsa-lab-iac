#!/bin/bash
set -u
FAIL=0
check() { if [ "$1" -eq 0 ]; then echo "OK: $2"; else echo "FALHOU: $2"; FAIL=1; fi; }

[ -f /home/backup.tar.bz2 ]; check $? "/home/backup.tar.bz2 existe"

if [ -f /home/backup.tar.bz2 ]; then
    file /home/backup.tar.bz2 | grep -qi bzip2
    check $? "arquivo e bzip2 valido"

    tar -tjf /home/backup.tar.bz2 2>/dev/null | grep -q 'etc/fstab$'
    check $? "backup contem etc/fstab"

    tar -tjf /home/backup.tar.bz2 2>/dev/null | grep -q 'etc/passwd$'
    check $? "backup contem etc/passwd"

    expected=$(mktemp)
    actual=$(mktemp)
    trap 'rm -f "$expected" "$actual"' EXIT
    # So' conta o que ja existia quando o backup foi feito (! -newer): arquivos
    # criados em /etc depois, por outros exercicios, nao podem reprovar.
    find /etc -type f ! -newer /home/backup.tar.bz2 -printf 'etc/%P\n' | sort > "$expected"
    tar -tjf /home/backup.tar.bz2 2>/dev/null | sed 's#^\./##; s#/$##' | sort > "$actual"
    faltando=$(comm -23 "$expected" "$actual" | wc -l)
    [ "$faltando" -eq 0 ]
    check $? "backup contem todos os arquivos regulares de /etc (faltando: $faltando)"
fi

[ "$FAIL" -eq 0 ] && echo "RESULTADO: PASSOU" || echo "RESULTADO: FALHOU"
exit $FAIL
