#!/bin/bash

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
# Path Configuration
# ==========================================

# 1. Try to find the git root directory
if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    PROJECT_DIR=$(git rev-parse --show-toplevel)
else
    # 2. Fallback: Find the directory where this script is located
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
    # Assuming the script is one level down from root (e.g., /scripts/upload.sh)
    # Adjust "../" if your directory structure is deeper.
    PROJECT_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
fi

# Get the name of the project directory
PROJECT_NAME=$(basename "$PROJECT_DIR")

# Set destination to home directory + project name
REMOTE_DEST="/home/$REMOTE_USER/$PROJECT_NAME"

# ==========================================
# Execution
# ==========================================

echo "Uploading project directory from: $PROJECT_DIR"
echo "To: $REMOTE_USER@$REMOTE_HOST:$REMOTE_DEST"
echo "--------------------------------------------"

# Use rsync for efficient transfer, explicitly telling it to 
# copy the contents of PROJECT_DIR into REMOTE_DEST
rsync -avz --delete --exclude '.git' --exclude '__pycache__' \
    "$PROJECT_DIR/" "$REMOTE_USER@$REMOTE_HOST:$REMOTE_DEST/"

echo "--------------------------------------------"
echo "Upload complete."
