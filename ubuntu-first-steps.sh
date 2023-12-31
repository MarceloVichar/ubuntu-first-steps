#!/bin/bash

sudo -v

# Verifica se a autenticação foi bem-sucedida
if [ $? -eq 0 ]; then
    echo "Autenticação bem-sucedida. Continuando a execução do script..."

    # Agora você pode continuar com o restante do script
else
    echo "Falha na autenticação. Certifique-se de fornecer a senha correta."
    exit 1
fi

sudo apt update

# Verifica se o Zsh já está instalado
if ! command -v zsh &> /dev/null; then
    echo "Instalando Zsh..."
    sudo apt install zsh -y
fi

# Verifica se o Curl já está instalado
if ! command -v curl &> /dev/null; then
    echo "Instalando Curl..."
    sudo apt install curl -y
fi

# Verifica se o Git já está instalado
if ! command -v git &> /dev/null; then
    echo "Instalando Git..."
    sudo apt install git -y
fi

# Configuração do Git
echo "Configurando Git..."
read -p "Digite seu nome de usuário do Git: " git_username
read -p "Digite seu email do Git: " git_email

git config --global user.name "$git_username"
git config --global user.email "$git_email"

# Verifica se o NVM já está instalado
if ! command -v nvm &> /dev/null; then
    echo "Instalando NVM..."
    curl https://raw.githubusercontent.com/creationix/nvm/master/install.sh | bash 
    export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
fi

# Instala o Node.js com o NVM
echo "Instalando Node.js..."
nvm install 18
nvm use 18
nvm alias default 18

# Instala o Yarn
echo "Instalando Yarn..."
npm install -g yarn

# Instala o Docker
echo "Instalando Docker..."
sudo apt-get update
sudo apt-get install ca-certificates curl gnupg -y
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
curl -fsSL https://get.docker.com -o get-docker.sh
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
sudo usermod -aG docker $USER

# Instala o Visual Studio Code (VSCode)
echo "Instalando Visual Studio Code (VSCode)..."
sudo apt install software-properties-common apt-transport-https wget -y
wget -q https://packages.microsoft.com/keys/microsoft.asc -O- | gpg --dearmor > packages.microsoft.gpg
sudo install -o root -g root -m 644 packages.microsoft.gpg /usr/share/keyrings/
sudo sh -c 'echo "deb [arch=amd64 signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/vscode stable main" > /etc/apt/sources.list.d/vscode.list'
sudo apt update
sudo apt install code -y

# Gera a chave SSH para autenticação no GitHub
echo "Gerando chave SSH..."
ssh-keygen -t rsa -b 4096 -C "$git_email"

# Inicia o agente SSH
eval "$(ssh-agent -s)"

# Adiciona a chave privada ao agente SSH
ssh-add ~/.ssh/id_rsa

# Mostra a chave pública para copiar e adicionar ao GitHub
echo "A chave pública SSH foi gerada. Copie a saída abaixo e adicione-a ao GitHub (https://github.com/settings/ssh/new):"
echo ""
cat ~/.ssh/id_rsa.pub
echo ""

echo "Após adicionar a chave ao GitHub, pressione Enter para continuar..."
read

# Instala o Oh My Zsh
echo "Instalando Oh My Zsh..."
echo -e "\n" | sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Define o tema Agnoster
echo "Configurando tema Agnoster..."
sudo apt install fonts-powerline -y
sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="agnoster"/' ~/.zshrc

# Define o Zsh como shell padrão
echo "Definindo Zsh como shell padrão..."
chsh -s $(which zsh)

echo "Script concluído! Você precisa reiniciar o computador para aplicar todas as alterações"
