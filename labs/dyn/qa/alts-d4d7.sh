# Caminhos alternativos do aluno: LVM, particionamento, filesystems, NFS/autofs e fcontext.
# Carregado por validate-alt.sh (usa a funcao alt <id> <<'EOS'). D, D2 e P1 vem do PRE do host_cmd.

# ---- particionamento ----
alt dyn-part-gpt-create <<'EOS'
parted -s $D mklabel gpt; parted -s $D mkpart $PNAME 1MiB $((SIZE+1))MiB; udevadm settle
EOS
alt dyn-part-gpt-create <<'EOS'
printf "g\nn\n1\n\n+${SIZE}M\nx\nn\n$PNAME\nr\nw\n" | fdisk $D; udevadm settle
EOS
alt dyn-part-resize <<'EOS'
echo ",${NEWSIZE}MiB" | sfdisk -N 1 --no-reread $D; partx -u $D; udevadm settle; resize2fs ${D}1
EOS
alt dyn-part-resize <<'EOS'
mp=$(findmnt -no TARGET ${D}1); umount ${D}1; parted -s $D resizepart 1 ${NEWSIZE}MiB; udevadm settle; e2fsck -fy ${D}1; resize2fs ${D}1; mount ${D}1 $mp
EOS
alt dyn-part-delete <<'EOS'
umount ${D}$PNUM; sed -i "\#/mnt/dyndel$PNUM#d" /etc/fstab; sfdisk --delete $D $PNUM; partprobe $D; systemctl daemon-reload; udevadm settle
EOS
alt dyn-part-delete <<'EOS'
umount /mnt/dyndel$PNUM; grep -v "/mnt/dyndel$PNUM " /etc/fstab > /root/fstab.new; cat /root/fstab.new > /etc/fstab; rm -f /root/fstab.new
printf "d\n$PNUM\nw\n" | fdisk $D; systemctl daemon-reload; udevadm settle
EOS
alt dyn-part-format-mount <<'EOS'
printf "g\nn\n1\n\n+${SIZE}M\nw\n" | fdisk $D; udevadm settle
if [ $FSTYPE = xfs ]; then mkfs.xfs -f -q ${D}1; else mkfs -t $FSTYPE -q ${D}1; fi
mkdir -p $MOUNT; udevadm settle; echo "UUID=$(lsblk -no UUID ${D}1)	$MOUNT	$FSTYPE	defaults	0 0" >> /etc/fstab; systemctl daemon-reload; mount $MOUNT
EOS
alt dyn-part-format-mount <<'EOS'
parted -s $D mklabel gpt mkpart primary $FSTYPE 1MiB $((SIZE+1))MiB; udevadm settle
mkfs.$FSTYPE -q ${D}1 2>/dev/null || mkfs.$FSTYPE -f -q ${D}1
mkdir -p $MOUNT; mount ${D}1 $MOUNT; echo "UUID=$(blkid -s UUID -o value ${D}1) $MOUNT $FSTYPE defaults 0 0" >> /etc/fstab; systemctl daemon-reload
EOS

# ---- LVM ----
alt dyn-lvm-pv-create <<'EOS'
pvcreate -y $D
EOS
alt dyn-lvm-vg-create <<'EOS'
vgcreate $VG $D
EOS
alt dyn-lvm-vg-create <<'EOS'
pvcreate -f $D; vgcreate --physicalextentsize 4M $VG $D
EOS
alt dyn-lvm-vg-extend <<'EOS'
vgextend $VG $D2
EOS
alt dyn-lvm-lv-create <<'EOS'
if [ "$MODE" = ext ]; then lvcreate --extents $EXT --name $LV $VG; else lvcreate --size ${SIZE}m --name $LV $VG; fi
EOS
alt dyn-lvm-lv-create <<'EOS'
if [ "$MODE" = ext ]; then lvcreate -L $((EXT*PE))M -n $LV $VG; else lvcreate -l $((SIZE/PE)) -n $LV $VG; fi
EOS
alt dyn-lvm-extend <<'EOS'
cur=$(lvs --noheadings --nosuffix --units m -o lv_size $VG/$LV | awk '{printf "%d",$1}')
if [ "$MODE" = ext ]; then lvextend -l +$((TARGET-cur/PE)) $VG/$LV; else lvextend -L +$((TARGET-cur))M $VG/$LV; fi
EOS
alt dyn-lvm-extend <<'EOS'
if [ "$MODE" = ext ]; then lvresize -l $TARGET /dev/$VG/$LV; else lvresize -L ${TARGET}M /dev/mapper/$VG-$LV; fi
EOS
alt dyn-lvm-lv-remove <<'EOS'
umount /dev/$VG/$LV; grep -v " /mnt/$LV " /etc/fstab > /root/fstab.new; cat /root/fstab.new > /etc/fstab; rm -f /root/fstab.new; systemctl daemon-reload; lvremove -y /dev/$VG/$LV
EOS
alt dyn-lvm-lv-reduce <<'EOS'
lvreduce -r -y -L ${NEWSIZE}M $VG/$LV
EOS
alt dyn-lvm-lv-reduce <<'EOS'
umount /mnt/$LV; e2fsck -f -y /dev/mapper/$VG-$LV; lvresize -r -y -L ${NEWSIZE}M $VG/$LV; mount /mnt/$LV 2>/dev/null || mount /dev/$VG/$LV /mnt/$LV
EOS
alt dyn-lvm-full-workflow <<'EOS'
vgcreate $VG $D; lvcreate --name $LV --size ${SIZE}M $VG; mkfs -t xfs /dev/mapper/$VG-$LV; mkdir -p $MOUNT
echo "/dev/mapper/$VG-$LV $MOUNT xfs defaults 0 0" >> /etc/fstab; systemctl daemon-reload; mount $MOUNT
EOS
alt dyn-lvm-extent-workflow <<'EOS'
vgcreate --physicalextentsize ${PE}M $VG $D; lvcreate --extents $EXT --name $LV $VG; mkfs.xfs /dev/$VG/$LV; mkdir -p $MOUNT
udevadm settle; echo "UUID=$(lsblk -no UUID /dev/$VG/$LV) $MOUNT xfs defaults 0 0" >> /etc/fstab; systemctl daemon-reload; mount -a
EOS
alt dyn-fs-extend <<'EOS'
lvresize -r -L ${EXPECTED}M vg_prac$SUFFIX/lv_prac$SUFFIX
EOS
alt dyn-fs-extend <<'EOS'
lvextend -L ${EXPECTED}M /dev/vg_prac$SUFFIX/lv_prac$SUFFIX; fsadm resize /dev/vg_prac$SUFFIX/lv_prac$SUFFIX
EOS

# ---- filesystems ----
alt dyn-fs-create <<'EOS'
mkfs -t $FSTYPE ${D}1
EOS
alt dyn-fs-mount <<'EOS'
mkdir -p $MOUNT; mount -t $(blkid -s TYPE -o value ${D}1) ${D}1 $MOUNT
EOS
alt dyn-fs-persistent <<'EOS'
mkdir -p $MOUNT; udevadm settle; echo "UUID=$(lsblk -no UUID ${D}1)	$MOUNT	$FSTYPE	$OPTIONS	0	0" >> /etc/fstab; systemctl daemon-reload; mount $MOUNT
EOS
alt dyn-fs-unmount <<'EOS'
umount -l $MOUNT
EOS

# ---- NFS / autofs ----
alt dyn-nfs-mount <<'EOS'
mkdir -p $MOUNT; mount -t nfs4 workstation.lab.example.com:/exports/dyn-nfsdata $MOUNT
EOS
alt dyn-nfs-mount <<'EOS'
mkdir -p $MOUNT; mount workstation.lab.example.com:/exports/dyn-nfsdata $MOUNT
EOS
alt dyn-nfs-mount <<'EOS'
mkdir -p $MOUNT; mount -o rw,vers=4 $(getent hosts workstation.lab.example.com | awk '{print $1; exit}'):/exports/dyn-nfsdata $MOUNT
EOS
alt dyn-nfs-fstab <<'EOS'
mkdir -p $MOUNT; echo "workstation.lab.example.com:/exports/dyn-nfsshared $MOUNT nfs4 rw,_netdev 0 0" >> /etc/fstab; systemctl daemon-reload; mount $MOUNT
EOS
alt dyn-nfs-fstab <<'EOS'
mkdir -p $MOUNT; echo "$(getent hosts workstation.lab.example.com | awk '{print $1; exit}')	/exports/dyn-nfsshared	$MOUNT	nfs	defaults,_netdev	0	0" | awk '{print $1":"$2"\t"$3"\t"$4"\t"$5"\t"$6"\t"$7}' >> /etc/fstab; systemctl daemon-reload; mount -a
EOS
alt dyn-autofs-basic <<'EOS'
if [ "$MAPTYPE" = indirect ]; then
  echo "$MOUNT /etc/auto.nfsmap --timeout=60" > /etc/auto.master.d/nfs.autofs; echo "*	-fstype=nfs4,rw	workstation.lab.example.com:$EXPORT/&" > /etc/auto.nfsmap
else
  echo "/- /etc/auto.nfsdirect" > /etc/auto.master.d/nfs.autofs; echo "$MOUNT	-fstype=nfs4,rw	workstation.lab.example.com:$EXPORT" > /etc/auto.nfsdirect
fi
systemctl reset-failed autofs; systemctl enable --now autofs; systemctl reload autofs 2>/dev/null || systemctl restart autofs
EOS
alt dyn-autofs-basic <<'EOS'
if [ "$MAPTYPE" = indirect ]; then
  echo "$MOUNT /etc/auto.shares2" >> /etc/auto.master; echo "* -rw workstation.lab.example.com:$EXPORT/&" > /etc/auto.shares2
else
  echo "/- /etc/auto.data2" >> /etc/auto.master; echo "$MOUNT -rw workstation.lab.example.com:$EXPORT" > /etc/auto.data2
fi
systemctl reset-failed autofs; systemctl enable autofs; systemctl start autofs; systemctl restart autofs
EOS
alt dyn-autofs-home <<'EOS'
echo "/home/guests /etc/auto.guests" >> /etc/auto.master; echo "* -fstype=nfs4,rw,sync workstation.lab.example.com:/exports/dyn-guests/&" > /etc/auto.guests
systemctl reset-failed autofs; systemctl enable --now autofs; systemctl restart autofs
EOS

# ---- SELinux fcontext ----
alt dyn-selinux-context <<'EOS'
chcon -R -t $TYPE $DIR; semanage fcontext -a -t $TYPE "$DIR(/.*)?"
EOS
alt dyn-selinux-context <<'EOS'
semanage fcontext --add --type $TYPE "$DIR(/.*)?"; restorecon -Rv $DIR
EOS
alt dyn-selinux-context <<'EOS'
semanage fcontext -a -t $TYPE "$DIR"; semanage fcontext -a -t $TYPE "$DIR/.*"; restorecon -R $DIR
EOS
alt dyn-selinux-restorecon <<'EOS'
restorecon -R $DIR
EOS
alt dyn-selinux-restorecon <<'EOS'
restorecon -RF $DIR
EOS
