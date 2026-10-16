# labs/

| Caminho | Conteúdo | Dono |
|---|---|---|
| `hosts/<host>/` | Árvore espelhada, a partir de `/`, do que existe em cada VM do homelab para os labs legados `examsim-*` | role `lab_common` |
| `dyn/` | Exame dinâmico (`examsim-dinamico`) | role `lab_dyn` |
| `catalog.json` | Catálogo do painel (27 entradas) | dashboard |

## `hosts/` — labs legados

Cópia fiel dos scripts que rodam nas VMs do homelab (extraídos em 2026-10-16), só com a
tabela de IPs/textos do porte aplicada (`192.168.10.x` → `192.168.56.x`, "noVNC/qm reboot 131"
→ `virsh console|reboot rhcsa-lab-serverb`). O role `lab_common` copia cada arquivo para o
mesmo caminho absoluto no host; os modos vêm de `ansible/roles/lab_common/defaults/main.yml`
(padrão `0750 root:root`; exceções de modo e de dono iguais às VMs, inclusive 6 scripts `student:student`).

| Host | Arquivos |
|---|---|
| servera | `usr/local/bin/lab` (dispatcher local: `start`/`grade`/`finish`, o `finish` roda o grade antes), `usr/local/lib/lab-common.sh` (só `verifica_senha`), `usr/local/lib/lab-network-reset.sh`, `usr/local/lib/{lab-scripts,lab-grade,lab-finish}/` com 17 labs |
| serverb | `usr/local/bin/lab`, `usr/local/lib/lab-common.sh` (`disco_do_so`, `resolve_disco`, `limpa_disco_forte`, `verifica_senha`), `usr/local/lib/lab-full/examsim-full-serverb.sh`, `usr/local/lib/{lab-scripts,lab-grade,lab-finish}/` com 8 labs |
| workstation | `usr/local/lib/{lab-scripts,lab-grade,lab-finish}/examsim-autofs-remoteuser2.sh` (lado servidor NFS) |

Os `lab-common.sh` de servera e serverb são **diferentes** no homelab e continuam diferentes
aqui. O dispatcher da workstation (`rhcsa-lab-original`), o `lab_wrapper.py` e o
`lab-full/examsim-full.sh` vêm do role `workstation`.

Para mudar um lab: edite o arquivo em `hosts/<host>/...` e rode `make provision`.
Para conferir que nenhum IP do homelab sobrou: `bash labs/check-ips.sh`.
