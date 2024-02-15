#!/bin/bash
set -eu

if [[ -z "${HOME_USER}" ]]; then
    HOME_USER="vscode"
fi

#addgroup nonroot
#adduser --disabled-password --gecos "" ${HOME_USER}
#echo "${HOME_USER} ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# We do this first to ensure sudo works below when renaming the user.
# Otherwise the current container UID may not exist in the passwd database.
eval "$(fixuid -q)"

if [ "${HOME_USER-}" ]; then
  USER="$HOME_USER"
  if [ "$HOME_USER" != "$(whoami)" ]; then
    adduser --disabled-password --gecos "" ${HOME_USER}
    echo "$HOME_USER ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers.d/nopasswd > /dev/null
    su - $HOME_USER
    # Unfortunately we cannot change $HOME as we cannot move any bind mounts
    # nor can we bind mount $HOME into a new home as that requires a privileged container.
    sudo usermod --login "$DOCKER_USER" vscode
    sudo groupmod -n "$DOCKER_USER" vscode

    sudo sed -i "/vscode/d" /etc/sudoers.d/nopasswd
    sudo cd /home/${HOME_USER}
  fi
fi


#Creating extensions folder
sudo mkdir /home/${HOME_USER}/.config/Code
sudo chmod -R a+rwX /home/${HOME_USER}/.config/Code
sudo mkdir /home/${HOME_USER}/.vscode-server
sudo chmod -R a+rwX /home/${HOME_USER}/.vscode-server
sudo mkdir /home/${HOME_USER}/.vscode-server-insiders
sudo chmod -R a+rwX /home/${HOME_USER}/.vscode-server-insiders

# Check if the data.json file exists
if [ -f "/home/extensions.json" ]; then
    # Read the JSON file into a variable
    jsonExtensions=$(cat /home/extensions.json)

    # Use jq to extract the extension parameter from the JSON array
    extensions=$(echo $jsonExtensions | jq -r '.[].extensionsGroup.extensions[].uniqueIdentifier')

    # Loop through the extensions and process each element
    for extension in $extensions; do
        echo "Installing extension: $extension"
        sudo su - ${HOME_USER} -c "code --install-extension $extension"
    done
    sudo cp -R /home/${HOME_USER}/.vscode/* /home/${HOME_USER}/.vscode-server
    sudo cp -R /home/${HOME_USER}/.vscode/* /home/${HOME_USER}/.vscode-server-insiders
    sudo chmod -R a+rwX /home/${HOME_USER}/.vscode
    sudo chmod -R a+rwX /home/${HOME_USER}/.vscode-server
    sudo chmod -R a+rwX /home/${HOME_USER}/.vscode-server-insiders
else
    echo "File extensions.json not found"
fi

if [[ -z "${VSCODE_TUNNEL_NAME}" ]]; then
    sudo su - ${HOME_USER} -c "code tunnel --accept-server-license-terms"
else
    sudo su - ${HOME_USER} -c "code tunnel --accept-server-license-terms --name ${VSCODE_TUNNEL_NAME}"
fi
