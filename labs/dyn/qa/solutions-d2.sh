# Solucoes e retratos das tarefas do dominio 2 (boot, recuperacao e journal).
# Usado por validate-ported.sh. Nenhuma solucao reinicia a VM.
RETBOOT='md5sum /etc/default/grub /boot/grub2/grub.cfg /boot/grub2/grubenv; md5sum < /etc/kernel/cmdline; cat /boot/loader/entries/*.conf | md5sum; rotulos=$(restorecon -nR /boot/loader /boot/grub2 /etc/default/grub 2>&1 | wc -l); echo rotulos=$rotulos; systemctl get-default'
RETFSTAB='md5sum < /etc/fstab; ls -d /mnt/dyn* 2>&1'
SOL[dyn-grub-timeout]='sed -i "s/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=$TIMEOUT/" /etc/default/grub; grub2-mkconfig -o /boot/grub2/grub.cfg'
RET[dyn-grub-timeout]=$RETBOOT
SOL[dyn-kernel-param-add]='grubby --update-kernel=ALL --args="$KARG"'
RET[dyn-kernel-param-add]=$RETBOOT
SOL[dyn-kernel-param-remove]='grubby --update-kernel=ALL --remove-args="$KARG"'
RET[dyn-kernel-param-remove]=$RETBOOT
SOL[dyn-boot-troubleshoot]='systemctl set-default $TARGET; sed -i "s/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=$TIMEOUT/" /etc/default/grub; grub2-mkconfig -o /boot/grub2/grub.cfg; if [ $KMODE = add ]; then grubby --update-kernel=ALL --args="$KARG"; else grubby --update-kernel=ALL --remove-args="$KARG"; fi'
RET[dyn-boot-troubleshoot]=$RETBOOT
SOL[dyn-fstab-fix]='sed -i "\#[[:space:]]$MP[[:space:]]#d" /etc/fstab; systemctl daemon-reload'
RET[dyn-fstab-fix]=$RETFSTAB
SOL[dyn-fstab-validate]='sed -i "\#[[:space:]]$MP1[[:space:]]#d" /etc/fstab; sed -i "\#[[:space:]]$MP2[[:space:]]#s/defaults/defaults,nofail/" /etc/fstab; systemctl daemon-reload'
RET[dyn-fstab-validate]=$RETFSTAB
SOL[dyn-boot-analyze]='systemd-analyze > $OUT; systemd-analyze blame --no-pager | head -$TOPN >> $OUT'
RET[dyn-boot-analyze]='ls $OUT 2>&1'
SOL[dyn-boot-entries]='grubby --info=ALL > $OUT; grubby --default-kernel >> $OUT'
RET[dyn-boot-entries]='ls $OUT 2>&1'
SOL[dyn-initramfs-rebuild]='dracut -f'
RET[dyn-initramfs-rebuild]='md5sum /boot/initramfs-$(uname -r).img; stat -c %Y /boot/initramfs-$(uname -r).img; ls -Z /boot/initramfs-$(uname -r).img | cut -d" " -f1'
SOL[dyn-chroot-practice]='mkdir -p $CHROOT; for m in ${MOUNTS//,/ }; do mkdir -p $CHROOT/$m; mount --bind /$m $CHROOT/$m; done'
RET[dyn-chroot-practice]='findmnt -rno TARGET | grep -c "^$CHROOT"; ls -d $CHROOT 2>&1; findmnt -rno TARGET | wc -l'
SOL[dyn-emergency-target]='systemctl set-default $TARGET'
RET[dyn-emergency-target]='systemctl get-default'
SOL[dyn-ro-root]='mount -o remount,rw /mnt/dynro; printf %s "$CONTENT" > $FILE'
RET[dyn-ro-root]='ls /var/lib/dyn-ro.img /mnt/dynro 2>&1; losetup -a | wc -l; findmnt -rno TARGET | wc -l'
SOL[dyn-journal-boot-log]='journalctl -b 0 -p $PRIO --no-pager > $OUT'
RET[dyn-journal-boot-log]='ls $OUT 2>&1'
SOL[dyn-journal-filter-unit]='journalctl -u $UNIT --no-pager > $OUT'
RET[dyn-journal-filter-unit]='ls $OUT 2>&1'
