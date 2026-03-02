#!/bin/bash

# 1. Pre-check: Show current status
echo "--- CURRENT DISK STATUS (BEFORE) ---"
df -h /
echo ""
sudo vgs
echo "------------------------------------"

# 2. Identify the Logical Volume path automatically
LV_PATH=$(sudo lvs --noheadings -o lv_path | tr -d '[:space:]' | head -n 1)

if [ -z "$LV_PATH" ]; then
    echo "Error: Could not automatically detect the Logical Volume path."
    exit 1
fi

# 3. Ask for confirmation
read -p "Do you want to extend '$LV_PATH' to use all available free space? [y/N]: " CONFIRM
if [[ $CONFIRM != "y" && $CONFIRM != "Y" ]]; then
    echo "Operation cancelled."
    exit 0
fi

# 4. Perform the extension
echo "Extending Logical Volume at '$LV_PATH'..."
sudo lvextend -l +100%FREE "$LV_PATH"

echo "Resizing Filesystem at '$LV_PATH'..."
sudo resize2fs "$LV_PATH"

# 5. Final check
echo "------------------------------------"
echo "--- UPDATED DISK STATUS (AFTER) ---"
df -h /
