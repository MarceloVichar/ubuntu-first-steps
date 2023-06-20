# ubuntu-first-steps

No repositório encontra-se um script que ira instalar e configurar no Ubuntu algumas tecnologias necessárias para rodar alguns ambientes

* Git
  - Instalação
  - Configuração de nome do usuário e email
  - Geração de chave SSH (Após a chave ser gerada, copie a mesma e configure no github, seguindo esse tutorial, a partir do passo 2: https://docs.github.com/pt/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account )
 
* Zsh
  - Instalação
  - Configuração do OhMyZsh
  - Instalação do tema agnoster
 
* Docker
* Docker Compose
* NPM
* NVM (Com a versão 16.15.1 do NODE)
* Yarn


## Como rodar o script

Copie o arquivo ubuntu-first-steps.sh para a pasta home do seu ubuntu

Abra o terminal (Ctrl + Alt + T)

Dê permissão para o arquivo com o comando
 ```
  $ chmod +x ubuntu-first-steps.sh
```

Rode o comando para iniciar o script
```
  $ ./ubuntu-first-steps.sh
```
