# Como criar um exercício novo

Regras completas em [Contrato dos exercícios](../reference/contrato-exercicios.md).
Exemplo: `examsim-meu-exercicio` na servera.

## 1. Escreva os três scripts

Copie um exercício parecido da mesma VM:

```bash
H=labs/hosts/servera/usr/local/lib
for d in lab-scripts lab-grade lab-finish; do
  cp "$H/$d/examsim-cron.sh" "$H/$d/examsim-meu-exercicio.sh"
done
```

- **start** (`lab-scripts/`): idempotente; rode `lab start` duas vezes.
- **grade** (`lab-grade/`): só consulta; `check $? "descrição"` por critério;
  termina com `RESULTADO: PASSOU|FALHOU`.
- **finish** (`lab-finish/`): desfaz o start e o que o aluno pode ter
  criado (usuários, partições, portas, booleans, `.repo`).
- Disco? `source /usr/local/lib/lab-common.sh` (serverb) e procure por
  tamanho — nunca `/dev/sdb`.

## 2. Registre no dispatcher

Em `ansible/roles/workstation/files/rhcsa-lab-original`:

- acrescente o id ao `case` de `lab_hosts()` (servera, serverb ou a regra
  multi-host);
- acrescente a `TODOS_OS_LABS`;
- se apagar disco ou exigir console, uma linha em `lab_aviso()`.

## 3. Registre no catálogo

Acrescente a entrada em `labs/catalog.json` com o próximo `number` livre e o
enunciado **com suas palavras** ([por quê](../explanation/direitos-autorais.md)).

```bash
make catalog          # valida
```

## 4. Solução de referência

Acrescente um bloco `lsol examsim-meu-exercicio <<'EOS' ... EOS` em
`tests/solutions/legacy.sh` e o host em `--host`.

## 5. Instale e teste o ciclo

```bash
make provision                     # ou provision-offline
make ssh-workstation
lab start  examsim-meu-exercicio
lab grade  examsim-meu-exercicio   # RESULTADO: FALHOU
```

No host libvirt:

```bash
bash scripts/lab-ssh.sh servera 'sudo bash -s -- examsim-meu-exercicio' < tests/solutions/legacy.sh
```

De volta na workstation:

```bash
lab grade  examsim-meu-exercicio   # RESULTADO: PASSOU
lab finish examsim-meu-exercicio
lab start  examsim-meu-exercicio   # do zero, de novo
```

## 6. Lint e aceitação

```bash
make lint test-dashboard
bash tests/acceptance/run-all.sh --skip-t11   # T9 roda todos os avulsos
```

## Principais Conclusões

- Scripts em `labs/hosts/<host>/`, registro no dispatcher e no catálogo.
- Teste sempre start → grade (falha) → solução → grade (passa) → finish → start.
