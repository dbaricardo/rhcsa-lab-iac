# Tutorial fim a fim

Este tutorial assume que você nunca viu este repositório antes. Ele cobre
tudo, do zero: instalar os pré-requisitos no seu computador, conseguir uma
ISO do RHEL 10, construir o ambiente e resolver seu primeiro exercício.

Se você já tem tudo instalado e só quer o resumo rápido, veja o
[README.md](../README.md).

## 1. Pré-requisitos do host

Você precisa de uma máquina Linux com suporte a virtualização de hardware
(VT-x/AMD-V habilitado na BIOS/UEFI). As VMs deste laboratório rodam via
**KVM/libvirt**, usando **Vagrant** como orquestrador.

Confirme que a virtualização está disponível antes de instalar qualquer
coisa:

```bash
grep -E 'vmx|svm' /proc/cpuinfo | head -1
```

Se não retornar nada, habilite VT-x/AMD-V na BIOS/UEFI antes de continuar.

### Fedora / RHEL / CentOS Stream / Rocky (dnf)

```bash
sudo dnf install -y @virtualization libvirt libvirt-daemon-kvm \
  virt-install libguestfs-tools qemu-img ansible-core gettext python3 \
  libvirt-devel gcc ruby-devel libxml2-devel pkgconf-pkg-config

sudo systemctl enable --now libvirtd
sudo usermod -aG libvirt "$USER"
```

Instale o Vagrant a partir do repositório oficial da HashiCorp (não está nos
repositórios padrão do Fedora):

```bash
sudo dnf config-manager addrepo --from-repofile=https://rpm.releases.hashicorp.com/fedora/hashicorp.repo
sudo dnf install -y vagrant
```

### Debian / Ubuntu (apt)

```bash
sudo apt update
sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients \
  virtinst libguestfs-tools qemu-utils ansible gettext-base python3 \
  libvirt-dev ruby-dev build-essential pkg-config libxslt-dev libxml2-dev zlib1g-dev

sudo systemctl enable --now libvirtd
sudo usermod -aG libvirt,kvm "$USER"
```

Instale o Vagrant a partir do repositório oficial da HashiCorp:

```bash
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install -y vagrant
```

### Nas duas distribuições

Depois de instalar, **saia e entre de novo na sessão** (ou rode `newgrp
libvirt`) para o grupo `libvirt` (e `kvm`, no Debian/Ubuntu) fazer efeito.
Em seguida, instale o plugin do Vagrant para libvirt:

```bash
vagrant plugin install vagrant-libvirt
```

Instale também as collections Ansible usadas pelos roles (não vêm no
`ansible-core`):

```bash
ansible-galaxy collection install -r ansible/requirements.yml
```

Confirme que tudo está funcionando:

```bash
virsh -c qemu:///system list
```

Se retornar uma lista vazia sem erro, o libvirt está acessível para o seu
usuário.

## 2. Conta Red Hat Developer + activation key

Este laboratório usa RHEL 10 real, registrado com uma **Red Hat Developer
Subscription for Individuals** (gratuita).

1. Crie (ou use) uma conta em <https://developers.redhat.com/> — a inscrição
   é gratuita.
2. Acesse <https://console.redhat.com/insights/connector/activation-keys>
   com essa conta.
3. Crie uma **activation key** nova (ou use uma existente). Anote:
   - o **nome/valor da activation key**;
   - o **Organization ID** da sua conta (aparece na mesma página, ou em
     `console.redhat.com` -> ícone de perfil -> "My User Access" /
     "Account settings").

Você vai usar os dois em `.env` (`RHSM_ACTIVATION_KEY` e `RHSM_ORG_ID`) no
passo 4.

## 3. Baixar a ISO do RHEL 10

Baixe a ISO **DVD, x86_64** do RHEL 10 na página oficial de downloads da sua
conta Red Hat:

<https://access.redhat.com/downloads/content/rhel>

(faça login com a mesma conta Red Hat Developer do passo 2). Este
repositório **nunca** baixa, inclui ou redistribui a ISO por você — anote o
caminho local completo do arquivo baixado, você vai precisar dele no próximo
passo.

## 4. Clonar o repositório e configurar `.env`

```bash
git clone <url-deste-repositorio> rhcsa-lab-iac
cd rhcsa-lab-iac
cp .env.example .env
```

Edite `.env` e preencha:

| Variável | Valor |
|---|---|
| `RHEL_ISO_PATH` | Caminho absoluto da ISO baixada no passo 3 |
| `RHSM_ORG_ID` | Organization ID do passo 2 |
| `RHSM_ACTIVATION_KEY` | Activation key do passo 2 |
| `STUDENT_PASSWORD` | Senha que você vai usar para o usuário `student` nas VMs (uso local apenas) |
| `APPLY_SECURITY_UPDATES` | `false` (padrão, build mais rápido) ou `true` |

`.env` nunca é commitado (está no `.gitignore`) — pode conter suas
credenciais reais com segurança.

## 5. `make check-env`

```bash
make check-env
```

Esse comando valida, em modo relatório (não para no primeiro erro): binários
necessários (`virt-install`, `virt-customize`, `qemu-img`, `virsh`,
`vagrant`, `ansible`, `envsubst`, `python3`), o plugin `vagrant-libvirt`,
presença de `/dev/kvm`, acesso a `qemu:///system` e todas as variáveis do
`.env` (incluindo se `RHEL_ISO_PATH` de fato existe no disco).

Só avance quando a saída terminar com `Tudo certo. Pode seguir com 'make
build-box'.`. Se algo falhar, a própria saída indica o comando de correção.

## 6. `make build-box`

```bash
make build-box
```

O que acontece (tudo automatizado, sem interação):

1. Renderiza o kickstart (`kickstart/ks.cfg.tpl`) com suas variáveis de
   `.env` (a senha já entra como hash SHA-512, nunca em texto plano).
2. Cria um disco qcow2 de 20GB e roda `virt-install` contra a sua ISO,
   injetando o kickstart via `--initrd-inject` — instalação 100%
   desassistida.
3. Espera o domínio desligar sozinho (o kickstart termina com `poweroff`).
4. Roda um sysprep leve offline (`image/box-finalize.sh`, via
   `virt-customize`): remove chaves SSH de host, limpa logs, corrige
   contexto SELinux.
5. Empacota o resultado como um box `vagrant-libvirt` e registra com
   `vagrant box add`.

**Tempo estimado:** normalmente entre 10 e 20 minutos, a maior parte gasta
na instalação desassistida do RHEL (passo 2). Em hardware mais lento ou I/O
em disco mecânico, pode levar mais.

O que esperar no terminal: uma sequência de linhas `==> ...` marcando cada
etapa, seguida pela saída "crua" do `virt-install` durante a instalação
(sem interação necessária — é só acompanhar). Ao final, confirme:

```bash
vagrant box list
# deve listar: rhel10-rhcsa-base (libvirt, 0)
```

Se algo falhar aqui, o erro mais comum é `RHEL_ISO_PATH` incorreto ou
activation key/org ID inválidos — revise o `.env` e rode `make check-env`
de novo.

## 7. `make up`

```bash
make up
```

Isso gera `labs/catalog.json` (a partir dos `meta.json` de cada exercício em
`labs/`) e roda `vagrant up`, que:

1. Cria as 3 VMs (`servera`, `serverb`, depois `workstation`, sempre por
   último) a partir do box golden, cada uma com IP estático conforme
   `machines.yaml`.
2. Depois que as 3 existem, dispara o playbook Ansible
   (`ansible/site.yml`) uma única vez, provisionando tudo: usuário
   `student`, SSH cruzado entre as VMs, pacotes de cada papel, os
   exercícios atribuídos a cada host e o dashboard web na `workstation`.

Isso demora vários minutos (clonagem de 3 discos + provisionamento
completo). Acompanhe a saída do Ansible no terminal — ela mostra cada task
rodando por host.

## 8. Verificar as VMs

```bash
vagrant status
```

Deve mostrar `workstation`, `servera` e `serverb`, todas em estado
`running`. Para confirmar acesso SSH:

```bash
vagrant ssh workstation
```

Dentro da `workstation`, liste o catálogo de exercícios:

```bash
lab list
```

Isso deve imprimir a lista de exercícios disponíveis (número, id, host(s),
título). Se `lab list` falhar ou vier vazia, confirme que `make up` rodou
até o fim sem erros do Ansible.

Saia da sessão SSH (`exit` ou `Ctrl+D`) quando terminar.

## 9. Acessar o dashboard

```bash
make status
```

A última linha imprime a URL do dashboard, por padrão:

```
http://192.168.56.10:8421
```

Abra essa URL no navegador do seu host (a máquina onde você rodou `vagrant
up`, não dentro de nenhuma VM). Você deve ver a lista de exercícios e o
status de progresso de cada um (inicialmente, todos pendentes).

Se a página não carregar, confirme a origem permitida em `machines.yaml` ->
`dashboard.allowed_source` — por padrão é a própria rede privada do lab
(`192.168.56.0/24`), que já inclui a interface do libvirt no seu host.

## 10. Resolver um exercício de ponta a ponta

Vamos usar `users-groups-01` como exemplo — um exercício simples, de um
único host (`servera`).

Tudo começa e termina na `workstation`:

```bash
vagrant ssh workstation
lab start users-groups-01
```

Isso prepara o ambiente do exercício em `servera` (o dispatcher `lab`
resolve automaticamente qual host usar, olhando o catálogo). A saída mostra
`==> lab start users-groups-01 (servera)` seguido do resultado.

Agora resolva o exercício de verdade. Abra outra sessão (a partir do seu
host, ou de dentro da própria `workstation`) para a `servera`:

```bash
vagrant ssh servera
```

Leia as instruções do exercício (no dashboard, ou com `lab list` mais
detalhes) e resolva com os comandos reais do RHEL (`useradd`, `groupadd`,
`chage`, etc. — para este exercício específico). Quando terminar, saia da
`servera`.

De volta na `workstation` (ou numa nova sessão `vagrant ssh workstation`),
avalie o resultado:

```bash
lab grade users-groups-01
```

A saída mostra uma linha `OK:`/`FALHOU:` por critério avaliado, terminando
com `RESULTADO: PASSOU` ou `RESULTADO: FALHOU`. Rode `lab grade` quantas
vezes quiser — é uma operação somente leitura, não altera nada.

Atualize o dashboard no navegador (passo 9): o exercício `users-groups-01`
deve aparecer com o resultado mais recente.

Quando terminar de estudar esse exercício, limpe o ambiente:

```bash
lab finish users-groups-01
```

Isso reverte explicitamente o que `lab start` preparou (nunca reinvoca
`start.sh` para isso — ver [troubleshooting.md](troubleshooting.md)),
deixando `servera` pronta para o próximo exercício.

## 11. `make destroy`

Quando terminar a sessão de estudo:

```bash
make destroy
```

Isso destrói as 3 VMs (`vagrant destroy -f`) — **o box golden
`rhel10-rhcsa-base` não é removido**, então da próxima vez basta rodar `make
up` de novo (sem precisar refazer `make build-box`), a menos que você queira
recomeçar do zero com uma imagem base nova.

## Onde ir depois

- [docs/architecture.md](architecture.md) — como as peças se encaixam e por
  quê.
- [docs/troubleshooting.md](troubleshooting.md) — bugs conhecidos, caso
  encontre algum sintoma parecido.
- [docs/exercises-authoring-guide.md](exercises-authoring-guide.md) — como
  escrever seus próprios exercícios em `labs/`.
- [docs/rocky-linux-fallback.md](rocky-linux-fallback.md) — se quiser testar
  a infraestrutura sem uma ISO RHEL.
- [NOTICE.md](../NOTICE.md) / [docs/copyright-notice.md](copyright-notice.md)
  — contexto sobre direitos autorais e o que este repositório
  deliberadamente não inclui.
