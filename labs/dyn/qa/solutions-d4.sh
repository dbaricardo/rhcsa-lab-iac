# Solucoes e retratos das tarefas do dominio 4 (usado por validate-ported.sh).
# Cada solucao roda no host com os params da tarefa e com D, D2 e P1 ja definidos
# (disco de 2 GiB, disco de 3 GiB, particao 1 do primeiro).
NFS=workstation.lab.example.com
SOL[dyn-part-gpt-create]='parted -s $D mklabel gpt mkpart $PNAME ext4 1MiB $((SIZE+1))MiB; udevadm settle'
# parted pede confirmacao ao mexer numa particao montada: o aluno responde Yes
SOL[dyn-part-resize]='printf "Yes\n" | parted ---pretend-input-tty $D resizepart 1 ${NEWSIZE}MiB; udevadm settle; resize2fs ${D}1'
SOL[dyn-part-delete]='umount /mnt/dyndel$PNUM; sed -i "\#/mnt/dyndel$PNUM #d" /etc/fstab; parted -s $D rm $PNUM; systemctl daemon-reload; udevadm settle'
SOL[dyn-part-format-mount]='parted -s $D mklabel gpt mkpart primary $FSTYPE 1MiB $((SIZE+1))MiB; udevadm settle; mkfs.$FSTYPE -q ${D}1; mkdir -p $MOUNT; echo "UUID=$(blkid -s UUID -o value ${D}1) $MOUNT $FSTYPE defaults 0 0" >> /etc/fstab; systemctl daemon-reload; mount -a'
SOL[dyn-lvm-verify]='pvcreate $D; vgcreate $VG $D; lvcreate -L ${SIZE}M -n $LV $VG'
SOL[dyn-lvm-pv-create]='pvcreate $D'
SOL[dyn-lvm-vg-create]='pvcreate $D; vgcreate $VG $D'
SOL[dyn-lvm-lv-create]='if [ "$MODE" = ext ]; then lvcreate -l $EXT -n $LV $VG; else lvcreate -L ${SIZE}M -n $LV $VG; fi'
SOL[dyn-lvm-extend]='if [ "$MODE" = ext ]; then lvextend -l $TARGET $VG/$LV; else lvextend -L ${TARGET}M $VG/$LV; fi'
SOL[dyn-lvm-full-workflow]='pvcreate $D; vgcreate $VG $D; lvcreate -L ${SIZE}M -n $LV $VG; mkfs.xfs -q /dev/$VG/$LV; mkdir -p $MOUNT; echo "UUID=$(blkid -s UUID -o value /dev/$VG/$LV) $MOUNT xfs defaults 0 0" >> /etc/fstab; systemctl daemon-reload; mount -a'
SOL[dyn-lvm-extent-workflow]='pvcreate $D; vgcreate -s ${PE}M $VG $D; lvcreate -l $EXT -n $LV $VG; mkfs.xfs -q /dev/$VG/$LV; mkdir -p $MOUNT; echo "UUID=$(blkid -s UUID -o value /dev/$VG/$LV) $MOUNT xfs defaults 0 0" >> /etc/fstab; systemctl daemon-reload; mount -a'
SOL[dyn-lvm-vg-extend]='pvcreate $D2; vgextend $VG $D2'
SOL[dyn-lvm-lv-remove]='umount /mnt/$LV; sed -i "\#/mnt/$LV #d" /etc/fstab; systemctl daemon-reload; lvremove -f $VG/$LV'
SOL[dyn-lvm-lv-reduce]='umount /mnt/$LV; e2fsck -fy /dev/$VG/$LV; resize2fs /dev/$VG/$LV ${NEWSIZE}M; lvreduce -f -L ${NEWSIZE}M $VG/$LV; mount /dev/$VG/$LV /mnt/$LV'
SOL[dyn-fs-create]='mkfs.$FSTYPE -q ${D}1'
SOL[dyn-fs-mount]='mkdir -p $MOUNT; mount ${D}1 $MOUNT'
SOL[dyn-fs-persistent]='mkdir -p $MOUNT; echo "UUID=$(blkid -s UUID -o value ${D}1) $MOUNT $FSTYPE $OPTIONS 0 0" >> /etc/fstab; systemctl daemon-reload; mount -a'
SOL[dyn-fs-extend]='lvextend -r -L ${EXPECTED}M vg_prac$SUFFIX/lv_prac$SUFFIX'
SOL[dyn-fs-unmount]='fuser -k $MOUNT; sleep 1; umount $MOUNT'
SOL[dyn-fs-vfat]='mkfs.vfat ${D}1; mkdir -p $MOUNT; mount ${D}1 $MOUNT'
SOL[dyn-swap-partition]='parted -s $D mklabel gpt mkpart primary linux-swap 1MiB $((SIZE+1))MiB; udevadm settle; mkswap ${D}1; swapon ${D}1; echo "UUID=$(blkid -s UUID -o value ${D}1) none swap defaults 0 0" >> /etc/fstab; systemctl daemon-reload'
SOL[dyn-swap-file]='fallocate -l ${SIZE}M $SWAPFILE; chmod 600 $SWAPFILE; mkswap $SWAPFILE; swapon $SWAPFILE; echo "$SWAPFILE none swap defaults 0 0" >> /etc/fstab; systemctl daemon-reload'
SOL[dyn-swap-swappiness]='echo "vm.swappiness = $SWAPPINESS" > /etc/sysctl.d/99-swappiness.conf; sysctl -p /etc/sysctl.d/99-swappiness.conf'
SOL[dyn-nfs-mount]='mkdir -p $MOUNT; mount -t nfs '$NFS':/exports/dyn-nfsdata $MOUNT'
SOL[dyn-nfs-fstab]='mkdir -p $MOUNT; echo "'$NFS':/exports/dyn-nfsshared $MOUNT nfs defaults,_netdev 0 0" >> /etc/fstab; systemctl daemon-reload; mount -a'
SOL[dyn-autofs-basic]='if [ "$MAPTYPE" = indirect ]; then echo "$MOUNT /etc/auto.shares" > /etc/auto.master.d/shares.autofs; echo "* -rw '$NFS':$EXPORT/&" > /etc/auto.shares; else echo "/- /etc/auto.data" > /etc/auto.master.d/data.autofs; echo "$MOUNT -rw '$NFS':$EXPORT" > /etc/auto.data; fi; systemctl reset-failed autofs; systemctl enable --now autofs; systemctl restart autofs'
SOL[dyn-autofs-home]='echo "/home/guests /etc/auto.home" > /etc/auto.master.d/home.autofs; echo "* -rw,sync '$NFS':/exports/dyn-guests/&" > /etc/auto.home; systemctl reset-failed autofs; systemctl enable --now autofs; systemctl restart autofs'
# Retrato amplo do estado (cliente): deve voltar IGUAL depois do finish.
RETD4='lsblk -bnro NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT -e 7,11; md5sum < /etc/fstab; swapon --show=NAME,TYPE,SIZE --noheadings; vgs --noheadings -o vg_name; pvs --noheadings -o pv_name; cat /proc/sys/vm/swappiness; ls /etc/sysctl.d | tr "\n" " "; md5sum < /etc/sysctl.conf; ls /etc/auto.master.d 2>&1 | tr "\n" " "; ls /etc/auto.* 2>&1 | tr "\n" " "; systemctl is-enabled autofs 2>&1; systemctl is-active autofs 2>&1; findmnt -rn -t nfs,nfs4 | wc -l; ls /mnt /shares /data /home/guests /swapfile /var/swap /swap.img 2>&1 | tr "\n" " "; echo "rotulos=$(restorecon -nR /etc /srv /opt /var/www /usr/local 2>&1 | wc -l)"'
for id in dyn-part-gpt-create dyn-part-resize dyn-part-delete dyn-part-format-mount dyn-lvm-verify dyn-lvm-pv-create \
          dyn-lvm-vg-create dyn-lvm-lv-create dyn-lvm-extend dyn-lvm-full-workflow dyn-lvm-extent-workflow dyn-lvm-vg-extend \
          dyn-lvm-lv-remove dyn-lvm-lv-reduce dyn-fs-create dyn-fs-mount dyn-fs-persistent dyn-fs-extend dyn-fs-unmount dyn-fs-vfat \
          dyn-swap-partition dyn-swap-file dyn-swap-swappiness dyn-nfs-mount dyn-nfs-fstab dyn-autofs-basic dyn-autofs-home; do
    RET[$id]=$RETD4
done
# Retrato do servidor NFS (workstation), para as tarefas que exportam diretorios.
RETSRV='ls /etc/exports.d 2>&1 | tr "\n" " "; ls /exports 2>&1 | tr "\n" " "; systemctl is-active nfs-server 2>&1; exportfs -v | wc -l'
