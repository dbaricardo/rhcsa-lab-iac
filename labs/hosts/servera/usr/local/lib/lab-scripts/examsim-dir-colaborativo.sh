#!/bin/bash
# Item 6: /common/admin com grupo sysadmin, acesso restrito ao grupo,
# SGID para heranca automatica do grupo em arquivos novos.
set -u
rm -rf /common/admin
getent group sysadmin &>/dev/null || groupadd sysadmin
echo "OK: ambiente limpo para o item 6 (/common/admin removido, demais dados preservados)."
