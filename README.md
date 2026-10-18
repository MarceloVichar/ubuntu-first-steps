# ubuntu-first-steps

Script que prepara um Ubuntu novo para desenvolvimento, de forma não interativa e idempotente (pode rodar várias vezes). Testado no **Ubuntu 26.04 LTS**.

**Nenhuma versão é fixada**: o Node é sempre a LTS vigente, o NVM a última release, e o resto vem dos repositórios oficiais de cada projeto.

## O que instala e configura

| Ferramenta | Como | Observações |
|---|---|---|
| Atualizações do sistema | `apt full-upgrade` + `snap refresh` | |
| Base | `zsh git curl wget build-essential fonts-powerline unzip` | `fonts-powerline` dá os símbolos do agnoster |
| **Git** | `user.name`, `user.email`, branch padrão `main`, editor VS Code | |
| **Chave SSH** | `ed25519` (substitui a antiga RSA 4096), sem senha | `github.com` já fica nos `known_hosts` |
| **GitHub CLI** (`gh`) | repo oficial `cli.github.com` | Login pelo navegador; **a chave SSH é cadastrada no GitHub automaticamente** |
| **Zsh** | definido como shell padrão com `usermod -s` (como root) | Corrige o `chsh` do script antigo, que pedia senha e falhava |
| **Oh My Zsh** | modo `--unattended` | Corrige o instalador que abria um zsh e travava o script |
| Tema **agnoster** | `DEFAULT_USER` definido | Esconde `usuario@maquina` no prompt |
| Fonte **MesloLGS NF** | `~/.local/share/fonts`, definida como fonte monoespaçada do sistema e no terminal do VS Code | Derivada da Menlo (fonte do Terminal do macOS), com os símbolos do agnoster embutidos |
| PATH no zsh | `~/.local/bin` no `.zshrc`; `.zprofile` carrega `/etc/profile` e `~/.profile`; `~/.config/environment.d` para a sessão gráfica | Sem isso, o `claude` e outras ferramentas instaladas em `~/.local/bin` não aparecem no zsh |
| **Variáveis de ambiente** | `~/.env` (chmod 600), carregado pelo `~/.zshenv` | Lido por todo zsh: terminal, scripts, comandos não interativos e Claude Code |
| **Teclado** | `br` / `abnt2` na sessão (gsettings), na tela de login e no console (`localectl`) | Mude com `KB_LAYOUT` / `KB_MODEL` |
| Plugins | `git docker docker-compose nvm npm gh zsh-autosuggestions zsh-syntax-highlighting` | |
| **NVM** | última tag estável, via `git ls-remote` (sem limite da API) | Carregado sob demanda: o terminal abre rápido |
| **Node.js** | `nvm install --lts` + npm mais recente | `default -> lts/*` |
| **Yarn / pnpm** | Corepack | Respeita o campo `packageManager` de cada projeto |
| **Docker Engine + Compose v2** | repo oficial `download.docker.com` | Usuário adicionado ao grupo `docker`. Daemon **sob demanda** (`docker.socket`) |
| **VS Code** | repo oficial da Microsoft | |
| **Claude Code** e **omp** (oh-my-pi) | instaladores oficiais (`claude.ai/install.sh`, `omp.sh/install`), se faltarem | Instruções globais compartilhadas, skills do Claude no omp, modo sem aprovações. O navegador do omp usa o seu Chrome (perfil e logins) via relay; passo manual único: em `chrome://extensions`, ative o Modo do desenvolvedor, clique em "Carregar sem compactação" e escolha `~/.omp/browser-relay/extension` |

Os repositórios usam o formato moderno do apt (`.sources`, deb822) com chave GPG em `signed-by`, sem `apt-key`.

## Como rodar

```bash
chmod +x ubuntu-first-steps.sh
./ubuntu-first-steps.sh
```

Para reaplicar só as configurações do usuário (zsh, fonte, Node, GitHub), sem senha e sem `apt`:

```bash
./ubuntu-first-steps.sh --skip-system
```

Para também liberar **sudo e pkexec sem senha** (só em PC pessoal: qualquer programa do seu usuário vira root sem confirmação):

```bash
./ubuntu-first-steps.sh --sudo-sem-senha
# para desfazer:
sudo rm /etc/sudoers.d/90-nopasswd-$USER /etc/polkit-1/rules.d/49-nopasswd-$USER.rules
```

- **sudo**: o arquivo em `/etc/sudoers.d` é validado com `visudo -c` antes de ser instalado, então um erro nele não quebra o sudo.
- **pkexec** e janelas de administrador do GNOME: regra do polkit válida **só na sessão local ativa**. Via ssh, a senha continua sendo pedida.

Outro teclado (o padrão é o brasileiro ABNT2):

```bash
KB_LAYOUT=us KB_MODEL=pc105 ./ubuntu-first-steps.sh
```

Para outra pessoa ou outro email:

```bash
GIT_NAME="Fulano" GIT_EMAIL="fulano@email.com" ./ubuntu-first-steps.sh
```

Ao rodar:
1. A senha é pedida **uma vez**: no terminal, ou numa janela gráfica se não houver terminal.
2. No fim, o `gh` mostra um código. Abra https://github.com/login/device, cole o código e autorize.
3. Faça **logout/login** ou reinicie. Só então valem o Zsh como padrão e o grupo `docker`.

O script termina com uma **verificação** de shell padrão, grupo docker, SSH com GitHub, `gh` e versões instaladas.

## Variáveis de ambiente (`~/.env`)

Coloque as suas variáveis em `~/.env`, uma por linha:

```bash
OPENAI_API_KEY=sk-...
DATABASE_URL="postgres://user:pass@localhost:5432/db"
```

Elas são exportadas automaticamente em **todo** zsh: terminal, scripts e comandos não interativos (inclusive os que o Claude Code executa). O arquivo tem permissão `600`, então só o seu usuário consegue ler.

- Apps abertos pelo Dock/menu **não** leem esse arquivo. Para variáveis que eles precisem ver, use `~/.config/environment.d/*.conf` (vale a partir do próximo login).
- Não guarde a senha do sistema aqui. Com `--sudo-sem-senha` ela não é necessária, e uma variável de ambiente fica visível para todos os processos filhos.

## Claude Code e omp: instruções compartilhadas

Os dois agentes leem **o mesmo arquivo** de instruções globais:

```
~/.claude/CLAUDE.md            ← lido pelo Claude Code
~/.omp/agent/AGENTS.md  ──→    link simbólico para o arquivo acima (lido pelo omp)
```

Ele diz quem é o usuário, em que idioma responder, que o sudo não pede senha, onde ficam as variáveis (`~/.env`) e que toda mudança no sistema deve entrar nestes scripts. O modelo está em [`claude/CLAUDE.md`](claude/CLAUDE.md). Numa máquina nova ele é copiado só se ainda não existir um, para não sobrescrever edições locais.

O omp também é configurado com:
- `skills.enableClaudeUser` e `commands.enableClaudeUser`: usa as skills e comandos de `~/.claude/`
- `tools.approvalMode = yolo`: não pede aprovação a cada comando
- Modelo padrão `anthropic/claude-opus-5-5`

Para continuar no omp uma conversa começada no Claude Code: `omp --from-claude`.

## Docker sob demanda

Para não pesar no boot, o daemon do Docker não sobe com o sistema: ele inicia no primeiro comando `docker`, com ~1 s de atraso só nessa primeira vez. Containers com `restart: always` só voltam depois que você rodar algum comando `docker`.

Se preferir o Docker sempre ligado:

```bash
sudo systemctl enable --now docker.service containerd.service
```

## Problemas conhecidos (já tratados pelo script)

- **Símbolos do agnoster quebrados ou desalinhados**: o `fonts-powerline` sozinho só "empresta" os símbolos de outra fonte. O script instala a MesloLGS NF, que já tem os glifos. Feche e abra o terminal depois de rodar.
- **`claude: command not found` no zsh**: o instalador do Claude Code só adiciona `~/.local/bin` ao `.bashrc`. O script coloca esse diretório no PATH do zsh e da sessão gráfica.
- **`gh` diz "token is invalid" depois do primeiro logout**: numa instalação nova, o chaveiro "Login" do GNOME só é criado no primeiro login, e o token salvo antes disso fica em outro chaveiro. Ao rodar de novo, o script encontra esse token e o regrava, sem pedir novo login.

## Mudanças em relação à versão antiga

- Node 18 fixo → LTS sempre atual; `npm i -g yarn` → Corepack
- Chave RSA + copiar e colar no GitHub → ed25519 cadastrada pelo `gh`
- `apt-key` / `.list` → keyrings + `.sources` (deb822)
- `chsh` interativo → `usermod -s`; instalador do Oh My Zsh não abre mais um shell no meio do script
- Corrigido o download do `get-docker.sh` que não era usado
- Adicionados: `gh`, atualização completa do sistema, plugins de autosugestão e realce de sintaxe, verificação final
