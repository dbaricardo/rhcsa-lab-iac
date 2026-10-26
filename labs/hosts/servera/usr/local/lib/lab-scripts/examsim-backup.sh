#!/bin/bash
# Item 8: backup de /etc em /home/backup.tar.bz2.
set -u
rm -f /home/backup.tar.bz2
echo "OK: /home/backup.tar.bz2 removido (se existia) para o item 8."
