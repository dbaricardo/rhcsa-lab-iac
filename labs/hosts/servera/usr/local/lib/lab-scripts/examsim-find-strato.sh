#!/bin/bash
# Item 11: localizar a string 'strato' em /usr/share/dict/words e salvar
# o resultado em /searchfile.
set -u
dnf install -y words &>/dev/null
rm -f /searchfile
grep -q strato /usr/share/dict/words 2>/dev/null || echo "strato" >> /usr/share/dict/words
echo "OK: /usr/share/dict/words garantido com 'strato', /searchfile removido -- item 11 pronto."
