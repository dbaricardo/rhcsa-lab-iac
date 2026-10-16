#!/bin/bash
# Item 10: localizar arquivos do usuario Simone e copiar para /root/found.
set -u
id Simone &>/dev/null && userdel -r Simone 2>/dev/null
useradd Simone
rm -rf /root/found
for d in /tmp/examsim10 /var/tmp/examsim10 /opt/examsim10 /home/Simone/docs; do
    mkdir -p "$d"
    f="$d/arquivo-simone-$RANDOM.txt"
    echo "propriedade de Simone" > "$f"
    chown Simone:Simone "$f"
done
echo "OK: usuario Simone criado com arquivos espalhados, /root/found removido -- item 10 pronto."
