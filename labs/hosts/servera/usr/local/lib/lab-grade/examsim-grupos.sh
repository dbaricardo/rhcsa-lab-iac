#!/bin/bash
set -u
source /usr/local/lib/lab-common.sh
FAIL=0
check() { if [ "$1" -eq 0 ]; then echo "OK: $2"; else echo "FALHOU: $2"; FAIL=1; fi; }

getent group sysadmin &>/dev/null; check $? "grupo sysadmin existe"

id natasha &>/dev/null && [ "$(id -gn natasha)" != "sysadmin" ] && id -nG natasha | grep -qw sysadmin
check $? "natasha e membro secundario de sysadmin"

id harry &>/dev/null && [ "$(id -gn harry)" != "sysadmin" ] && id -nG harry | grep -qw sysadmin
check $? "harry e membro secundario de sysadmin"

id sarah &>/dev/null; check $? "usuario sarah existe"

if id sarah &>/dev/null; then
    ! id -nG sarah | grep -qw sysadmin
    check $? "sarah NAO e membro de sysadmin"

    shell=$(getent passwd sarah | cut -d: -f7)
    case "$shell" in
        */nologin|*/false) check 0 "sarah sem shell interativo ($shell)" ;;
        *) echo "FALHOU: sarah sem shell interativo (atual: $shell)"; FAIL=1 ;;
    esac
fi

for u in natasha harry sarah; do
    if id "$u" &>/dev/null; then
        verifica_senha "$u" atenorth
        check $? "senha de $u e 'atenorth'"
    fi
done

[ "$FAIL" -eq 0 ] && echo "RESULTADO: PASSOU" || echo "RESULTADO: FALHOU"
exit $FAIL
