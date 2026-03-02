# Coder Setup Utility for Ubuntu Server

This script automates the installation and management of [Coder](https://coder.com/) on a fresh Ubuntu 24.04 server, configured to support Nvidia GPU pass-through for AI workloads (like Ollama).

## Prerequisites

Before running the setup, ensure you have:

- **Local Machine:** `rsync` installed on your local machine (standard on macOS and Linux).
- **Remote Server:** A remote Linux server with fresh install of Ubuntu Server 24.04 LTS with SSH access
- **Remote Server Hardware:** Physical Nvidia GPU installed.
- **Remote User:** Root access or `sudo` privileges.

### Local Domain & DNS Note

If you are using a domain name that only exists on your local network (e.g., `coder.local` or `dev.home`), you **must have a self-hosted DNS server** configured to resolve that domain to the IP address of your remote server.

## Setup Workflow

Clone this repository to your local machine.

Follow these steps in order to prepare your local environment and deploy to the server.

### 1. Set up SSH Key Authentication

Run this script first to generate an SSH key pair (if you don't have one) and copy it to your remote server. This enables passwordless login.

```bash
./init-scripts/setup-ssh-key.sh <remote_user> <remote_host>
```

### 2. Upload Project Files

Run this script to upload the contents of this project directory to your remote server.

```bash
./init-scripts/upload-project.sh <remote_user> <remote_host>
```

### 3. Configure Your Remote Server

SSH into to your remote server and execute these scripts to configure your remote server.

```bash
ssh <remote_user>@<remote_host>
cd ~/coder-setup

# (REQUIRED) Install NVidia driver & CUDA. Make sure you follow the instructions to reboot.
./scripts/install-nvidia-cuda.sh

# (RECOMMENDED) Setup passwordless SSH (if you haven't) to enhance security.
sudo ./scripts/setup-passwordless-ssh.sh

# (optional) Ensure disk space is fully allocated to the system
./scripts/extend-disk.sh 

# (optional) Optimize power settings for remote server if you are using a bare metal machine.
./scripts/setup-power.sh

# (optional) Sets a large Terminus 16x32 font, which is generally good for high-resolution displays if needed.
./scripts/set-console-font.sh

# (optional) Simple reminder on package updates upon SSH logins, if your login doesn't output any messages.
./scripts/setup-ssh-login-message.sh
```

### 4. Run Coder Setup on Remote Server

SSH into to your remote server and execute the coder-setup script.

```bash
ssh <remote_user>@<remote_host>
cd ~/coder-setup
sudo ./coder-setup install --domain <your-domain.com>
```

## How it Works

Persistence: Coder data is stored in /opt/coder.

Auto-start: The script configures Docker to start on boot, and Coder containers to restart: always.

Nvidia Passthrough: Installs the Nvidia Container Toolkit to allow Docker containers to utilize the physical GPU.
