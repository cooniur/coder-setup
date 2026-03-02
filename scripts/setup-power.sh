#!/bin/bash

# ==========================================
# Configuration
# ==========================================
BLANK_TIME=30
LOGIND_CONF="/etc/systemd/logind.conf"
GRUB_FILE="/etc/default/grub"

echo "Starting system configuration updates..."
echo "------------------------------------------"

# ==========================================
# 1. Update Logind Settings (Lid/Power/Idle)
# ==========================================
echo "Configuring systemd-logind..."
sudo cp "$LOGIND_CONF" "${LOGIND_CONF}.bak"

sudo sed -i 's/^#\?HandlePowerKey=.*/HandlePowerKey=lock/' "$LOGIND_CONF"
sudo sed -i 's/^#\?HandleLidSwitch=.*/HandleLidSwitch=ignore/' "$LOGIND_CONF"
sudo sed -i 's/^#\?HandleLidSwitchExternalPower=.*/HandleLidSwitchExternalPower=ignore/' "$LOGIND_CONF"
sudo sed -i 's/^#\?HandleLidSwitchDocked=.*/HandleLidSwitchDocked=ignore/' "$LOGIND_CONF"
sudo sed -i "s/^#\?IdleAction=.*/IdleAction=blank/" "$LOGIND_CONF"
sudo sed -i "s/^#\?IdleActionSec=.*/IdleActionSec=${BLANK_TIME}s/" "$LOGIND_CONF"

# ==========================================
# 2. Update GRUB Settings (Kernel Console)
# ==========================================
echo "Configuring GRUB for console blanking..."
sudo cp "$GRUB_FILE" "${GRUB_FILE}.bak"

if grep -q "consoleblank=" "$GRUB_FILE"; then
    sudo sed -i "s/consoleblank=[0-9]*/consoleblank=$BLANK_TIME/g" "$GRUB_FILE"
else
    # Appends to the end of the cmdline string
    sudo sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=\"/GRUB_CMDLINE_LINUX_DEFAULT=\"consoleblank=$BLANK_TIME /g" "$GRUB_FILE"
fi

# ==========================================
# 3. Apply Changes
# ==========================================
echo "------------------------------------------"
echo "Applying changes..."

# Restart Logind
sudo systemctl restart systemd-logind

# Update Grub
sudo update-grub

echo "------------------------------------------"
echo "Setup Complete!"
echo " - Lid Close (Any state): Stays ON"
echo " - Power Key (Short Tap): Lock Screen"
echo " - Auto Shutdown Display After: $BLANK_TIME Seconds"
echo "------------------------------------------"
echo "NOTE: A reboot is required for GRUB changes to take effect."
