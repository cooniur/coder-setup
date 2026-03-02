#!/bin/bash

# Define the file path
SSHRC_FILE="/etc/ssh/sshrc"
CMD="/usr/lib/update-notifier/apt-check --human-readable"

# Ensure the command isn't already in the file to avoid duplicates
if grep -Fxq "$CMD" "$SSHRC_FILE" 2>/dev/null; then
    echo "Notification command is already present in $SSHRC_FILE."
else
    # Append the command to the file (requires sudo)
    echo "$CMD" | sudo tee -a "$SSHRC_FILE" > /dev/null
    echo "Added update notification to $SSHRC_FILE."
fi

# Ensure the file has the correct permissions
sudo chmod 644 "$SSHRC_FILE"
