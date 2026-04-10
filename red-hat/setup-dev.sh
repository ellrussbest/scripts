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
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh)" --unattended || true
else
    echo "Oh My Bash already installed. Skipping."
fi

# --- 2. System Updates & Core Utilities ---
echo "Updating system and installing basic utils..."
sudo dnf upgrade -y

sudo dnf groupinstall -y "Development Tools" || true

sudo dnf install -y \
    git curl wget unzip zip vim \
    net-tools iputils bind-utils \
    gnome-tweaks \
    gnome-extensions-app \
    gnome-browser-connector \
    ca-certificates gnupg2 bash || true

# --- 3. Java & Android SDK Setup ---
if ! command -v java &> /dev/null; then
    echo "Installing Java..."
    sudo dnf install -y java-17-openjdk-devel || true
else
    echo "Java already installed. Skipping."
fi

if ! command -v adb &> /dev/null; then
    sudo dnf install -y android-tools
else
    echo "Android tools already installed. Skipping."
fi

# Fedora uses adbusers instead of plugdev
sudo groupadd -f adbusers
sudo usermod -aG adbusers $USER

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

    mv "$ANDROID_SDK_ROOT/cmdline-tools/temp/cmdline-tools" \
       "$ANDROID_SDK_ROOT/cmdline-tools/latest"

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
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

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
    curl https://sh.rustup.rs -sSf | sh -s -- -y
    source "$HOME/.cargo/env" || true
else
    echo "Rust already installed. Skipping."
fi

# --- 6. Custom Aliases & Exports ---
echo "Ensuring aliases and environment variables are in .bashrc..."

sed -i '/# START CUSTOM SETUP/,/# END CUSTOM SETUP/d' ~/.bashrc

cat << 'EOF' >> ~/.bashrc
# START CUSTOM SETUP
export ANDROID_SDK_ROOT="/usr/local/android"
export PATH="$PATH:$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools"

alias virc='vim ~/.bashrc'
alias pnpm-init='pnpm init && pnpm add -D typescript @types/node && pnpm tsc --init'
alias la='ls -A'
alias ll='ls -alF'
# END CUSTOM SETUP
EOF

# --- 7. Install VS Code ---
if ! command -v code &> /dev/null; then
    echo "Installing VS Code..."

    sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc

    sudo tee /etc/yum.repos.d/vscode.repo > /dev/null <<EOF
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF

    sudo dnf install -y code
else
    echo "VS Code already installed. Skipping."
fi

# --- 8. Setup SSH ---
if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
    echo "Generating SSH key..."
    ssh-keygen -t ed25519 -C "$USER_EMAIL" -N "" -f "$HOME/.ssh/id_ed25519"
    eval "$(ssh-agent -s)"
    ssh-add ~/.ssh/id_ed25519
else
    echo "SSH key already exists. Skipping."
fi

# --- 9. Setup docker ---
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    bash <(curl -fsSL https://get.docker.com)
    sudo usermod -aG docker $USER
    sudo systemctl start docker
    sudo systemctl enable docker
else
    echo "Docker already installed. Skipping."
fi

# --- 10. Install postman ---
if ! command -v postman &> /dev/null; then
    echo "Installing Postman..."
    wget -q --show-progress https://dl.pstmn.io/download/latest/linux64 -O /tmp/postman-linux-x64.tar.gz
    sudo rm -rf /opt/Postman
    sudo tar -xzf /tmp/postman-linux-x64.tar.gz -C /opt
    sudo chown -R $USER:$USER /opt/Postman
    sudo chmod +x /opt/Postman/Postman
    sudo ln -sf /opt/Postman/Postman /usr/bin/postman
    mkdir -p ~/.local/share/applications
    cat << EOF > ~/.local/share/applications/postman.desktop
[Desktop Entry]
Name=Postman
GenericName=API Client
X-GNOME-FullName=Postman API Client
Comment=Make and view REST API calls and responses
Keywords=api;
Exec=/opt/Postman/Postman
Terminal=false
Type=Application
Icon=/opt/Postman/app/resources/app/assets/icon.png
Categories=Development;Utilities;
EOF

    # Clean up the downloaded archive
    rm /tmp/postman-linux-x64.tar.gz
    
    echo "Postman installation complete."
else
    echo "Postman already installed. Skipping."
fi

echo "--------------------------------------------------"
echo "Setup complete! Please restart your terminal."
echo "--------------------------------------------------"
