# Aleleba VSCode Dockerfile Configuration

This repository contains a Dockerfile configuration for use with Visual Studio Code with dev tunnel.

## Getting Started

To run the Docker container, follow these steps:

1. Clone this repository to your local machine.
2. Open the integrated terminal in Visual Studio Code.
3. Run the Docker container by running the following command: `docker run -it -e HOME_USER=custom-home-user -e VSCODE_TUNNEL_NAME=vscode-ssh-remote-server -v /path/to/extensions.json:/home/extensions.json aleleba/vscode`

### Environment Variables

The following environment variables can be set when running the Docker container:

- `HOME_USER`: The username of the user running the container. This is used to set the correct permissions on files created in the container.
- `VSCODE_TUNNEL_NAME`: The name of the SSH tunnel used by Visual Studio Code to connect to the container.

### Custom Environment Variables

You can set custom environment variables for the `HOME_USER` by using the `USER_ENV_` prefix when running the Docker container. These environment variables will be created in the `/home/${HOME_USER}/.bashrc` file without the `USER_ENV_` prefix.

For example, if you want to set a custom environment variable named `MY_VARIABLE` for the `HOME_USER`, you can do so by setting the `USER_ENV_MY_VARIABLE` environment variable when running the Docker container:

```bash
docker run -it -e HOME_USER=custom-home-user -e USER_ENV_MY_VARIABLE=my_value -e VSCODE_TUNNEL_NAME=vscode-ssh-remote-server -v /path/to/extensions.json:/home/extensions.json aleleba/vscode
```
In this example, MY_VARIABLE will be set to my_value in the /home/${HOME_USER}/.bashrc file.

### Global Environment Variables

You can set global environment variables by using the `GLOBAL_ENV_` prefix when running the Docker container. These environment variables will be created in the `/etc/environment` file without the `GLOBAL_ENV_` prefix.

For example, if you want to set a global environment variable named `MY_GLOBAL_VARIABLE`, you can do so by setting the `GLOBAL_ENV_MY_GLOBAL_VARIABLE` environment variable when running the Docker container:

```bash
docker run -it -e HOME_USER=custom-home-user -e GLOBAL_ENV_MY_GLOBAL_VARIABLE=my_global_value -e VSCODE_TUNNEL_NAME=vscode-ssh-remote-server -v /path/to/extensions.json:/home/extensions.json aleleba/vscode
```
In this example, MY_GLOBAL_VARIABLE will be set to my_global_value in the /etc/environment file.

### Adding VSCode Extensions

To add VSCode extensions to the container, create a JSON file with an array of objects containing the extension details you want to install, the only Mandatory field is uniqueIdentifier and follow this structure. For example:
```
[
    {
        "extensionsGroup": {
            "description": "Extensions of Spanish Language Pack",
            "extensions": [
                {
                    "name": "Spanish Language Pack for Visual Studio Code",
                    "notes": "Extension of Spanish Language Pack for Visual Studio Code",
                    "uniqueIdentifier": "ms-ceintl.vscode-language-pack-es"
                }
            ]
        }
    },
    {
        "extensionsGroup": {
            "description": "Extensions of Github Copilot",
            "extensions": [
                {
                    "name": "GitHub Copilot",
                    "notes": "Extension of GitHub Copilot",
                    "uniqueIdentifier": "github.copilot"
                },
                {
                    "name": "GitHub Copilot Chat",
                    "notes": "Extension of GitHub Copilot Chat",
                    "uniqueIdentifier": "github.copilot-chat"
                }
            ]
        }
    }
]
```

Save this file as `extensions.json` and add it as a volume when running the Docker container on /home/extensions.json. For example:
`docker run -it -e HOME_USER=custom-home-user -e VSCODE_TUNNEL_NAME=vscode-ssh-remote-server -v /path/to/extensions.json:/home/extensions.json aleleba/vscode`


The extensions will be installed automatically after the container is created.

### Using Docker Compose

Alternatively, you can use Docker Compose to run the container with the `aleleba/vscode` image and the `HOME_USER` and `VSCODE_TUNNEL_NAME` environment variables set. Here's an example `docker-compose.yml` file:

```
version: '3'

services:
  vscode:
    image: aleleba/vscode
    environment:
      HOME_USER: custom-home-user
      VSCODE_TUNNEL_NAME: vscode-ssh-remote-server
    volumes:
      - /path/to/extensions.json:/home/extensions.json
```

You can run this `docker-compose.yml` file by navigating to the directory where it is saved and running the following command: `docker-compose up -d`

This will start the container in the background and output the container ID. You can then use the `docker ps` command to view the running container.

## Adding Custom Scripts

In this project, you can add custom scripts that will be automatically executed when the application starts. The `/usr/bin/custom-scripts` directory in the Docker container is a volume that maps to a directory on your host machine. Here's how you can add a custom script:

### 1. Create a new script file

Create a new file with a `.sh` extension in the directory on your host machine that maps to the `/usr/bin/custom-scripts` volume in the Docker container. For example, if the `/usr/bin/custom-scripts` volume maps to the `./custom-scripts` directory on your host machine, you can create a file named `install_node.sh` in the `./custom-scripts` directory.

```bash
touch ./custom-scripts/install_node.sh
```

### 2. Write your script

Open the file in a text editor and write your script. Here's an example that installs Node.js using NVM:

```bash
#!/bin/bash
# Installing Node.js with NVM
sudo curl -O https://raw.githubusercontent.com/creationix/nvm/master/install.sh
bash install.sh
source ~/.nvm/nvm.sh
nvm install --lts
nvm alias default lts/*
nvm use default && npm install -g yo generator-code
nvm use default && npm install -g @vscode/vsce
```
The #!/bin/bash line at the top of the script tells the system that this script should be run with the Bash shell.

#### Note on sudo privileges

If the script name includes the word "sudo", the script will be run with root privileges. This is useful if your script needs to perform operations that require superuser privileges.

For instance, if you have a script named `install_sudo_package.sh`, this script will be run with root privileges due to the inclusion of "sudo" in the file name.

Please be aware of the security implications when running scripts with root privileges. Ensure that your script does not perform any unsafe or destructive operations when run with these privileges.

### 3. Run your Docker container
When you start your Docker container, all .sh files in the /usr/bin/custom-scripts directory will be automatically executed in alphabetical order. The environment variables from the /etc/environment file will be loaded before each script is executed.

Remember to replace install_node.sh with the name of your script and ./custom-scripts with the actual path to the directory on your host machine that maps to the /usr/bin/custom-scripts volume in the Docker container.

## Using this image as a base image in a Dockerfile

To use this image as a base image in a Dockerfile, you can add the following line to the top of your Dockerfile and you can install any additional packages you need, here an example installing nvm and nodejs in a `Dockerfile`:

```
FROM aleleba/vscode:latest

ENV HOME_USER=vscode

RUN sudo adduser --disabled-password --gecos "" --uid 1000 ${HOME_USER}
RUN sudo echo "$HOME_USER ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers.d/nopasswd > /dev/null

USER ${HOME_USER}
WORKDIR /home/${HOME_USER}

# Installing node.js and NVM
SHELL ["/bin/bash", "--login", "-i", "-c"]
RUN curl https://raw.githubusercontent.com/creationix/nvm/master/install.sh | bash
RUN nvm install --lts
RUN nvm alias default lts/*
SHELL ["/bin/sh", "-c"]
RUN echo 'source ~/.nvm/nvm.sh' >> ~/.bashrc
# Finishing installing node.js and NVM

```



> **Note:** If you are using this image as a base image in a Dockerfile, ensure that the value of `HOME_USER` is the same as the one you will use when creating the container. This is necessary to ensure that all configurations and packages are installed in the correct user directory.

> **Note:** To grant access to the server, please log into https://github.com/login/device and use the code XXXX-XXXX. You can view the container logs to get the code.

## Contributing

If you'd like to contribute to this project, please fork the repository and create a pull request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

I hope this helps! Let me know if you have any further questions.
