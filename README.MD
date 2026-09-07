# Setting Up a New Developer Laptop

This repository contains configuration and scripts for recreating my development environment on a new laptop or VDE.

## Note Taking

I use [Obsidian](https://obsidian.md/) for note taking. Notes are stored as Markdown files and synced to a Git repository.

### Obsidian Plugins

Install the following community plugins:

- **Dataview:** Creates dashboards for tracking tasks and other metadata.
- **Git:** Automatically synchronises the vault with GitHub.
- **Templater:** Applies templates to notes in different vault directories.

## Development Tools

Visual Studio Code is the primary IDE.

Development takes place on an Ubuntu VDE connected through VS Code Remote SSH. A Fedora-based Distrobox provides the terminal development environment.

### VS Code Extensions

Install the following extensions:

- Remote - SSH
- Python
- Pylance
- Terraform
- YAML
- Markdown previewer
- One Dark Pro theme

## Fedora Devbox with Distrobox

The underlying VDE may need to be replaced when its Ubuntu version is upgraded. Distrobox reduces the amount of setup that must be repeated by providing a portable, Fedora-based development environment.

The Devbox image includes:

- Zsh and Powerlevel10k
- Python
- Poetry
- Terraform
- AWS CLI v2
- Docker CLI
- Git
- Common terminal and build tools

### Architecture

```text
Local workstation
└── Visual Studio Code
    └── Remote SSH
        └── Ubuntu VDE
            ├── Git repositories
            ├── Docker Engine
            ├── Source-controlled shell configuration
            └── Fedora Distrobox
                ├── Python and Poetry
                ├── Terraform
                ├── AWS CLI
                ├── Docker CLI
                └── Development dependencies
```

Visual Studio Code edits files directly on the VDE.

Git repositories and shell configuration are stored in the VDE home directory. Distrobox shares this home directory, so the same files are available inside Devbox.

Docker Engine runs on the VDE. The Docker CLI inside Devbox connects to that daemon through `/var/run/docker.sock`. This is not Docker-in-Docker.

### Repository Structure

```text
ch-laptop-setup/
├── Dockerfile
├── README.md
├── dotfiles/
│   ├── .zshrc
│   └── .p10k.zsh
└── scripts/
    ├── enter-devbox.sh
    └── setup-docker-access.sh
```

## Initial VDE Setup

### Prerequisites

The Ubuntu VDE must have:

- Docker Engine
- Distrobox
- Zsh
- Git
- Linuxbrew (Homebrew)

Docker must work without `sudo` on the VDE before configuring Devbox.

### Install the Shell Configuration

The source-controlled Zsh files are stored under `dotfiles/`.

Link them into the VDE home directory:

```bash
ln -sfn \
  "$HOME/Documents/git/ch-laptop-setup/dotfiles/.zshrc" \
  "$HOME/.zshrc"

ln -sfn \
  "$HOME/Documents/git/ch-laptop-setup/dotfiles/.p10k.zsh" \
  "$HOME/.p10k.zsh"
```

Verify the links:

```bash
readlink -f ~/.zshrc
readlink -f ~/.p10k.zsh
```

Check their syntax:

```bash
zsh -n ~/.zshrc
zsh -n ~/.p10k.zsh
```

No output means the syntax is valid.

Restart Zsh:

```bash
exec zsh
```

The same configuration is used on the VDE and inside Devbox because Distrobox shares the VDE home directory.

Powerlevel10k displays a `DEVBOX` segment whenever `$CONTAINER_ID` is set.

## Build the Devbox Image

From the root of this repository:

```bash
docker build \
  --tag devbox:latest \
  .
```

Confirm that the image exists:

```bash
docker image ls devbox
```

Test the main tools:

```bash
docker run --rm devbox:latest python3 --version
docker run --rm devbox:latest poetry --version
docker run --rm devbox:latest terraform version
docker run --rm devbox:latest aws --version
docker run --rm devbox:latest zsh --version
docker run --rm devbox:latest docker --version
```

## Create Devbox

Create the Distrobox from the local image:

```bash
distrobox create \
  --name devbox \
  --image devbox:latest
```

Enter it:

```bash
distrobox enter devbox
```

The initial entry may take longer while Distrobox installs its integration packages.

Verify that the shell is inside Devbox:

```bash
echo "$CONTAINER_ID"
cat /etc/os-release
```

Expected results include:

```text
devbox
```

and Fedora operating system information.

Verify the installed tools:

```bash
python3 --version
poetry --version
terraform version
aws --version
docker --version
git --version
```

## Configure Docker Access

Docker Engine runs on the VDE, while Devbox contains the Docker CLI.

The first attempt to use Docker inside a newly created Devbox may return:

```text
permission denied while trying to connect to the Docker API at unix:///var/run/docker.sock
```

Run the setup script from inside Devbox:

```bash
cd ~/Documents/git/ch-laptop-setup
./scripts/setup-docker-access.sh
```

If the script is not executable:

```bash
chmod +x scripts/setup-docker-access.sh
```

The script detects the numeric group ID that owns the Docker socket and adds the Devbox user to the matching group.

Restart Devbox to activate the new group membership:

```bash
exit
distrobox stop devbox
distrobox enter devbox
```

Verify access:

```bash
id
docker ps -a
docker run --rm hello-world
```

The `id` output should include the group that owns the Docker socket, for example:

```text
998(docker)
```

This configuration persists for the lifetime of the Devbox container. The setup script must be run again if Devbox is deleted and recreated.

> Docker socket access grants substantial control over the VDE. Do not make `/var/run/docker.sock` world-writable.

### Test Docker Bind Mounts

Repositories stored under the shared VDE home directory can be bind-mounted into application containers:

```bash
docker run --rm \
  --mount type=bind,src="$PWD",dst=/workspace \
  --workdir /workspace \
  alpine:latest \
  ls -la
```

The source path must exist on the VDE because the Docker daemon runs on the VDE.

Repositories under the following path are suitable:

```text
~/Documents/git
```

## Automatically Enter Devbox from VS Code

VS Code remains connected to the Ubuntu VDE through Remote SSH. New integrated terminals are configured to run `enter-devbox.sh`, which enters Devbox automatically.

The launcher:

1. Initialises the Linuxbrew PATH.
2. Checks whether Devbox already exists.
3. Enters the existing Devbox.
4. Creates Devbox if the container is missing but the image exists.
5. Falls back to a VDE Zsh shell if Devbox cannot be entered.

Ensure the launcher is executable:

```bash
chmod +x \
  ~/Documents/git/ch-laptop-setup/scripts/enter-devbox.sh
```

Check its syntax:

```bash
bash -n \
  ~/Documents/git/ch-laptop-setup/scripts/enter-devbox.sh
```

Test it manually:

```bash
~/Documents/git/ch-laptop-setup/scripts/enter-devbox.sh
```

### Configure the VS Code Terminal Profile

While connected to the VDE:

1. Open the Command Palette.
2. Select `Preferences: Open Remote Settings (JSON)`.
3. Add the following settings:

```json
{
  "terminal.integrated.profiles.linux": {
    "Devbox": {
      "path": "/home/connor.hindle/Documents/git/ch-laptop-setup/scripts/enter-devbox.sh",
      "icon": "terminal-linux"
    },
    "VDE Zsh": {
      "path": "/usr/bin/zsh",
      "args": ["-l"],
      "icon": "terminal"
    }
  },
  "terminal.integrated.defaultProfile.linux": "Devbox"
}
```

If the remote settings file already contains other properties, merge these properties into the existing JSON rather than replacing the whole file.

Close existing integrated terminals and create a new terminal.

New terminals should enter Devbox automatically and display the `DEVBOX` Powerlevel10k segment.

When direct access to the Ubuntu VDE is needed, use the terminal profile dropdown and select `VDE Zsh`.

This configuration only places the integrated terminal inside Devbox. VS Code Server and Remote SSH continue to run on the VDE.

## Normal Development Workflow

### Start a Session

Connect to the VDE through VS Code Remote SSH and open a new integrated terminal.

The terminal should enter Devbox automatically.

Confirm this using the prompt or:

```bash
echo "$CONTAINER_ID"
```

Open a repository:

```bash
cd ~/Documents/git/my-project
```

## Updating Devbox

Update the `Dockerfile` when changing:

- Fedora version
- Python packages