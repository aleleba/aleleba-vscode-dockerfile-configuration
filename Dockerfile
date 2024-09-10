FROM ubuntu:22.04

# Update the package list, install sudo, create a non-root user, and grant password-less sudo permissions
RUN apt update
RUN apt install -y sudo

RUN sudo apt-get update
#Instalando Curl
RUN sudo apt-get install -y curl
#Instalando wget
RUN sudo apt-get install -y wget
#Instalando jq
RUN sudo apt-get install -y jq

RUN sudo apt-get update
RUN sudo apt-get install dumb-init

RUN ARCH="$(dpkg --print-architecture)" \
  && curl -fsSL "https://github.com/boxboat/fixuid/releases/download/v0.6.0/fixuid-0.6.0-linux-${ARCH}.tar.gz" | tar -C /usr/local/bin -xzf - \
  && chown root:root /usr/local/bin/fixuid \
  && chmod 4755 /usr/local/bin/fixuid \
  && mkdir -p /etc/fixuid \
  && printf "user: vscode\ngroup: vscode\n" > /etc/fixuid/config.yml

#Instalando devtunnel
#Comandos que no se deben olvidar correr al crear el devtunnel
#devtunnel user login -g -d
#devtunnel token TUNNELID --scope connect
RUN curl -sL https://aka.ms/DevTunnelCliInstall | bash

# Configurar debconf para que use una interfaz no interactiva
ENV DEBIAN_FRONTEND=noninteractive

#Instalando VSCode
RUN ARCH="$(dpkg --print-architecture)" \
    && sudo apt-get update \
    && sudo apt-get install -y gnupg2 \
    && sudo apt-get install -y software-properties-common \
    && sudo wget -q https://packages.microsoft.com/keys/microsoft.asc -O- | sudo apt-key add - \
    && sudo add-apt-repository "deb [arch=${ARCH}] https://packages.microsoft.com/repos/vscode stable main" \
    && sudo apt update \
    && sudo apt install code -y

#Making home writteable
RUN sudo chmod -R a+rwX /home

RUN sudo sysctl -w fs.inotify.max_user_watches=524288

ADD ./.bashrc /usr/bin/.bashrc
RUN sudo chmod +x /usr/bin/.bashrc
ADD ./.profile /usr/bin/.profile
RUN sudo chmod +x /usr/bin/.profile
ADD ./entrypoint.sh /usr/bin/entrypoint.sh
RUN sudo chmod +x /usr/bin/entrypoint.sh

ENTRYPOINT ["/usr/bin/entrypoint.sh"]