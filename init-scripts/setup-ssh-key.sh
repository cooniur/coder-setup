#!/bin/bash

# ==========================================
# Configuration
# ==========================================
# Change this if you use a different key name (e.g., id_ed25519)
SSH_PUB_KEY="$HOME/.ssh/id_rsa.pub"
SSH_PRIV_KEY="$HOME/.ssh/id_rsa"

# ==========================================
# Usage check
# ==========================================
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <remote_user> <remote_host>"
    exit 1
fi

REMOTE_USER=$1
REMOTE_HOST=$2

# ==========================================
# Execution
# ==========================================

echo "Checking for local SSH key: $SSH_PUB_KEY"
echo "--------------------------------------------"

# Check if public key exists
if [ ! -f "$SSH_PUB_KEY" ]; then
    echo "Public key not found."
    read -p "Would you like to generate a new SSH key pair? [y/N]: " confirm
    if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
        echo "Generating key pair..."
        # -t rsa -b 4096 is a secure default
        ssh-keygen -t rsa -b 4096 -f "$SSH_PRIV_KEY" -N ""
    else
        echo "SSH key generation cancelled. Exiting."
        exit 1
    fi
fi

echo "Setting up SSH key for: $REMOTE_USER@$REMOTE_HOST"
echo "--------------------------------------------"

# Use ssh-copy-id to securely copy the key
ssh-copy-id -i "$SSH_PUB_KEY" "$REMOTE_USER@$REMOTE_HOST"

echo "--------------------------------------------"
echo "SSH key setup complete. Try logging in without a password:"
echo "ssh $REMOTE_USER@$REMOTE_HOST"
