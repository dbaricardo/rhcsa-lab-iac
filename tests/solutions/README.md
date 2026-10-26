# tests/solutions/

Soluções de referência dos labs legados `examsim-*` (24 questões + `examsim-treino-storage`),
usadas **só** pelo teste de aceitação para provar que cada `grade` reconhece um ambiente
resolvido. Não fazem parte do fluxo do estudante.

`legacy.sh` é um único script autocontido, gerado a partir de
`rhcsa-lab-dashboard/lab-scripts/dyn/qa/solutions-legacy.sh` (mesmo `LPRE` + `LSOL` do homelab),
com os IPs traduzidos para `192.168.56.0/24`.

## Interface

| Chamada | Onde | Efeito |
|---|---|---|
| `legacy.sh --list` | qualquer lugar | lista os 25 ids com solução |
| `legacy.sh --host <id>` | qualquer lugar | imprime `servera` ou `serverb` |
| `legacy.sh <id>` | **no host da questão, como root** | aplica a solução (`LPRE; set -e; <solução>`); rc ≠ 0 = falhou |

Fluxo por questão (a partir do host de teste):

```bash
host=$(bash tests/solutions/legacy.sh --host examsim-cron)
bash scripts/lab-ssh.sh workstation 'lab start examsim-cron'
bash scripts/lab-ssh.sh "$host" 'sudo bash -s -- examsim-cron' < tests/solutions/legacy.sh
bash scripts/lab-ssh.sh workstation 'lab grade examsim-cron'    # deve dar RESULTADO: PASSOU
bash scripts/lab-ssh.sh workstation 'lab finish examsim-cron'
```

Observações:

- `examsim-autofs-remoteuser2`: a solução roda só na servera (cliente autofs); o lado servidor
  NFS (workstation) é preparado pelo próprio `lab start`.
- `examsim-rootpw-recover-node2`: aplica só o resultado (`chpasswd`), não o procedimento real
  de console/rd.break.
- `examsim-tuned-servera` e `examsim-timer-acl` precisam do mirror `content.example.com:8091`.
- Diferença em relação ao homelab: lá as soluções só rodavam dentro da prova (layout de
  discos do `examsim-full`). Aqui `lvm-mydatabase` cria label gpt no disco de 6 GiB se ele
  estiver cru e `lvm-resize-home` usa `vg_home` (prova) ou `myvg` (lab avulso).
  `examsim-treino-storage` não existia em `solutions-legacy.sh` e foi escrita a partir do grader.
