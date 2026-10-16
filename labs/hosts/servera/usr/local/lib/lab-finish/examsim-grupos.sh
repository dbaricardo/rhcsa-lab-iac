#!/bin/bash
set -u
for u in natasha harry sarah; do
    id "$u" &>/dev/null && userdel -r "$u" 2>/dev/null
done
getent group sysadmin &>/dev/null && groupdel sysadmin
echo "OK: item 5 limpo (grupo sysadmin + natasha/harry/sarah removidos)."
