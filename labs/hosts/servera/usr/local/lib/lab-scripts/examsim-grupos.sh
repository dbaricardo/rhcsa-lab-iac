#!/bin/bash
# Item 5 do simulado: grupo sysadmin com natasha/harry membros secundarios,
# sarah sem acesso ao grupo e sem shell interativo, todos com senha atenorth.
set -u
for u in natasha harry sarah; do
    id "$u" &>/dev/null && userdel -r "$u" 2>/dev/null
done
getent group sysadmin &>/dev/null && groupdel sysadmin
echo "OK: ambiente limpo para o item 5 (grupo sysadmin + natasha/harry/sarah)."
