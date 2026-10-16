# Stub do item 15 do simulado RHCSA (examsim-timer-acl): pacote "logger"
# servido em http://content.example.com:8091/timer-repo. Reproduz o RPM do
# homelab (rpm -qp --info/-l/--requires de logger-1.0-1.noarch.rpm em
# 2026-10-16): mesmo nome/versão/release/licença/summary/descrição e o
# mesmo /usr/local/bin/logger (86 bytes, 0755 root:root).
Name:           logger
Version:        1.0
Release:        1
Summary:        Stub script para o item 15 do simulado RHCSA (systemd timer)
License:        MIT
BuildArch:      noarch

%description
Script stub em /usr/local/bin/logger -- o aluno deve edita-lo para
gravar log em /var/tmp/ex200, conforme o enunciado do item 15.

%prep

%build

%install
install -d %{buildroot}/usr/local/bin
cat > %{buildroot}/usr/local/bin/logger <<'EOF'
#!/usr/bin/bash
echo "logger stub -- edite este script para gravar em /var/tmp/ex200"
EOF
chmod 0755 %{buildroot}/usr/local/bin/logger

%files
%attr(0755,root,root) /usr/local/bin/logger
