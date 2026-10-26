# Referência: comando `lab`

Usado como `student` na **workstation**.

```
lab list
lab start  <id>
lab grade  <id>
lab finish <id>
```

| Subcomando | Efeito | Altera o host? |
|---|---|---|
| `list` | Lista os ids e os hosts de cada um | não |
| `start <id>` | Prepara o exercício no(s) host(s) | sim |
| `grade <id>` | Avalia sem destruir o estado (recusado em `examsim-full`/`examsim-dinamico`) | não |
| `finish <id>` | **Avalia e limpa** (nos avulsos o `finish` do host roda o grade antes) | sim |

A saída tem uma linha por critério (`OK: ...` / `FALHOU: ...`) e uma linha
`RESULTADO: PASSOU|FALHOU`. Nas provas orquestradas, `Nota X/24` (aprovação
com 17).

## Camadas

| Camada | Arquivo | Papel |
|---|---|---|
| Wrapper | `/usr/local/bin/lab` (`lab_wrapper.py`) | Repassa saída e código; registra `examsim-*` no SQLite do dashboard; no `finish`, dispara a revisão por IA se `ai_review.py` existir |
| Dispatcher | `/usr/local/libexec/rhcsa-lab-original` | Escolhe host(s) e ordem; `examsim-full` → `lab-full/examsim-full.sh`; `examsim-dinamico` → `lab-dyn/examsim-dinamico.sh` |
| Executor local | `/usr/local/bin/lab` em servera/serverb | Roda `/usr/local/lib/{lab-scripts,lab-grade,lab-finish}/<id>.sh` |

- Hosts remotos: `ssh -o BatchMode=yes -o ConnectTimeout=10 root@<host> "lab <ação> <id>"`.
- Lado workstation (`examsim-autofs-remoteuser2`): `ssh root@localhost "bash /usr/local/lib/<dir>/<id>.sh"`.
- Ordem multi-host: no `start`, workstation (servidor NFS) antes da servera;
  no `finish`, o inverso. Falha num host interrompe os seguintes.

## Códigos de saída

| Código | Significado |
|---|---|
| `0` | Ação executada (em `grade`, independe de PASSOU/FALHOU) |
| `1` | Uso incorreto ou id inexistente |
| `2` | Host de destino inacessível por SSH como root |
| outro | Código do script do exercício |

## Variáveis de ambiente

| Variável | Efeito |
|---|---|
| `LAB_SEED=<n>` | `examsim-dinamico`: reproduz o sorteio |
| `RHCSA_AI_REVIEW=0` | Não dispara a revisão por IA neste `finish` |

## Estado e arquivos

| Caminho | Conteúdo |
|---|---|
| `~/examsim-full/`, `~/examsim-dinamico/` | Prova aberta (`.aberta`), enunciado, resultados |
| `/var/lib/rhcsa-lab-dashboard/` | SQLite de progresso e `dinamico/` (manifestos públicos) |
| `~/examsim-feedback/` | Retornos da revisão por IA (se ligada) |

## Principais Conclusões

- Tudo se roda da workstation; o dispatcher age como root por SSH.
- `finish` corrige **e** limpa; `grade` só avalia.
- As provas orquestradas só dão nota no `finish`.
