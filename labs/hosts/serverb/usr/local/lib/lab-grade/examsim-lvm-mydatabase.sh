#!/bin/bash
set -u
FAIL=0
check() { if [ "$1" -eq 0 ]; then echo "OK: $2"; else echo "FALHOU: $2"; FAIL=1; fi; }

vgs myvg &>/dev/null; check $? "VG myvg existe"

if vgs myvg &>/dev/null; then
    pe=$(vgs --noheadings -o vg_extent_size --units m myvg 2>/dev/null | tr -d ' ')
    echo "$pe" | grep -Eiq '^8(\.00)?m$'; check $? "PE size de myvg e 8MiB (atual: $pe)"

    lvs myvg/mydatabase &>/dev/null; check $? "LV mydatabase existe em myvg"

    if lvs myvg/mydatabase &>/dev/null; then
        extents=$(lvs --noheadings -o seg_size_pe myvg/mydatabase 2>/dev/null | tr -d ' ')
        [ "$extents" = "50" ]; check $? "LV mydatabase tem 50 extents (atual: $extents)"

        fstype=$(blkid -o value -s TYPE /dev/myvg/mydatabase 2>/dev/null)
        echo "$fstype" | grep -qi vfat; check $? "LV formatado em vfat (atual: $fstype)"
    fi
fi

mountpoint -q /database; check $? "/database montado"
SOURCE=$(findmnt -no SOURCE -T /database 2>/dev/null || true)
[ "$SOURCE" = "/dev/mapper/myvg-mydatabase" ] || [ "$SOURCE" = "/dev/myvg/mydatabase" ]
check $? "/database montado a partir de myvg/mydatabase (origem atual: ${SOURCE:-nenhuma})"
grep -Eq '^[^#]*(/dev/mapper/myvg-mydatabase|/dev/myvg/mydatabase)[[:space:]]+/database[[:space:]]' /etc/fstab
check $? "/etc/fstab referencia myvg/mydatabase em /database"

[ "$FAIL" -eq 0 ] && echo "RESULTADO: PASSOU" || echo "RESULTADO: FALHOU"
exit $FAIL
