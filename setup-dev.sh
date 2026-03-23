#!/bin/bash

set -e
trap "echo 'Exiting...'; exit" INT

# --- 0. Email Input Handling ---
USER_EMAIL=$1

if [ -z "$USER_EMAIL" ]; then
    echo "Please enter your email address for the SSH key setup:"
    read USER_EMAIL
fi

# --- 1. Oh My Bash ---
if [ ! -d "$HOME/.oh-my-bash" ]; then
    echo "Installing Oh My Bash..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh)" --nodash --unattended || true
else
    echo "Oh My Bash already installed. Skipping."
fi

# --- 2. System Updates & Core Utilities ---
echo "Updating system and installing basic utils..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y build-essential git curl wget unzip zip vim \
    net-tools iputils-ping dnsutils ca-certificates gnupg bash || true

# --- 3. Java & Android SDK Setup ---
if ! command -v java &> /dev/null; then
    echo "Installing Java..."
    sudo apt install -y openjdk-17-jdk || true
else
    echo "Java already installed. Skipping."
fi

if ! command -v adb &> /dev/null; then
    sudo apt update
    sudo apt install -y android-tools-adb android-tools-fastboot
else
    echo "Android tools already installed. Skipping."
fi

if ! getent group plugdev > /dev/null; then
    sudo groupadd plugdev || true
fi
sudo usermod -aG plugdev $USER

ANDROID_SDK_ROOT="/usr/local/android"
if [ ! -d "$ANDROID_SDK_ROOT/cmdline-tools/latest" ]; then
    echo "Setting up Android SDK and Command Line Tools..."
    sudo mkdir -p "$ANDROID_SDK_ROOT"
    sudo chown -R $USER:$USER "$ANDROID_SDK_ROOT"
    sudo chmod -R u+rwX "$ANDROID_SDK_ROOT"

    CMD_URL="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"
    wget -q --show-progress "$CMD_URL" -O /tmp/cmdline.zip
    mkdir -p "$ANDROID_SDK_ROOT/cmdline-tools/temp"
    unzip -q /tmp/cmdline.zip -d "$ANDROID_SDK_ROOT/cmdline-tools/temp"
    mv "$ANDROID_SDK_ROOT/cmdline-tools/temp/cmdline-tools" "$ANDROID_SDK_ROOT/cmdline-tools/latest"
    rm -rf /tmp/cmdline.zip "$ANDROID_SDK_ROOT/cmdline-tools/temp"
    
    export PATH="$PATH:$ANDROID_SDK_ROOT/cmdline-tools/latest/bin"
    echo "Accepting Android Licenses..."
    yes | sdkmanager --licenses > /dev/null 2>&1 || true
    sdkmanager --install "ndk;25.2.9519653" || true
else
    echo "Android SDK directory already exists. Skipping download."
fi

# --- 4. Node.js (via NVM) ---
if [ ! -d "$HOME/.nvm" ]; then
    echo "Installing NVM..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash
fi

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

if ! command -v node &> /dev/null; then
    echo "Installing Node.js v24..."
    nvm install 24 || true
    corepack enable || true
else
    echo "Node.js already installed. Skipping."
fi

# --- 5. Rust ---
if ! command -v rustc &> /dev/null; then
    echo "Installing Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env" || true
else
    echo "Rust already installed. Skipping."
fi

# --- 6. Custom Aliases & Exports (Non-conditional) ---
echo "Ensuring aliases and environment variables are in .bashrc..."
# We remove existing blocks first to avoid infinite duplication, then re-add.
sed -i '/# START CUSTOM SETUP/,/# END CUSTOM SETUP/d' ~/.bashrc

cat << 'EOF' >> ~/.bashrc
# START CUSTOM SETUP
# Android & SDK Paths
export ANDROID_SDK_ROOT="/usr/local/android"
export PATH="$PATH:$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools"

# Custom Aliases
alias gs='git status'
alias gp='git pull'
alias la='ls -A'
alias ll='ls -alF'
# END CUSTOM SETUP
EOF

# --- 7. Install VS Code ---
if ! command -v code &> /dev/null; then
    echo "Installing VS Code..."
    sudo apt install wget gpg -y
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
    sudo install -o root -g root -m 644 packages.microsoft.gpg /usr/share/keyrings/
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list
    sudo apt update
    sudo apt install code -y
    rm -f packages.microsoft.gpg
else
    echo "VS Code already installed. Skipping."
fi

# --- 8. Setup ssh ---
if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
    echo "Generating SSH key..."
    ssh-keygen -t ed25519 -C "$USER_EMAIL" -N "" -f "$HOME/.ssh/id_ed25519"
    eval "$(ssh-agent -s)"
    ssh-add ~/.ssh/id_ed25519
else
    echo "SSH key id_ed25519 already exists. Skipping generation."
fi

# --- 9. Setup docker ---
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    bash <(curl -fsSL https://get.docker.com)
    sudo usermod -aG docker $USER
else
    echo "Docker already installed. Skipping."
fi

echo "--------------------------------------------------"
echo "Setup complete! Please restart your terminal."
echo "--------------------------------------------------"
