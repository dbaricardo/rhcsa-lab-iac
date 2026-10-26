# Como fazer o deploy do lab no Windows

> **Não testado.** O lab só foi homologado num host Linux. Os dois
> caminhos abaixo rodam o mesmo deploy dentro de um Linux no Windows; a
> opção B reproduz o ambiente da homologação (uma VM Rocky 10 com
> virtualização aninhada) e é a mais previsível.

O lab precisa de KVM/libvirt: o Terraform cria as 3 VMs via
`qemu:///system`. O Windows não oferece isso nativamente, então o deploy
roda num Linux que, por sua vez, precisa de **virtualização aninhada**
(VMs dentro de uma VM).

| | Opção A: WSL2 | Opção B: VM Linux |
|---|---|---|
| Requisito | Windows 11 + CPU com nested virtualization no WSL | Hyper-V, VMware Workstation ou VirtualBox 7 com nested |
| Consumo | menor | maior (uma VM a mais) |
| Previsibilidade | menor (WSL tem quirks) | igual à homologação |

Nos dois casos a máquina física precisa de ~16 GB de RAM (12 GB para o
Linux) e ~100 GB livres.

## Opção A: WSL2

### 1. Ligar a virtualização aninhada no WSL

Crie ou edite `%UserProfile%\.wslconfig`:

```ini
[wsl2]
nestedVirtualization=true
memory=12GB
processors=6
```

Sem `memory`, o WSL usa só metade da RAM física e as 3 VMs podem não
caber.

### 2. Instalar o Ubuntu e ligar o systemd

No PowerShell:

```powershell
wsl --install -d Ubuntu-24.04
```

Dentro do Ubuntu, crie `/etc/wsl.conf`:

```ini
[boot]
systemd=true
```

De volta ao PowerShell:

```powershell
wsl --shutdown
```

### 3. Conferir o KVM

Abra o Ubuntu de novo e rode:

```bash
ls -l /dev/kvm
```

Se `/dev/kvm` não existir, a CPU ou a versão do Windows não expõe
virtualização aninhada ao WSL: use a opção B.

### 4. Fazer o deploy

Siga o [deploy em Linux](deploy-linux.md) a partir do passo 1, na variante
Ubuntu/Debian. Dois cuidados:

- Guarde **o repositório e a ISO dentro do WSL** (por exemplo `~/` ou
  `/var/lib/libvirt/images/`), não em `/mnt/c/...`. O disco do Windows é
  lento pelo WSL e o usuário `qemu` não consegue lê-lo.
- Para copiar a ISO baixada no Windows:
  `sudo cp /mnt/c/Users/<voce>/Downloads/rhel-10*-dvd.iso /var/lib/libvirt/images/`

### 5. Abrir o dashboard no navegador do Windows

O Windows não enxerga a rede `192.168.56.0/24`, que só existe dentro do
WSL. Dentro do Ubuntu, na pasta do repositório, abra um túnel e deixe-o
rodando:

```bash
ssh -N -i output/student_key -o StrictHostKeyChecking=no \
  -L 8421:192.168.56.10:8421 student@192.168.56.10
```

O WSL repassa o `localhost` para o Windows: abra
`http://localhost:8421` no navegador.

Os exercícios continuam pelo terminal do Ubuntu: `make ssh-workstation`.

## Opção B: VM Linux com virtualização aninhada

### 1. Criar a VM

- Sistema: Rocky Linux 10 (o host da homologação), RHEL 10, Fedora ou
  Ubuntu 24.04.
- 6 vCPUs, 10–12 GB de RAM, disco de 100 GB.
- Rede em modo NAT ou bridge, com internet.

### 2. Ligar a virtualização aninhada (com a VM desligada)

Hyper-V (PowerShell como administrador):

```powershell
Set-VMProcessor -VMName <nome-da-vm> -ExposeVirtualizationExtensions $true
Set-VMMemory -VMName <nome-da-vm> -DynamicMemoryEnabled $false
```

VMware Workstation: *VM Settings → Processors →* marque
**Virtualize Intel VT-x/EPT or AMD-V/RVI**.

VirtualBox 7: *Configurações → Sistema → Processador →* marque
**Habilitar VT-x/AMD-V aninhado**. Com o Hyper-V ativo no Windows, o
VirtualBox perde desempenho e pode não expor o KVM; nesse caso prefira o
Hyper-V.

### 3. Conferir o KVM

Dentro da VM:

```bash
ls -l /dev/kvm
grep -cE 'vmx|svm' /proc/cpuinfo   # precisa ser > 0
```

### 4. Fazer o deploy

Siga o [deploy em Linux](deploy-linux.md) inteiro dentro da VM.

### 5. Abrir o dashboard no navegador do Windows

Do PowerShell (o OpenSSH já vem no Windows 10/11):

```powershell
ssh -L 8421:192.168.56.10:8421 <usuario>@<ip-da-vm-linux>
```

e abra `http://localhost:8421`.

## Desmontar

Dentro do Linux (WSL ou VM): `make destroy`. Para liberar o disco do WSL
inteiro: `wsl --unregister Ubuntu-24.04` (apaga tudo dessa distribuição).

Algo deu errado? Veja [Resolver problemas comuns](resolver-problemas.md).
