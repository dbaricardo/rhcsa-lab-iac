# Referência: comando `lab` e dashboard

## `lab` (na `workstation`)

`/usr/local/bin/lab`, instalado pelo role `workstation`. É o único comando
que o estudante usa.

```
lab list
lab start  <id>
lab grade  <id>
lab finish <id>
```

| Subcomando | Efeito | Altera o host? |
|---|---|---|
| `list` | Imprime o catálogo: número, id, hosts, título | não |
| `start <id>` | Roda `start.sh` em cada host do exercício, na ordem de `hosts` | sim (prepara) |
| `grade <id>` | Roda `grade.sh` em cada host, na ordem de `hosts` | não |
| `finish <id>` | Roda `finish.sh` em cada host, na ordem **inversa** de `hosts` | sim (limpa) |

Antes de cada host, imprime `==> lab <ação> <id> (<host>)`.

### Códigos de saída

| Código | Significado |
|---|---|
| `0` | Ação executada (em `grade`, independe de PASSOU/FALHOU) |
| `2` | Uso incorreto, id inexistente no catálogo ou host de destino inacessível |
| outro | Código devolvido pelo script do exercício em algum host |

O resultado de `grade` está na saída (`RESULTADO: PASSOU`/`FALHOU`), não no
código de saída.

### Execução

- Hosts `servera`/`serverb`: `ssh -o BatchMode=yes -o ConnectTimeout=5
  <host> sudo /usr/local/bin/lab-remote <ação> <id>`.
- Host igual à própria `workstation`: `sudo lab-remote` local, sem SSH.
- Timeout por host: 600 s.
- Cada execução é gravada no SQLite em `/var/lib/rhcsa-lab-dashboard`. Falha
  ao gravar gera só um aviso, sem mudar o código de saída.

Arquivos lidos: `/opt/rhcsa-lab-dashboard/catalog.json` (catálogo) e
`/opt/rhcsa-lab-dashboard/backend.py` (classe `ProgressStore`).

## `lab-remote` (em todas as VMs)

`/usr/local/bin/lab-remote <start|grade|finish> <id>`, instalado pelo role
`lab_common`. Executa `/usr/local/lib/lab-scripts/<id>/<ação>.sh` no host
local. Sai com `2` se a ação for inválida ou o script não existir. Não é
para uso direto do estudante.

## Dashboard

| Item | Valor |
|---|---|
| Serviço | `rhcsa-lab-dashboard.service` (systemd, na `workstation`) |
| URL | `http://192.168.56.10:8421` (`make status` imprime) |
| Código | `/opt/rhcsa-lab-dashboard/backend.py` (Python `http.server`) |
| Dados | `/var/lib/rhcsa-lab-dashboard` (SQLite) |
| Firewall | Porta liberada só para `dashboard.allowed_source` |

Endpoints (todos somente leitura):

| Rota | Resposta |
|---|---|
| `GET /` | Página HTML com catálogo e progresso |
| `GET /api/state` | JSON com o estado de cada exercício |
| `GET /healthz` | Verificação de vida do serviço |

Linhas com `senha`, `password`, `token` ou `private key` na saída dos
scripts são redigidas antes de ir para o banco.
