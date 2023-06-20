#!/bin/bash

# Verifica se o Zsh já está instalado
if ! command -v zsh &> /dev/null; then
    echo "Instalando Zsh..."
    sudo apt update
    sudo apt install zsh -y
fi

# Verifica se o Git já está instalado
if ! command -v git &> /dev/null; then
    echo "Instalando Git..."
    sudo apt update
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
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.38.0/install.sh | bash
    source ~/.bashrc
fi

# Instala o Node.js com o NVM
echo "Instalando Node.js..."
nvm install 16.15.1
nvm use 16.15.1
nvm alias default 16.15.1

# Verifica se o NPM já está instalado
if ! command -v npm &> /dev/null; then
    echo "Instalando NPM..."
    sudo apt update
    sudo apt install npm -y
fi

# Instala o Yarn
echo "Instalando Yarn..."
npm install -g yarn

# Instala o Docker
echo "Instalando Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Instala o Docker Compose
echo "Instalando Docker Compose..."
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Instala o Visual Studio Code (VSCode)
echo "Instalando Visual Studio Code (VSCode)..."
sudo apt update
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
echo "A chave pública SSH foi gerada. Copie a saída abaixo e adicione-a ao GitHub:"
echo ""
cat ~/.ssh/id_rsa.pub
echo ""

echo "Após adicionar a chave ao GitHub, pressione Enter para continuar..."
read

# Instala o Oh My Zsh
echo "Instalando Oh My Zsh..."
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Define o tema Agnoster
echo "Configurando tema Agnoster..."
sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="agnoster"/' ~/.zshrc

# Define o Zsh como shell padrão
echo "Definindo Zsh como shell padrão..."
chsh -s $(which zsh)

echo "Script concluído!"

