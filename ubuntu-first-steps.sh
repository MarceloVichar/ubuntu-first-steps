#!/usr/bin/env bash
# =============================================================================
#  ubuntu-first-steps.sh — ambiente de desenvolvimento no Ubuntu
#
#  Testado em: Ubuntu 26.04 LTS.
#  Instala: atualizações do sistema, Git, Zsh + Oh My Zsh (agnoster), NVM + Node
#  LTS, Yarn/pnpm (Corepack), Docker Engine + Compose, VS Code, GitHub CLI e
#  chave SSH cadastrada no GitHub.
#
#  Uso:
#     ./ubuntu-first-steps.sh
#     GIT_NAME="Fulano" GIT_EMAIL="fulano@x.com" ./ubuntu-first-steps.sh
#     ./ubuntu-first-steps.sh --skip-system   # só reaplica configs do usuário (sem senha)
#     ./ubuntu-first-steps.sh --sudo-sem-senha # libera sudo e pkexec sem senha (PC pessoal)
#     KB_LAYOUT=us KB_MODEL=pc105 ./ubuntu-first-steps.sh   # outro teclado (padrão: br abnt2)
#
#  Nenhuma versão é fixada: Node sempre na LTS vigente, NVM na última release,
#  demais pacotes pelos repositórios oficiais. Pode ser executado várias vezes.
# =============================================================================
set -euo pipefail

GIT_NAME="${GIT_NAME:-MarceloVichar}"
GIT_EMAIL="${GIT_EMAIL:-marcos.marcelo43@gmail.com}"
KB_LAYOUT="${KB_LAYOUT:-br}"      # layout do teclado (br = Português Brasil)
KB_MODEL="${KB_MODEL:-abnt2}"     # modelo físico (abnt2 = teclado brasileiro com Ç)

log()  { printf '\n\033[1;34m==>\033[0m \033[1m%s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m[aviso]\033[0m %s\n' "$*"; }

# =============================================================================
#  ETAPA DE SISTEMA (root) — chamada pelo próprio script via sudo/pkexec
# =============================================================================
if [[ ${1:-} == --system ]]; then
  TARGET_USER="$2"
  NOPASSWD="${3:-0}"
  export DEBIAN_FRONTEND=noninteractive
  ARCH="$(dpkg --print-architecture)"
  CODENAME="$(. /etc/os-release && echo "$VERSION_CODENAME")"
  install -m 0755 -d /etc/apt/keyrings

  if [[ $NOPASSWD == 1 ]]; then
    log "Sudo sem senha para $TARGET_USER"
    f="/etc/sudoers.d/90-nopasswd-$TARGET_USER"
    printf '# Criado por ubuntu-first-steps: sudo sem senha (PC pessoal). Apague para desfazer.\n%s ALL=(ALL:ALL) NOPASSWD: ALL\n' "$TARGET_USER" > "$f.tmp"
    if visudo -cf "$f.tmp" >/dev/null; then install -m 0440 "$f.tmp" "$f"; fi   # só instala se for válido
    rm -f "$f.tmp"
    # pkexec / janelas de administrador do GNOME (polkit) sem senha, só na sessão local ativa
    cat > "/etc/polkit-1/rules.d/49-nopasswd-$TARGET_USER.rules" <<EOF
// Criado por ubuntu-first-steps: ações administrativas sem senha para $TARGET_USER
// (somente na sessão local ativa; via ssh continua pedindo). Apague para desfazer.
polkit.addRule(function(action, subject) {
    if (subject.user == "$TARGET_USER" && subject.local && subject.active) {
        return polkit.Result.YES;
    }
});
EOF
    chmod 644 "/etc/polkit-1/rules.d/49-nopasswd-$TARGET_USER.rules"
  fi

  log "Teclado do sistema: ${4:-br} ${5:-abnt2} (tela de login e console)"
  localectl set-x11-keymap "${4:-br}" "${5:-abnt2}" || warn "localectl falhou"

  log "Atualizando o sistema"
  apt-get update -qq
  apt-get full-upgrade -y
  apt-get install -y zsh git curl wget ca-certificates gnupg build-essential \
                     fonts-powerline unzip

  log "Repositório oficial do Docker"
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  rm -f /etc/apt/sources.list.d/docker.list
  cat > /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $CODENAME
Components: stable
Architectures: $ARCH
Signed-By: /etc/apt/keyrings/docker.asc
EOF

  log "Repositório oficial do VS Code"
  curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor --yes -o /usr/share/keyrings/microsoft.gpg
  chmod a+r /usr/share/keyrings/microsoft.gpg
  rm -f /etc/apt/sources.list.d/vscode.list
  cat > /etc/apt/sources.list.d/vscode.sources <<EOF
Types: deb
URIs: https://packages.microsoft.com/repos/code
Suites: stable
Components: main
Architectures: amd64,arm64,armhf
Signed-By: /usr/share/keyrings/microsoft.gpg
EOF
  echo "code code/add-microsoft-repo boolean false" | debconf-set-selections  # não duplicar o repo

  log "Repositório oficial do GitHub CLI"
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o /etc/apt/keyrings/githubcli-archive-keyring.gpg
  chmod a+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
  rm -f /etc/apt/sources.list.d/github-cli.list
  cat > /etc/apt/sources.list.d/github-cli.sources <<EOF
Types: deb
URIs: https://cli.github.com/packages
Suites: stable
Components: main
Architectures: $ARCH
Signed-By: /etc/apt/keyrings/githubcli-archive-keyring.gpg
EOF

  log "Instalando Docker, VS Code e GitHub CLI"
  apt-get update -qq
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin \
                     docker-compose-plugin code gh
  apt-get autoremove -y

  # Docker sob demanda: o daemon só sobe no primeiro comando `docker`,
  # em vez de ficar rodando desde o boot.
  systemctl disable --now docker.service containerd.service >/dev/null 2>&1 || true
  systemctl enable docker.socket >/dev/null 2>&1 || true
  groupadd -f docker
  usermod -aG docker "$TARGET_USER"

  log "Zsh como shell padrão de $TARGET_USER"
  usermod -s "$(command -v zsh)" "$TARGET_USER"

  log "Atualizando snaps"
  snap refresh || warn "snap refresh falhou (tente de novo mais tarde)"
  exit 0
fi

# =============================================================================
#  ETAPA DO USUÁRIO
# =============================================================================
[[ $EUID -eq 0 ]] && { echo "Rode como usuário normal (sem sudo); o script pede a senha quando precisar." >&2; exit 1; }

SKIP_SYSTEM=0; NOPASSWD=0
for arg in "$@"; do
  case "$arg" in
    --skip-system)    SKIP_SYSTEM=1 ;;
    --sudo-sem-senha) NOPASSWD=1 ;;
    -h|--help)        sed -n '2,17p' "$0"; exit 0 ;;
    *) echo "Opção desconhecida: $arg" >&2; exit 1 ;;
  esac
done

SELF="$(readlink -f "$0")"
if (( SKIP_SYSTEM )); then
  log "Pulando etapa de sistema (--skip-system)"
else
  log "Etapa de sistema (pede sua senha uma vez, se o sudo exigir)"
  if sudo -n true 2>/dev/null || [[ -t 0 ]]; then sudo bash "$SELF" --system "$USER" "$NOPASSWD" "$KB_LAYOUT" "$KB_MODEL"
  else pkexec bash "$SELF" --system "$USER" "$NOPASSWD" "$KB_LAYOUT" "$KB_MODEL"; fi   # sem terminal: janela gráfica de senha
fi

# -------------------------------------------------------------------- Teclado
log "Teclado da sessão: $KB_LAYOUT"
gsettings set org.gnome.desktop.input-sources sources "[('xkb', '$KB_LAYOUT')]"

# ------------------------------------------------------------------------ Git
log "Configurando Git ($GIT_NAME <$GIT_EMAIL>)"
git config --global user.name  "$GIT_NAME"
git config --global user.email "$GIT_EMAIL"
git config --global init.defaultBranch main
git config --global pull.rebase false
git config --global core.editor "code --wait"

# ------------------------------------------------------------------- SSH key
KEY="$HOME/.ssh/id_ed25519"
if [[ ! -f $KEY ]]; then
  log "Gerando chave SSH ed25519"
  mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
  ssh-keygen -t ed25519 -C "$GIT_EMAIL" -f "$KEY" -N "" -q
fi
# chave do servidor do GitHub, para o primeiro `git clone` não perguntar
ssh-keygen -F github.com >/dev/null 2>&1 || ssh-keyscan -t ed25519 github.com >> "$HOME/.ssh/known_hosts" 2>/dev/null

# ------------------------------------------------------------- Oh My Zsh
if [[ ! -d $HOME/.oh-my-zsh ]]; then
  log "Instalando Oh My Zsh"
  RUNZSH=no CHSH=no KEEP_ZSHRC=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi
ZC="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
for p in zsh-autosuggestions zsh-syntax-highlighting; do
  [[ -d $ZC/plugins/$p ]] || git clone -q --depth=1 "https://github.com/zsh-users/$p" "$ZC/plugins/$p"
done

log "Configurando ~/.zshrc (agnoster + plugins)"
sed -i 's/^ZSH_THEME=.*/ZSH_THEME="agnoster"/' "$HOME/.zshrc"
sed -i 's/^plugins=(.*)/plugins=(git docker docker-compose nvm npm gh zsh-autosuggestions zsh-syntax-highlighting)/' "$HOME/.zshrc"
# bloco gerenciado: removido e reinserido a cada execução (atualiza sem duplicar);
# precisa vir antes do `source $ZSH/oh-my-zsh.sh`
sed -i '/^# --- ubuntu-first-steps ---$/,/^# --------------------------$/d' "$HOME/.zshrc"
block="$(cat <<'ZSHRC'
# --- ubuntu-first-steps ---
# ~/.local/bin (claude, pipx, etc.): o bash põe no PATH pelo .bashrc/.profile, o zsh não lê esses arquivos
typeset -U path PATH
path=("$HOME/.local/bin" "$HOME/bin" $path)
DEFAULT_USER="$USER"                   # agnoster: esconde usuario@maquina no prompt
zstyle ':omz:plugins:nvm' lazy yes     # NVM só carrega ao usar node/npm/yarn (terminal abre rápido)
zstyle ':omz:update' mode reminder     # avisa quando houver update do Oh My Zsh
# --------------------------
ZSHRC
)"
awk -v b="$block" '/^source \$ZSH\/oh-my-zsh.sh/{print b "\n"} 1' "$HOME/.zshrc" > "$HOME/.zshrc.tmp" \
  && mv "$HOME/.zshrc.tmp" "$HOME/.zshrc"

# Shell de login em zsh (ssh, TTY) não carrega /etc/profile nem ~/.profile:
# carrega os dois em modo sh, igual ao bash (locale, ç, snap, ~/.local/bin...)
if ! grep -q "ubuntu-first-steps" "$HOME/.zprofile" 2>/dev/null; then
  cat >> "$HOME/.zprofile" <<'ZPROFILE'
# ubuntu-first-steps: mesmo ambiente de login do bash
[[ -r /etc/profile ]] && emulate sh -c '. /etc/profile'
[[ -r ~/.profile ]] && emulate sh -c '. ~/.profile'
ZPROFILE
fi

# Variáveis de ambiente pessoais: ~/.env (chmod 600), carregado pelo ~/.zshenv,
# que o zsh lê em TODA execução (terminal, scripts, comandos não interativos, Claude Code)
if [[ ! -f $HOME/.env ]]; then
  cat > "$HOME/.env" <<'ENVFILE'
# Variáveis de ambiente pessoais (carregadas por todo zsh via ~/.zshenv).
# Formato: NOME=valor   (uma por linha; use aspas se tiver espaços)
# Exemplo:
# OPENAI_API_KEY=sk-...
# DATABASE_URL="postgres://user:pass@localhost:5432/db"
ENVFILE
fi
chmod 600 "$HOME/.env"
if ! grep -q "ubuntu-first-steps" "$HOME/.zshenv" 2>/dev/null; then
  cat >> "$HOME/.zshenv" <<'ZSHENV'
# ubuntu-first-steps: variáveis pessoais (export automático de tudo em ~/.env)
[[ -r ~/.env ]] && { set -a; source ~/.env; set +a; }
ZSHENV
fi

# Sessão gráfica: apps abertos pelo Dock/menu (VS Code etc.) também enxergam ~/.local/bin
mkdir -p "$HOME/.config/environment.d"
echo 'PATH=$HOME/.local/bin:$HOME/bin:${PATH}' > "$HOME/.config/environment.d/10-local-bin.conf"

# ---------------------------------------------------- fonte do terminal
# Os símbolos do agnoster precisam de uma fonte com glifos Powerline embutidos;
# o fallback do fonts-powerline sai desalinhado. MesloLGS NF = Menlo (fonte do
# Terminal do macOS) com os glifos.
log "Instalando fonte MesloLGS NF (terminal)"
FONT_DIR="$HOME/.local/share/fonts/MesloLGS-NF"
mkdir -p "$FONT_DIR"
for f in Regular Bold Italic "Bold Italic"; do
  [[ -s "$FONT_DIR/MesloLGS NF $f.ttf" ]] || curl -fsSL -o "$FONT_DIR/MesloLGS NF $f.ttf" \
    "https://raw.githubusercontent.com/romkatv/powerlevel10k-media/145eb9fbc2f42ee408dacd9b22d8e6e0e553f83d/MesloLGS%20NF%20${f// /%20}.ttf"
done
fc-cache -f "$FONT_DIR" >/dev/null
# fonte monoespaçada do sistema (o terminal Ptyxis usa ela por padrão)
gsettings set org.gnome.desktop.interface monospace-font-name "MesloLGS NF 11"
gsettings set org.gnome.Ptyxis use-system-font true 2>/dev/null || true
# Copiar/colar sem Shift no terminal. Seguro: o Ptyxis desativa "copiar" quando não
# há seleção, então Ctrl+C sem nada selecionado continua interrompendo o programa.
gsettings set org.gnome.Ptyxis.Shortcuts copy-clipboard  '<ctrl>c' 2>/dev/null || true
gsettings set org.gnome.Ptyxis.Shortcuts paste-clipboard '<ctrl>v' 2>/dev/null || true
# terminal integrado do VS Code
VSC="$HOME/.config/Code/User/settings.json"
mkdir -p "$(dirname "$VSC")"; [[ -s $VSC ]] || echo '{}' > "$VSC"
python3 - "$VSC" <<'PY' || warn "Não consegui editar $VSC (tem comentários?); defina terminal.integrated.fontFamily manualmente"
import json, sys
p = sys.argv[1]
s = json.load(open(p))
s["terminal.integrated.fontFamily"] = "MesloLGS NF"
json.dump(s, open(p, "w"), indent=4)
PY
# terminal do VS Code: Ctrl+C copia só com seleção (senão interrompe), Ctrl+V cola
VSK="$HOME/.config/Code/User/keybindings.json"
[[ -s $VSK ]] || echo '[]' > "$VSK"
python3 - "$VSK" <<'PY' || warn "Não consegui editar $VSK (tem comentários?)"
import json, sys
p = sys.argv[1]
kb = json.load(open(p))
want = [
    {"key": "ctrl+c", "command": "workbench.action.terminal.copySelection",
     "when": "terminalFocus && terminalTextSelected"},
    {"key": "ctrl+v", "command": "workbench.action.terminal.paste", "when": "terminalFocus"},
]
for w in want:
    if w not in kb:
        kb.append(w)
json.dump(kb, open(p, "w"), indent=4)
PY

# ----------------------------------------------------------------- NVM + Node
export NVM_DIR="$HOME/.nvm"
# última tag estável via git (a API do GitHub limita 60 consultas/hora sem login)
NVM_TAG="$(git ls-remote --tags --refs --sort=-v:refname https://github.com/nvm-sh/nvm 'v*' 2>/dev/null | head -1 | sed 's#.*/##' || true)"
NVM_TAG="${NVM_TAG:-master}"
log "Instalando/atualizando NVM ($NVM_TAG)"
curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/$NVM_TAG/install.sh" | PROFILE=/dev/null bash >/dev/null
# shellcheck disable=SC1091
. "$NVM_DIR/nvm.sh"

log "Instalando Node.js LTS"
set +u
nvm install --lts --latest-npm
nvm alias default 'lts/*'
nvm use default >/dev/null
set -u
echo "Node $(node -v) / npm $(npm -v)"

log "Habilitando Yarn e pnpm via Corepack"
npm install -g corepack@latest >/dev/null
corepack enable
COREPACK_ENABLE_DOWNLOAD_PROMPT=0 yarn --version >/dev/null && echo "Yarn $(COREPACK_ENABLE_DOWNLOAD_PROMPT=0 yarn --version)"

# ----------------------------------------------------------- Claude Code + omp
log "Claude Code e omp (oh-my-pi)"
export PATH="$HOME/.local/bin:$PATH"
command -v claude >/dev/null || curl -fsSL https://claude.ai/install.sh | bash </dev/null
command -v omp    >/dev/null || curl -fsSL https://omp.sh/install | sh </dev/null
# Instruções globais compartilhadas: um único arquivo lido pelos dois agentes.
# Não sobrescreve se já existir (preserva edições locais).
REPO_DIR="$(dirname "$SELF")"
mkdir -p "$HOME/.claude" "$HOME/.omp/agent"
[[ -f $HOME/.claude/CLAUDE.md ]] || cp "$REPO_DIR/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
ln -sfn "$HOME/.claude/CLAUDE.md" "$HOME/.omp/agent/AGENTS.md"   # omp lê ~/.omp/agent/AGENTS.md
if command -v omp >/dev/null; then
  omp config set skills.enableClaudeUser true   >/dev/null   # skills de ~/.claude/skills
  omp config set commands.enableClaudeUser true >/dev/null   # comandos de ~/.claude/commands
  omp config set tools.approvalMode yolo        >/dev/null   # sem pedir aprovação a cada comando
  omp config set modelRoles.default anthropic/claude-opus-5-5 >/dev/null 2>&1 || true
  # navegador do omp usa o Chrome do dia a dia (perfil, logins) via extensão relay;
  # carregar a extensão no Chrome é manual (ver README)
  omp browser-relay install >/dev/null
  omp config set browser.relay true             >/dev/null
  omp token anthropic >/dev/null 2>&1 || warn "omp sem login na Anthropic: rode 'omp login' uma vez"
fi
command -v claude >/dev/null && { claude --version >/dev/null 2>&1 || true; }

# ---------------------------------------------------------------- GitHub CLI
log "Conectando ao GitHub"
# Em instalação nova o chaveiro "Login" do GNOME só passa a existir depois do
# primeiro logout/login; o token gravado antes disso fica em outro chaveiro e o
# gh deixa de achá-lo. Se for o caso, regrava o mesmo token (sem novo login).
gh_restore_token() {
  python3 -I - <<'PY' 2>/dev/null
import gi, subprocess
gi.require_version('Secret', '1')
from gi.repository import Secret
svc = Secret.Service.get_sync(Secret.ServiceFlags.OPEN_SESSION | Secret.ServiceFlags.LOAD_COLLECTIONS)
for col in svc.get_collections():
    col.load_items_sync()
    for it in col.get_items():
        a = it.get_attributes()
        if a.get('service') == 'gh:github.com' and a.get('username'):
            it.load_secret_sync()
            subprocess.run(['gh', 'auth', 'login', '-h', 'github.com', '-p', 'ssh', '--with-token'],
                           input=it.get_secret().get_text() + '\n', text=True, check=True)
            raise SystemExit(0)
raise SystemExit(1)
PY
}
if gh auth status -h github.com >/dev/null 2>&1 || { gh_restore_token && gh auth status -h github.com >/dev/null 2>&1; }; then
  echo "Já autenticado no GitHub."
else
  echo "Vai abrir o navegador: confirme o código mostrado abaixo em github.com/login/device"
  gh auth login -h github.com -p ssh -w --skip-ssh-key -s admin:public_key
fi
if gh ssh-key list 2>/dev/null | grep -q "$(awk '{print $2}' "$KEY.pub")"; then
  echo "Chave SSH já cadastrada no GitHub."
else
  gh ssh-key add "$KEY.pub" -t "$(hostname) ($(date +%Y-%m-%d))"
fi

# ---------------------------------------------------------------- verificação
# lê do sistema (getent), não da sessão atual: shell e grupo só valem no próximo login
log "Verificação final"
ok()   { printf '  \033[1;32m✔\033[0m %s\n' "$*"; }
fail() { printf '  \033[1;31m✘\033[0m %s\n' "$*"; }
[[ "$(getent passwd "$USER" | cut -d: -f7)" == */zsh ]] && ok "Zsh é o shell padrão" || fail "Zsh NÃO é o shell padrão"
id -nG "$USER" | grep -qw docker && ok "Usuário no grupo docker" || fail "Usuário NÃO está no grupo docker"
systemctl is-enabled -q docker.socket && ok "Docker sob demanda (docker.socket)" || fail "docker.socket desativado"
sshout="$(ssh -T -o BatchMode=yes git@github.com 2>&1 || true)"   # ssh -T sempre sai com código 1
[[ $sshout == *"successfully authenticated"* ]] && ok "SSH com GitHub" || fail "SSH com GitHub: $sshout"
gh auth status -h github.com >/dev/null 2>&1 && ok "GitHub CLI autenticado" || fail "GitHub CLI não autenticado"
[[ -L $HOME/.omp/agent/AGENTS.md && -f $HOME/.claude/CLAUDE.md ]] && ok "omp e Claude Code com as mesmas instruções globais (~/.claude/CLAUDE.md)" || fail "Instruções globais do omp/Claude não configuradas"
ok "Node $(node -v), npm $(npm -v), Docker $(docker --version | awk '{print $3}' | tr -d ,), VS Code $(code --version | head -1)"

log "Pronto!"
echo "Faça logout/login (ou reinicie) para valer o Zsh como padrão e o grupo docker."
