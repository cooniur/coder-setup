#!/bin/bash
set -e

echo "--- NVIDIA & CUDA Auto-Discovery Tool ---"

sudo apt update && sudo apt upgrade -y

# 1. Detect Recommended Driver
# Scans hardware to find the best driver branch (e.g., 590)
echo
echo "[1/6] Detecting recommended NVIDIA driver..."
echo ""
RECOMMENDED_DRIVER=$(ubuntu-drivers devices 2>/dev/null | grep "recommended" | grep -oP 'nvidia-driver-\K[0-9]+' | head -n 1)
if [ -z "$RECOMMENDED_DRIVER" ]; then
    echo "Could not automatically detect driver. Please install manually."
    exit 1
fi
echo "Recommended driver found: $RECOMMENDED_DRIVER"

# 2. Add CUDA Keyring for Ubuntu 24.04 to probe latest versions
echo ""
echo "[2/6] Add CUDA Keyring for Ubuntu 24.04 to probe latest versions..."
echo ""
CUDA_KEYRING_FILE=cuda-keyring_1.1-1_all.deb
if [ ! -f "/tmp/$CUDA_KEYRING_FILE" ]; then
    # Download the package directly to /tmp
    wget -q -P /tmp "https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/${CUDA_KEYRING_FILE}"
    # Install from /tmp
    sudo dpkg -i "/tmp/$CUDA_KEYRING_FILE"
    sudo apt update -q
    rm "/tmp/$CUDA_KEYRING_FILE"
fi

# 3. Detect Latest CUDA Toolkit
# Finds the highest versioned toolkit in the repository
echo ""
echo "[3/6] Detect Latest CUDA Toolkit..."
echo ""
LATEST_CUDA_PKG=$(apt-cache search cuda-toolkit | grep -oP 'cuda-toolkit-\K[0-9]+-[0-9]+' | sort -V | tail -n 1)
LATEST_CUDA_VER=${LATEST_CUDA_PKG//-/. }
if [ -z "$LATEST_CUDA_PKG" ]; then
    echo "Could not automatically detect latest CUDA Toolkit version. Please install manually."
    exit 1
fi
echo "Latest CUDA Toolkit version found: $LATEST_CUDA_VER"

# 4. Confirmation Prompt
echo ""
echo "[4/6] Auto-discovery results for your RTX 3070:"
echo " - Driver: nvidia-open-${RECOMMENDED_DRIVER}"
echo " - CUDA:   cuda-toolkit-${LATEST_CUDA_PKG} (v${LATEST_CUDA_VER})"
echo ""
read -p "Do you want to proceed with this installation? (y/n): " confirm
if [[ $confirm != [yY] ]]; then
    echo "Installation cancelled by user."
    exit 1
fi

# 5. Execute Installation
echo ""
echo "[5/6] Installing... This may take several minutes."
echo ""
sudo apt install -y -o Dpkg::Options::="--force-overwrite" \
    dkms linux-headers-$(uname -r) \
    nvidia-driver-${RECOMMENDED_DRIVER}-server-open \
    nvidia-utils-${RECOMMENDED_DRIVER}-server \
    nvidia-dkms-${RECOMMENDED_DRIVER}-server-open \
    cuda-toolkit-${LATEST_CUDA_PKG}

# 6. Environment Setup
echo ""
echo "[6/6] Environment setup..."
echo ""
CUDA_DIR="/usr/local/cuda-${LATEST_CUDA_VER// /}"
if [ -d "$CUDA_DIR" ]; then
    # Add to .bashrc
    grep -q "$CUDA_DIR/bin" ~/.bashrc || echo "export PATH=$CUDA_DIR/bin:\$PATH" >> ~/.bashrc
    grep -q "$CUDA_DIR/lib64" ~/.bashrc || echo "export LD_LIBRARY_PATH=$CUDA_DIR/lib64:\$LD_LIBRARY_PATH" >> ~/.bashrc
    
    # System-wide library link
    echo "$CUDA_DIR/lib64" | sudo tee /etc/ld.so.conf.d/cuda-auto.conf > /dev/null
    sudo ldconfig
fi

echo "--------------------------------------------------------"
echo "COMPLETED SUCCESSFULLY"
echo "--------------------------------------------------------"
echo "IMPORTANT: Ubuntu 24.04 requires a MOK Enrollment on reboot."
echo "1. Run: sudo reboot"
echo "2. At the Blue Screen: Enroll MOK -> Continue -> Yes -> [Your Password]"
echo "3. After reboot, test with: nvidia-smi"
echo "--------------------------------------------------------"
