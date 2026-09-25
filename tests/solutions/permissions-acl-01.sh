#!/bin/bash
# Solução de referência para permissions-acl-01 (host: servera). Idempotente.
# grade.sh exige que carla NÃO pertença ao grupo projeto-atlas -- o acesso é
# resolvido só via ACL (getfacl), nunca via grupo secundário.
set -euo pipefail

DIR=/dados/projeto-atlas

getent group projeto-atlas >/dev/null || groupadd projeto-atlas

mkdir -p "$DIR"
chown root:projeto-atlas "$DIR"
chmod 2770 "$DIR"
setfacl -m u:carla:rwx "$DIR"
setfacl -d -m u:carla:rwx "$DIR"

echo "permissions-acl-01: solução aplicada em $(hostname -s)."
