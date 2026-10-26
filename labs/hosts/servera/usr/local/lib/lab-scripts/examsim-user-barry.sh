#!/bin/bash
# Item 13: criar usuario barry, UID 2112, senha atenorth.
set -u
id barry &>/dev/null && userdel -r barry 2>/dev/null
echo "OK: ambiente limpo para o item 13 (barry removido, se existia)."
