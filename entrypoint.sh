#!/bin/bash
set -eu

if [[ -z "${HOME_USER-}" ]]; then
    HOME_USER="vscode"
fi

if ! grep -q "HOME_USER=" /etc/environment; then
  sudo bash -c "echo HOME_USER=$HOME_USER >> /etc/environment"
fi

if [[ -v VSCODE_TUNNEL_NAME && -n "${VSCODE_TUNNEL_NAME}" ]]; then
  if ! grep -q "VSCODE_TUNNEL_NAME=" /etc/environment; then
    sudo bash -c "echo VSCODE_TUNNEL_NAME=$VSCODE_TUNNEL_NAME >> /etc/environment"
  fi
fi

# List all environment variables
printenv |

# Filter variables that start with GLOBAL_ENV_
grep -E '^GLOBAL_ENV_' |

# Exclude GLOBAL_ENV_HOME_USER and GLOBAL_ENV_VSCODE_TUNNEL_NAME
grep -vE '^(GLOBAL_ENV_HOME_USER|GLOBAL_ENV_VSCODE_TUNNEL_NAME)=' |

# Remove the GLOBAL_ENV_ prefix
sed 's/^GLOBAL_ENV_//' |

# Append the result to /etc/environment if not already present
while IFS= read -r line
do
  if ! grep -q "^${line%=*}=" /etc/environment; then
    echo "" >> /etc/environment
    echo "export $line" >> /etc/environment
  fi
done

# List all environment variables
printenv |

# Filter variables that start with USER_ENV_
grep -E '^USER_ENV_' |

# Remove the USER_ENV_ prefix
sed 's/^USER_ENV_//' |

# Append the result to /usr/bin/.bashrc
while IFS= read -r line
do
  # Check if the current user is root
  if [ "$(id -u)" = "0" ]; then
    echo "" >> /usr/bin/.bashrc
    echo "export $line" >> /usr/bin/.bashrc
  else
    echo "" >> /home/${HOME_USER}/.bashrc
    echo "export $line" >> /home/${HOME_USER}/.bashrc
  fi
done

USER="$HOME_USER"
if ! id -u $HOME_USER > /dev/null 2>&1; then
  sudo adduser --disabled-password --gecos "" --uid 1000 ${HOME_USER}
  sudo echo "$HOME_USER ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers.d/nopasswd > /dev/null

  # Creating .vscode folder if it doesn't exist
  if [ ! -d "/home/${HOME_USER}/.vscode" ]; then
    sudo mkdir -p /home/${HOME_USER}/.vscode
  fi

  # Changing the property of the directory /home/${HOME_USER}/.vscode
  sudo chown -R ${HOME_USER} /home/${HOME_USER}/.vscode
fi

# Then execute entrypoint.sh
if [ "$HOME_USER" != "$(whoami)" ]; then
  exec sudo -u $HOME_USER bash -c "source /etc/environment; /usr/bin/entrypoint.sh"
else
  find /home/${HOME_USER} -not -path "/home/${HOME_USER}/.ssh/*" -not -name ".ssh" -exec sudo chown ${HOME_USER} {} \;
fi

# Move the .bashrc file to the user's home directory if it doesn't exist
if [ ! -f "/home/${HOME_USER}/.bashrc" ]; then
  sudo mv /usr/bin/.bashrc /home/${HOME_USER}/.bashrc
  sudo chown ${HOME_USER} /home/${HOME_USER}/.bashrc
else
  sudo rm -f /usr/bin/.bashrc
fi

# Move the .profile file to the user's home directory if it doesn't exist
if [ ! -f "/home/${HOME_USER}/.profile" ]; then
  sudo mv /usr/bin/.profile /home/${HOME_USER}/.profile
  sudo chown ${HOME_USER} /home/${HOME_USER}/.profile
else
  sudo rm -f /usr/bin/.profile
fi

# Find .sh files in /usr/bin/custom-scripts and execute them in order
for script in $(find /usr/bin/custom-scripts -name "*.sh" | sort); do
  chmod +x $script
  if [[ $script == *"sudo"* ]]; then
    sudo -u $HOME_USER bash -c "source /etc/environment; sudo $script"
  else
    sudo -u $HOME_USER bash -c "source /etc/environment; $script"
  fi
done

#Creating extensions folder
if [ ! -d "/home/${HOME_USER}/.config/Code" ]; then
  sudo mkdir -p /home/${HOME_USER}/.config/Code
fi
sudo chmod -R a+rwX /home/${HOME_USER}/.config/Code

if [ ! -d "/home/${HOME_USER}/.vscode-server" ]; then
  sudo mkdir -p /home/${HOME_USER}/.vscode-server
fi
sudo chmod -R a+rwX /home/${HOME_USER}/.vscode-server

if [ ! -d "/home/${HOME_USER}/.vscode-server-insiders" ]; then
  sudo mkdir -p /home/${HOME_USER}/.vscode-server-insiders
fi
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
        sudo su ${HOME_USER} -c "code --install-extension $extension"
    done
    sudo cp -R /home/${HOME_USER}/.vscode/* /home/${HOME_USER}/.vscode-server
    sudo cp -R /home/${HOME_USER}/.vscode/* /home/${HOME_USER}/.vscode-server-insiders
    sudo chmod -R a+rwX /home/${HOME_USER}/.vscode
    sudo chmod -R a+rwX /home/${HOME_USER}/.vscode-server
    sudo chmod -R a+rwX /home/${HOME_USER}/.vscode-server-insiders
else
    echo "File extensions.json not found"
fi

if [[ -v VSCODE_TUNNEL_NAME && -n "${VSCODE_TUNNEL_NAME}" ]]; then
    sudo su ${HOME_USER} -c "code tunnel --accept-server-license-terms --name ${VSCODE_TUNNEL_NAME}"
else
    sudo su ${HOME_USER} -c "code tunnel --accept-server-license-terms"
fi
