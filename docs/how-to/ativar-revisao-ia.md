# Como ativar a revisão por IA

Com a revisão ligada, todo `lab finish examsim-...` manda a sua tentativa
(enunciado, saída do `lab grade` e a gravação do terminal) para um
**revisor**, que devolve um comentário em Markdown: veredito, o que você
fez, como fez e os riscos de perder ponto na prova. O comentário aparece
no dashboard e em `~/examsim-feedback/` na workstation, 1–3 min depois.

É opcional: sem revisor, o `lab finish` corrige e dá a nota do mesmo jeito.

O revisor roda **fora das VMs do lab**, com a **sua** conta de IA. Escolha
o motor:

| Motor | Precisa de | Custo |
|---|---|---|
| Claude Code CLI | conta Claude (Pro/Max) ou chave da API Anthropic | o da sua conta |
| LLM local (LM Studio, Ollama, vLLM...) | um servidor com API compatível com OpenAI | nenhum, mas a qualidade depende do modelo |
| API compatível com OpenAI na nuvem | URL + chave da API | o do provedor |

Dá para usar o Claude e deixar um LLM como **reserva**: ele só responde
quando o Claude falha (limite de uso, timeout).

## Caminho rápido: este host como revisor (`make ai-reviewer`)

Use quando o host do libvirt (onde você rodou `make deploy`) puder ser o
revisor. No Windows, é a VM Linux ou o WSL onde o lab roda. O lab precisa
estar no ar.

### 1. Preparar o motor

**Com Claude Code**, no host, com o mesmo usuário do `make deploy`:

```bash
curl -fsSL https://claude.ai/install.sh | bash   # instala em ~/.local/bin
claude                                           # faça o login uma vez e saia
claude -p "oi"                                   # precisa responder sem pedir nada
```

**Com LLM local ou API compatível com OpenAI**, preencha no `.env`:

```ini
AI_REVIEW_OPENAI_URL=http://192.168.1.50:1234/v1   # LM Studio; Ollama: http://<ip>:11434/v1
AI_REVIEW_OPENAI_MODEL=qwen3.5-9b                  # nome exato que o servidor lista em /v1/models
AI_REVIEW_OPENAI_API_KEY=                          # só se o servidor pedir
```

A URL precisa ser alcançável **a partir do host** (teste com
`curl <URL>/models`). No LM Studio, ligue "Serve on Local Network" para
aceitar conexões de outras máquinas.

Com os dois configurados, o Claude é o principal e a API vira reserva.

### 2. Rodar

```bash
make ai-reviewer
```

O alvo:

1. confere o motor (`claude -p` respondendo ou as variáveis da API);
2. instala `rhcsa-ai-review` e `rhcsa-ai-review-openai` em `~/.local/bin`
   e grava a configuração em `~/.config/rhcsa-ai-review/env` (modo 600);
3. confere o `sshd` e libera SSH na zona `libvirt` do firewalld, se faltar;
4. liga `RHCSA_RECORDING_ENABLED`, `AI_REVIEW_ENABLED` e
   `AI_REVIEWER=$USER@192.168.56.1` no `.env`;
5. roda `make provision` (ou `provision-offline` se `RHSM_ORG_ID` estiver
   vazio; force com `make ai-reviewer MODE=online`), que gera a chave
   dedicada do `student` na workstation;
6. autoriza essa chave no seu `~/.ssh/authorized_keys`, presa ao IP da
   workstation e ao revisor:
   `from="192.168.56.10",command="~/.local/bin/rhcsa-ai-review",restrict ...`;
7. pede uma revisão de teste a partir da workstation e mostra o começo
   dela.

Termina com `Revisão por IA ativa.` Leva ~4 min, quase tudo no Ansible.

### 3. Usar

```bash
make ssh-workstation
lab start examsim-grupos
# ... resolva ...
lab finish examsim-grupos      # a revisão chega em 1-3 min
ls ~/examsim-feedback/
```

Rode `make ai-reviewer` de novo depois de cada `make destroy` + `make
deploy`: a workstation nasce com chave nova e o alvo troca a linha antiga
do `authorized_keys`.

## Revisor em outra máquina

Use quando o motor está em outra máquina (por exemplo, um servidor que já
tem o Claude Code logado). O passo a passo manual, com a linha do
`authorized_keys`, está em
[`contrib/ai-reviewer/README.md`](../../contrib/ai-reviewer/README.md). A
diferença principal: o lab usa NAT, então o `from=` é o IP **do host do
libvirt** na sua rede, não `192.168.56.10`.

## Desligar

- Uma execução: `RHCSA_AI_REVIEW=0 lab finish <id>`.
- De vez: `AI_REVIEW_ENABLED=false` no `.env` e `make provision` (ou
  `provision-offline`). Para parar também a gravação:
  `RHCSA_RECORDING_ENABLED=false`.

## Se der errado

| Sintoma | O que fazer |
|---|---|
| `o Claude CLI não respondeu a 'claude -p'` | Rode `claude` no host, faça o login e teste `claude -p "oi"` |
| `nenhum motor` | Instale o Claude ou preencha `AI_REVIEW_OPENAI_URL` e `AI_REVIEW_OPENAI_MODEL` |
| `sshd não está rodando` | `sudo systemctl enable --now sshd` (Debian/Ubuntu: `apt install openssh-server`) |
| Teste com `Permission denied (publickey)` | Confira se o `$HOME` e o `~/.ssh` não são graváveis por outros (`chmod 755 ~` ou `700`; `chmod 700 ~/.ssh`) |
| Teste com `API ...: <erro>` | O host não alcança a URL: teste `curl <URL>/models` no host e o firewall do servidor do LLM |
| `claude falhou (...)` sem reserva | Limite da conta ou timeout; configure um LLM de reserva |
| Revisão não aparece depois do `lab finish` | Pedidos e respostas ficam em `~/.local/share/rhcsa-ai-review/` no host (30 dias): o `.md` traz o erro |

Como a coleta e a gravação funcionam por dentro:
[Arquitetura](../explanation/arquitetura.md).

## Principais Conclusões

- `make ai-reviewer` liga tudo num comando, usando o próprio host como revisor.
- O motor é da pessoa que roda o lab: Claude Code, LLM local ou API compatível com OpenAI.
- A chave da workstation só executa o revisor (`command=` + `restrict` + `from=`).
- Sem revisor, o lab funciona igual; só não há comentário da IA.
