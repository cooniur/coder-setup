#!/bin/bash

# Define the font settings
FONT="Lat2-Terminus32x16.psfu.gz"
SIZE="16x32"

echo "Setting console font to Terminus $SIZE..."

# Update the console-setup configuration file
sudo sed -i "s/^FONTFACE=.*/FONTFACE=\"Terminus\"/" /etc/default/console-setup
sudo sed -i "s/^FONTSIZE=.*/FONTSIZE=\"$SIZE\"/" /etc/default/console-setup

# Apply the settings immediately
sudo setupcon

echo "Font size updated permanently."
