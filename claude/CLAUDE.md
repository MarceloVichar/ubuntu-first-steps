# Instruções globais (Claude Code e omp)

Este arquivo é lido pelo Claude Code e pelo omp (oh-my-pi). Vale para qualquer projeto nesta máquina.

## Usuário
- Marcelo (GitHub: MarceloVichar, git: marcos.marcelo43@gmail.com). Responda sempre em **português (Brasil)**.
- PC pessoal: Ubuntu 26.04 LTS, GNOME 50 (Wayland), desktop AMD, teclado ABNT2.

## Permissões
- `sudo` e `pkexec` funcionam **sem senha** (configurado de propósito). Use `sudo` direto quando precisar. Não peça a senha e não peça ao usuário para rodar comandos com sudo.
- Ações irreversíveis ou que publicam algo fora da máquina (push, apagar dados, deixar um repositório público) ainda precisam da confirmação do usuário.

## Ambiente
- Shell padrão: zsh + Oh My Zsh (tema agnoster, fonte MesloLGS NF).
- Variáveis de ambiente pessoais ficam em `~/.env` (chmod 600), exportadas em todo zsh via `~/.zshenv`. Quando o usuário pedir uma nova variável, coloque lá. Nunca grave a senha do sistema em variável.
- Node: NVM com a LTS atual (carregado sob demanda no zsh); Yarn/pnpm via Corepack.
- Docker: sob demanda (`docker.socket`); o usuário está no grupo `docker` (não precisa de sudo).
- GitHub: `gh` autenticado e chave SSH ed25519 cadastrada; use `gh` para operações no GitHub.
- `~/.local/bin` está no PATH (claude, omp).

## Como trabalhar nesta máquina
- **Desempenho importa**: evite daemons em segundo plano, extensões pesadas ou serviços sempre ligados quando houver alternativa sob demanda.
- **Tudo replicável**: qualquer mudança de configuração do sistema também deve entrar no script correspondente (idempotente) e no README:
  - Aparência/experiência estilo macOS → `~/macos-look/setup-macos-look.sh` (github.com/MarceloVichar/macos-look)
  - Ferramentas, shell, sistema → `~/ubuntu-first-steps/ubuntu-first-steps.sh` (github.com/MarceloVichar/ubuntu-first-steps)
  - Teste o script de novo após mudar; commit com mensagem em português; push só depois que o usuário aprovar.
- Prefira versões **LTS** e repositórios oficiais; não confie em versões fixas antigas.
