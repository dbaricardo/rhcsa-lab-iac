#!/bin/bash
# Item 14: (a) script newsearch em /usr/local/bin localiza SUID sob /usr
# entre 30k-50k e salva em /root/myoutput. (b) umask padrao de alex deixa
# arquivos novos r--r--r-- e diretorios novos r-xr-xr-x.
set -u
rm -f /usr/local/bin/newsearch /root/myoutput /usr/local/bin/.examsim14-fallback-suid
id alex &>/dev/null && userdel -r alex 2>/dev/null
useradd alex

nativos=$(find /usr -type f -perm -4000 -size +30k -size -50k 2>/dev/null | wc -l)
if [ "$nativos" -eq 0 ]; then
    dd if=/dev/zero of=/usr/local/bin/.examsim14-fallback-suid bs=1024 count=40 status=none
    chmod 4755 /usr/local/bin/.examsim14-fallback-suid
fi

echo "OK: ambiente pronto para o item 14 (alex recriado com umask padrao, newsearch/myoutput removidos)."
