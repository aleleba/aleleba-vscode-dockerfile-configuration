#!/bin/bash
set -eu

if [[ -z "${HOME_USER-}" ]]; then
    HOME_USER="vscode"
fi

# Detectar UID/GID del volumen montado en /home/${HOME_USER} (si ya existe),
# permitir override explícito vía HOST_UID/HOST_GID, y por defecto usar 1000.
DETECTED_UID=$(stat -c '%u' "/home/${HOME_USER}" 2>/dev/null || echo 1000)
DETECTED_GID=$(stat -c '%g' "/home/${HOME_USER}" 2>/dev/null || echo 1000)
TARGET_UID="${HOST_UID:-$DETECTED_UID}"
TARGET_GID="${HOST_GID:-$DETECTED_GID}"

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
  # Ensure the user's home directory exists before writing .bashrc
  if [ ! -d "/home/${HOME_USER}" ]; then
    sudo mkdir -p "/home/${HOME_USER}"
    sudo chown root:root "/home/${HOME_USER}"
    sudo chmod 755 "/home/${HOME_USER}"
  fi

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
if ! id -u "$HOME_USER" > /dev/null 2>&1; then
  sudo groupadd -g "${TARGET_GID}" "${HOME_USER}" 2>/dev/null || true
  sudo adduser --disabled-password --gecos "" --uid "${TARGET_UID}" --gid "${TARGET_GID}" "${HOME_USER}"
  sudo echo "$HOME_USER ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers.d/nopasswd > /dev/null

  # Creating .vscode folder if it doesn't exist
  if [ ! -d "/home/${HOME_USER}/.vscode" ]; then
    sudo mkdir -p /home/${HOME_USER}/.vscode
  fi

  # Changing the property of the directory /home/${HOME_USER}/.vscode
  sudo chown -R ${HOME_USER} /home/${HOME_USER}/.vscode
else
  # Usuario ya existe (imagen/volumen reusado) — resincronizar UID/GID si cambiaron
  CURRENT_UID=$(id -u "${HOME_USER}")
  CURRENT_GID=$(id -g "${HOME_USER}")
  CURRENT_GROUP=$(id -gn "${HOME_USER}")

  if [ "$CURRENT_UID" != "$TARGET_UID" ] || [ "$CURRENT_GID" != "$TARGET_GID" ]; then
    if [ "$CURRENT_GID" != "$TARGET_GID" ]; then
      sudo groupmod -g "${TARGET_GID}" "${CURRENT_GROUP}"
    fi
    if [ "$CURRENT_UID" != "$TARGET_UID" ]; then
      sudo usermod -u "${TARGET_UID}" "${HOME_USER}"
    fi
    sudo find / -xdev \( -user "${CURRENT_UID}" -o -group "${CURRENT_GID}" \) \
      -exec chown -h "${TARGET_UID}:${TARGET_GID}" {} + 2>/dev/null || true
  fi
fi

# Then execute entrypoint.sh
if [ "$HOME_USER" != "$(whoami)" ]; then
  exec sudo -u $HOME_USER bash -c "source /etc/environment; /usr/bin/entrypoint.sh"
else
  sudo find "/home/${HOME_USER}" -xdev -exec chown "${HOME_USER}" {} + 2>/dev/null || true
  if [ -d "/home/${HOME_USER}/.ssh" ]; then
    sudo chmod 755 /home/${HOME_USER}/.ssh
    sudo chmod -R 600 /home/${HOME_USER}/.ssh/*
    # Check if any .pub files exist in the .ssh directory
    for file in /home/${HOME_USER}/.ssh/*.pub; do
      if [ -f "$file" ]; then
        sudo chmod 644 "$file"
      fi
    done
    # Check if the known_hosts file exists in the .ssh directory
    if [ -f "/home/${HOME_USER}/.ssh/known_hosts" ]; then
      sudo chmod 644 /home/${HOME_USER}/.ssh/known_hosts
    fi
  fi
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
  # Ensure the script is executable
  if [ ! -x $script ]; then
    sudo chmod +x $script
  fi

  # Execute the script as the configured user
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
        sudo su ${HOME_USER} -c "code --install-extension $extension --force"
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
