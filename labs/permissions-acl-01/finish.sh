#!/bin/bash
# Ação inversa explícita, nunca reinvoca start.sh.
set -uo pipefail

rm -rf /dados/projeto-atlas
rmdir /dados >/dev/null 2>&1 || true
userdel -r carla >/dev/null 2>&1 || true
groupdel projeto-atlas >/dev/null 2>&1 || true

echo "Ambiente de 'permissions-acl-01' limpo em $(hostname -s)."
exit 0
