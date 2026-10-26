# Referência: contrato dos exercícios

O que um exercício `examsim-*` precisa cumprir. Passo a passo em
[Criar um exercício](../how-to/criar-exercicio.md).

## Layout (igual às VMs do homelab)

`labs/hosts/<host>/` espelha, a partir de `/`, o que o role `lab_common`
instala em cada VM:

```
labs/hosts/<servera|serverb>/usr/local/
├── bin/lab                         # executor local (start/grade/finish)
└── lib/
    ├── lab-common.sh               # helpers (serverb: discos; ambos: verifica_senha)
    ├── lab-scripts/<id>.sh         # start
    ├── lab-grade/<id>.sh           # grade
    └── lab-finish/<id>.sh          # finish (limpeza)
labs/hosts/workstation/usr/local/lib/{lab-scripts,lab-grade,lab-finish}/
                                    # só o lado servidor NFS do autofs
labs/catalog.json                   # catálogo do painel (escrito à mão)
```

Um exercício novo também precisa entrar em `lab_hosts()` (e, se for o caso,
`lab_aviso()` e `TODOS_OS_LABS`) de
`ansible/roles/workstation/files/rhcsa-lab-original`. Modos de arquivo
diferentes de `0750` vão em `lab_common_modes`
(`ansible/roles/lab_common/defaults/main.yml`).

## Entrada em `labs/catalog.json`

Validada por `scripts/build-catalog.py` (`make catalog`) e
`labs/catalog.schema.json`.

| Campo | Tipo | Obrigatório | Regra |
|---|---|---|---|
| `id` | string | sim | `examsim-[a-z0-9-]+`, único |
| `number` | inteiro | sim | 1..N sem buraco; `0` só para `examsim-full`/`examsim-dinamico` |
| `title`, `description`, `warning` | string | sim | `warning` pode ser vazio |
| `host` | string | sim | Host principal exibido no painel |
| `hosts` | lista | sim | Subconjunto de `workstation`, `servera`, `serverb`, sem repetição |
| `instructions` | lista de strings | sim | Enunciado, item a item |
| `solve_target`, `solve_note` | string | sim | Não vazios |
| `solve_method` | string | sim | `ssh` (com `solve_command` `ssh servera\|serverb`) ou `console` (com `solve_command` vazio) |
| `grade` | bool | não | `false` = painel não oferece `grade` (provas orquestradas) |
| `dynamic` | bool | não | Entrada do exame dinâmico |
| `exam_limit_minutes` | inteiro ≥ 1 | não | Cronômetro do painel |

## Saída do grade

Lida por `backend.parse_grade`:

| Linha | Formato |
|---|---|
| Critério aprovado | `OK: <descrição>` |
| Critério reprovado | `FALHOU: <descrição>` |
| Resultado (uma vez, no fim) | `RESULTADO: PASSOU` ou `RESULTADO: FALHOU` |

- Código de saída `0` se passou, `1` se algum critério falhou (padrão
  `check()` dos scripts do homelab).
- Não imprimir senhas: `atenorth` e `LAB_ROOT_PASSWORD` são mascaradas pelo
  painel, mas o grade deve conferir propriedades, não o segredo
  (`verifica_senha` do `lab-common.sh`).

## Start e finish

| Script | Contrato |
|---|---|
| start | Idempotente; prepara só o que o aluno precisa encontrar; sem reboot |
| finish | Inverso explícito do start **e** do que o aluno criou; o executor local roda o grade antes |

Guardas herdadas do homelab (manter):

- discos sempre por **tamanho exato** (`resolve_disco`, `limpa_disco_forte`),
  nunca `/dev/sdb`;
- `fuser -km` antes de desmontar; `udevadm settle` após particionar;
- `restorecon` depois de `tar`/cópias; tabs no `fstab` gravado por scripts;
- o filtro de limpeza não pode depender de estado que a própria ação do
  aluno destrói.

## Exame dinâmico

Tarefas portadas ficam em `labs/dyn/tasks/dyn-*.sh` e são registradas em
`labs/dyn/pool.json`; `labs/dyn/tests/` valida pool e motor
(`python3 -m pytest labs/dyn/tests`). As 24 legadas do pool reaproveitam os
scripts `examsim-*` instalados.

## Soluções de referência

`tests/solutions/legacy.sh` (todas as 25 avulsas, `--list`, `--host <id>`)
e `labs/dyn/qa/solve-exam.sh`/`solve-legacy.sh` (exame dinâmico), usadas só
pelo teste de aceitação (T9/T13).

## Proibições

- Texto de material oficial da Red Hat (RH199/RH134…), em qualquer forma —
  ver [Direitos autorais](../explanation/direitos-autorais.md).
- Segredos reais em scripts ou saídas.

## Principais Conclusões

- Um exercício = 3 scripts por host em `labs/hosts/<host>/` + entrada no
  catálogo + entrada no dispatcher.
- Grade: `OK:`/`FALHOU:` por critério e uma linha `RESULTADO:`.
- Discos sempre por tamanho.
