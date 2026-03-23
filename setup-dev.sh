#!/bin/bash

# --- 0. Email Input Handling ---
USER_EMAIL=$1

if [ -z "$USER_EMAIL" ]; then
    echo "Please enter your email address for the SSH key setup:"
    read USER_EMAIL
fi

# --- 1. Oh My Bash (Run FIRST so it doesn't overwrite our .bashrc later) ---
if [ ! -d "$HOME/.oh-my-bash" ]; then
    echo "Installing Oh My Bash..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh)" --nodash --unattended || true
fi

# --- 2. System Updates & Core Utilities ---
echo "Updating system and installing basic utils..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y build-essential git curl wget unzip zip vim \
    net-tools iputils-ping dnsutils ca-certificates gnupg bash || true

# --- 3. Java & Android SDK Setup ---
echo "Setting up Java and Android SDK..."
sudo apt install -y openjdk-17-jdk || true
sudo apt update
sudo apt install -y android-tools-adb android-tools-fastboot
sudo groupadd plugdev || true
sudo usermod -aG plugdev $USER

ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-/usr/local/android}"
sudo mkdir -p "$ANDROID_SDK_ROOT"
sudo chown -R $USER:$USER "$ANDROID_SDK_ROOT"
sudo chmod -R u+rwX "$ANDROID_SDK_ROOT"

# Download cmdline-tools if not present
if [ ! -d "$ANDROID_SDK_ROOT/cmdline-tools/latest" ]; then
    echo "Downloading Android Command Line Tools..."
    CMD_URL="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"
    wget -q --show-progress "$CMD_URL" -O /tmp/cmdline.zip
    mkdir -p "$ANDROID_SDK_ROOT/cmdline-tools/temp"
    unzip -q /tmp/cmdline.zip -d "$ANDROID_SDK_ROOT/cmdline-tools/temp"
    mv "$ANDROID_SDK_ROOT/cmdline-tools/temp/cmdline-tools" "$ANDROID_SDK_ROOT/cmdline-tools/latest"
    rm -rf /tmp/cmdline.zip "$ANDROID_SDK_ROOT/cmdline-tools/temp"
fi

export ANDROID_SDK_ROOT
export PATH="$PATH:$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools"

echo "Accepting Android Licenses..."
yes | sdkmanager --licenses > /dev/null 2>&1 || true
sdkmanager --install "ndk;25.2.9519653" || true

# --- 4. Node.js (via NVM) ---
if [ ! -d "$HOME/.nvm" ]; then
    echo "Installing NVM..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash
fi

# Load NVM into current session
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

echo "Installing Node.js v24..."
nvm install 24 || true
corepack enable || true

# --- 5. Rust ---
if ! command -v rustc &> /dev/null; then
    echo "Installing Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
fi
source "$HOME/.cargo/env" || true

# --- 6. Custom Aliases & Exports ---
echo "Adding aliases and environment variables to .bashrc..."
# Use a check to ensure we don't append duplicates if run twice
if ! grep -q "ANDROID_SDK_ROOT" ~/.bashrc; then
cat << 'EOF' >> ~/.bashrc

# Android & SDK Paths
export ANDROID_SDK_ROOT="/usr/local/android"
export PATH="$PATH:$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools"

# Custom Aliases
alias gs='git status'
alias gp='git pull'
alias la='ls -A'
alias ll='ls -alF'
EOF
fi

# --- 7. Install VS Code ---
sudo apt install wget gpg -y
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
sudo install -o root -g root -m 644 packages.microsoft.gpg /usr/share/keyrings/
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list
sudo apt update
sudo apt install code -y

# --- 8. Setup ssh ---
ssh-keygen -t ed25519 -C "$USER_EMAIL"
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

echo "--------------------------------------------------"
echo "Setup complete! Please restart your terminal."
echo "--------------------------------------------------"
