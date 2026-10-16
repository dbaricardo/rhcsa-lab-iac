# Solucoes e retratos das tarefas dos dominios 1 (pacotes/repositorios/flatpak) e 5 (rede).
# Usado por validate-ported.sh. Cada solucao roda no host com os params da tarefa, sob "set -e".
# Retrato de pacote: so' a presenca (a versao pode mudar ao reinstalar do mirror) e a lista de .repo.
RETPKG='rpm -q --qf "%{NAME}\n" $PKG 2>&1; ls /etc/yum.repos.d; rotulos=$(restorecon -nR /etc/yum.repos.d 2>&1 | wc -l); echo rotulos=$rotulos'
RETREPO='rotulos=$(restorecon -nR /etc/yum.repos.d 2>&1 | wc -l); echo rotulos=$rotulos; ls /etc/yum.repos.d; cat /etc/yum.repos.d/*.repo | grep -v "^#" | grep -E "^(\[|baseurl|enabled)" | md5sum'
SOL[dyn-pkg-install]='dnf -y install $PKG'
RET[dyn-pkg-install]=$RETPKG
SOL[dyn-pkg-remove]='dnf -y remove $PKG'
RET[dyn-pkg-remove]=$RETPKG
SOL[dyn-pkg-query]='rpm -qi $PKG > $OUT'
RET[dyn-pkg-query]='ls $OUT 2>&1'
SOL[dyn-pkg-provides]='dnf -q provides $TARGET > $OUT'
RET[dyn-pkg-provides]='ls $OUT 2>&1'
SOL[dyn-pkg-history]='dnf -q history list > $OUT'
RET[dyn-pkg-history]='ls $OUT 2>&1'
SOL[dyn-pkg-verify]='rpm -V $PKG > $OUT 2>&1 || true'
RET[dyn-pkg-verify]='md5sum < $CONF; ls $OUT 2>&1'
SOL[dyn-repo-configure]='printf "[%s]\nname=%s\nbaseurl=%s\nenabled=1\ngpgcheck=%s\n" $REPOID "$REPONAME" $URL $GPG > /etc/yum.repos.d/$REPOID.repo'
RET[dyn-repo-configure]=$RETREPO
SOL[dyn-repo-enable-disable]='dnf config-manager --set-$([ $ACTION = enable ] && echo enabled || echo disabled) $REPOID'
RET[dyn-repo-enable-disable]=$RETREPO
SOL[dyn-repo-baseos-appstream]='M=http://content.example.com:8091/rhel10.0/x86_64/dvd; printf "[%s]\nname=%s\nbaseurl=$M/BaseOS\nenabled=1\ngpgcheck=0\n[%s]\nname=%s\nbaseurl=$M/AppStream\nenabled=1\ngpgcheck=0\n" $BASEID $BASEID $APPID $APPID > /etc/yum.repos.d/lab.repo'
RET[dyn-repo-baseos-appstream]=$RETREPO
SOL[dyn-repo-troubleshoot]='printf "[dyn-broken]\nname=Repositorio quebrado\nbaseurl=http://content.example.com:8091/rhel10.0/x86_64/dvd/AppStream\nenabled=1\ngpgcheck=0\n" > /etc/yum.repos.d/dyn-broken.repo'
RET[dyn-repo-troubleshoot]=$RETREPO
SOL[dyn-repo-thirdparty]='printf "[%s]\nname=%s\nbaseurl=http://content.example.com:8091/timer-repo\nenabled=1\ngpgcheck=0\n" $REPOID "$REPONAME" > /etc/yum.repos.d/$REPOID.repo; dnf -y install logger'
RET[dyn-repo-thirdparty]='rpm -q logger 2>&1; '$RETREPO
SOL[dyn-flatpak-remote]='flatpak remote-add --system $NAME http://flatpak.lab.example.com:8091/myrepo.flatpakrepo'
RET[dyn-flatpak-remote]='flatpak remotes --system --columns=name,url; flatpak list --system --columns=ref | sort'
SOL[dyn-flatpak-install]='flatpak install --system -y --noninteractive $NAME $APP'
RET[dyn-flatpak-install]=${RET[dyn-flatpak-remote]}
SOL[dyn-flatpak-remove]='flatpak uninstall --system -y --noninteractive $APP; flatpak uninstall --system -y --noninteractive --unused'
RET[dyn-flatpak-remove]=${RET[dyn-flatpak-remote]}
SOL[dyn-flatpak-list]='flatpak remote-ls --system $NAME --$MODE > $OUT'
RET[dyn-flatpak-list]='flatpak remotes --system --columns=name,url; ls $OUT 2>&1'

# Rede (interface virtual dyn0). Retrato: perfis e interfaces, resolv.conf e rotas da gerencia.
RETNET='rotulos=$(restorecon -nR /etc/NetworkManager 2>&1 | wc -l); echo rotulos=$rotulos; nmcli -t -f NAME,DEVICE con show | sort; ip -br link | awk "{print \$1}" | sort | tr "\n" " "; grep -v "^#" /etc/resolv.conf; ip route show default; ip -4 -br addr show ens18 | awk "{print \$3}"'
SOL[dyn-net-static-ip]='nmcli con mod $NAME ipv4.method manual ipv4.addresses $ADDR connection.autoconnect yes; nmcli con up $NAME'
RET[dyn-net-static-ip]=$RETNET
SOL[dyn-net-dhcp]='nmcli con mod $NAME ipv4.method auto ipv4.addresses "" connection.autoconnect yes'
RET[dyn-net-dhcp]=$RETNET
SOL[dyn-net-dns]='nmcli con mod $NAME ipv4.dns "$DNS1 $DNS2"; nmcli con up $NAME'
RET[dyn-net-dns]=$RETNET
SOL[dyn-net-newconn]='nmcli con add type dummy ifname dyn0 con-name $NAME ipv4.method manual ipv4.addresses $ADDR ipv4.dns $DNS1 ipv4.never-default yes ipv6.method ignore connection.autoconnect yes; nmcli con up $NAME'
RET[dyn-net-newconn]=$RETNET
SOL[dyn-net-ipv6]='nmcli con mod $NAME ipv6.method manual ipv6.addresses $ADDR6; nmcli con up $NAME'
RET[dyn-net-ipv6]=$RETNET
SOL[dyn-net-search-domain]='nmcli con mod $NAME ipv4.dns-search $DOM; nmcli con up $NAME'
RET[dyn-net-search-domain]=$RETNET
SOL[dyn-net-restart]='nmcli con down $NAME; nmcli con up $NAME'
RET[dyn-net-restart]=$RETNET
SOL[dyn-net-info]='nmcli device show dyn0 > $OUT'
RET[dyn-net-info]=$RETNET'; ls $OUT 2>&1'
SOL[dyn-net-verify]='ping -c $COUNT $TARGET > $OUT'
RET[dyn-net-verify]='ls $OUT 2>&1'
SOL[dyn-net-troubleshoot]='nmcli con mod $NAME connection.interface-name dyn0 ipv4.method manual ipv4.addresses $ADDR connection.autoconnect yes; nmcli con up $NAME'
RET[dyn-net-troubleshoot]=$RETNET
SOL[dyn-net-route]='nmcli con mod $NAME +ipv4.routes "$RNET $RGW"; nmcli con up $NAME'
RET[dyn-net-route]=$RETNET
SOL[dyn-net-full-setup]='nmcli con add type dummy ifname dyn0 con-name $NAME ipv4.method manual ipv4.addresses $ADDR ipv4.dns $DNS1 ipv4.dns-search $DOM ipv4.routes "$RNET $RGW" ipv4.never-default yes ipv6.method ignore connection.autoconnect yes; nmcli con up $NAME'
RET[dyn-net-full-setup]=$RETNET
