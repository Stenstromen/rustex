#!/bin/bash
set -e

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Define variables
SERVICE_NAME="rustex"
USER_NAME="rustex"
USER_HOME="/opt/rustex"
BINARY_PATH="$USER_HOME/rustex"
CONFIG_PATH="$USER_HOME/config.yaml"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
GITHUB_REPO="stenstromen/rustex"
LATEST_RELEASE_URL="https://api.github.com/repos/${GITHUB_REPO}/releases/latest"

# Detect system architecture
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)
        ARCH_NAME="amd64"
        ;;
    aarch64|arm64)
        ARCH_NAME="aarch64"
        ;;
    *)
        echo -e "${RED}Error: Unsupported architecture: $ARCH${NC}"
        echo -e "${RED}Supported architectures: x86_64 (amd64), aarch64 (arm64)${NC}"
        exit 1
        ;;
esac

echo -e "${GREEN}Detected architecture: ${ARCH} (${ARCH_NAME})${NC}"

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}Error: This script must be run as root${NC}"
    exit 1
fi

echo -e "${GREEN}Installing ${SERVICE_NAME} as a systemd service...${NC}"

# Create user for the service
if ! id "$USER_NAME" &>/dev/null; then
    echo -e "${GREEN}Creating user: ${USER_NAME}${NC}"
    useradd -r -s /bin/false -m -d "$USER_HOME" "$USER_NAME"
else
    echo -e "${YELLOW}User $USER_NAME already exists${NC}"
fi

# Create directory structure
mkdir -p "$USER_HOME"

# Function to compare versions
# Returns 0 if version1 < version2, 1 if version1 >= version2
version_less_than() {
    # Sort versions and check if first argument is the smallest
    printf '%s\n%s\n' "$1" "$2" | sort -V | head -n1 | grep -q "^$1$"
}

# Check if rustex is already installed and get version
INSTALLED_VERSION=""
NEEDS_UPDATE=true

if [ -f "$BINARY_PATH" ]; then
    echo -e "${YELLOW}Existing installation detected at ${BINARY_PATH}${NC}"
    
    # Try to get installed version (will fail gracefully for versions < 1.0.8)
    INSTALLED_VERSION=$("$BINARY_PATH" --version 2>/dev/null || echo "")
    
    if [ -n "$INSTALLED_VERSION" ]; then
        # Extract version number (e.g., "rustex v1.0.7" -> "1.0.7")
        INSTALLED_VERSION=$(echo "$INSTALLED_VERSION" | sed -n 's/.*v\?\([0-9]\+\.[0-9]\+\.[0-9]\+\).*/\1/p')
    fi
    
    if [ -z "$INSTALLED_VERSION" ]; then
        echo -e "${YELLOW}Installed version does not support --version flag (pre-1.0.8)${NC}"
        echo -e "${YELLOW}Will upgrade to latest version${NC}"
        INSTALLED_VERSION="0.0.0"
    else
        echo -e "${GREEN}Installed version: ${INSTALLED_VERSION}${NC}"
    fi
fi

# Download the latest release
echo -e "${GREEN}Fetching latest release information...${NC}"
LATEST_VERSION=$(curl -s "$LATEST_RELEASE_URL" | grep '"tag_name"' | cut -d '"' -f 4 | sed 's/^v//')

if [ -z "$LATEST_VERSION" ]; then
    echo -e "${RED}Error: Could not fetch latest version information${NC}"
    exit 1
fi

echo -e "${GREEN}Latest version available: ${LATEST_VERSION}${NC}"

# Compare versions if we have an installed version
if [ -n "$INSTALLED_VERSION" ] && [ "$INSTALLED_VERSION" != "0.0.0" ]; then
    if version_less_than "$INSTALLED_VERSION" "$LATEST_VERSION"; then
        echo -e "${YELLOW}Upgrade available: ${INSTALLED_VERSION} -> ${LATEST_VERSION}${NC}"
        echo -e "${GREEN}Proceeding with upgrade...${NC}"
    else
        echo -e "${GREEN}Already running the latest version (${INSTALLED_VERSION})${NC}"
        echo -e "${YELLOW}Skipping download. If you want to reinstall, remove ${BINARY_PATH} first.${NC}"
        NEEDS_UPDATE=false
    fi
else
    echo -e "${GREEN}Installing version ${LATEST_VERSION}${NC}"
fi

# Only download if update is needed
if [ "$NEEDS_UPDATE" = true ]; then
    DOWNLOAD_URL=$(curl -s "$LATEST_RELEASE_URL" | grep "browser_download_url" | grep -i "linux" | grep -i "$ARCH_NAME" | cut -d '"' -f 4)

    if [ -z "$DOWNLOAD_URL" ]; then
        echo -e "${RED}Error: Could not find download URL for ${ARCH_NAME} architecture${NC}"
        echo -e "${RED}Please check if a release is available for your architecture at:${NC}"
        echo -e "${RED}https://github.com/${GITHUB_REPO}/releases${NC}"
        exit 1
    fi

    echo -e "${GREEN}Downloading binary for ${ARCH_NAME} from: ${DOWNLOAD_URL}${NC}"
    curl -L "$DOWNLOAD_URL" -o "/tmp/rustex.tar.gz"

    # Download and verify checksum
    echo -e "${GREEN}Downloading and verifying checksum...${NC}"
    CHECKSUM_URL=$(curl -s "$LATEST_RELEASE_URL" | grep "browser_download_url" | grep -i "checksums.txt" | cut -d '"' -f 4)
    if [ -z "$CHECKSUM_URL" ]; then
        echo -e "${RED}Error: Could not find checksum file URL${NC}"
        exit 1
    fi

    curl -L "$CHECKSUM_URL" -o "/tmp/rustex_version_checksums.txt"
    EXPECTED_CHECKSUM=$(grep -i "linux" "/tmp/rustex_version_checksums.txt" | grep -i "$ARCH_NAME" | cut -d ' ' -f 1)
    ACTUAL_CHECKSUM=$(sha256sum "/tmp/rustex.tar.gz" | cut -d ' ' -f 1)

    if [ "$EXPECTED_CHECKSUM" != "$ACTUAL_CHECKSUM" ]; then
        echo -e "${RED}Error: Checksum verification failed${NC}"
        echo -e "${RED}Expected: $EXPECTED_CHECKSUM${NC}"
        echo -e "${RED}Actual:   $ACTUAL_CHECKSUM${NC}"
        rm -f "/tmp/rustex.tar.gz" "/tmp/rustex_version_checksums.txt"
        exit 1
    fi

    rm -f "/tmp/rustex_version_checksums.txt"

    # Extract the binary
    echo -e "${GREEN}Extracting binary...${NC}"
    tar -xzf "/tmp/rustex.tar.gz" -C "/tmp"
    cp "/tmp/rustex" "$BINARY_PATH"
    chmod +x "$BINARY_PATH"
    rm -f "/tmp/rustex.tar.gz" "/tmp/rustex"
    
    # Set proper ownership
    echo -e "${GREEN}Setting permissions...${NC}"
    chown -R "$USER_NAME:$USER_NAME" "$USER_HOME"
else
    echo -e "${GREEN}Skipping installation - already up to date${NC}"
fi

# Create systemd service file
echo -e "${GREEN}Creating systemd service file...${NC}"
cat > "$SERVICE_FILE" << EOL
[Unit]
Description=RustEx service for monitoring files and sending to Discord webhook
After=network.target

[Service]
Type=simple
User=${USER_NAME}
Group=${USER_NAME}
WorkingDirectory=${USER_HOME}
ExecStart=${BINARY_PATH} ${CONFIG_PATH}
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOL

# Reload systemd
echo -e "${GREEN}Reloading systemd...${NC}"
systemctl daemon-reload

# Print instructions
echo -e "\n${GREEN}========== INSTALLATION COMPLETE ==========${NC}"
echo -e "${YELLOW}Next steps:${NC}"
echo -e "1. Create a configuration file at ${CONFIG_PATH}"
echo -e "   Example configuration:"
echo -e "   ---"
echo -e "   webhook_url: https://discord.com/api/webhooks/.../..."
echo -e "   files:"
echo -e "     - filename: /path/to/file1.log"
echo -e "       regex: ^\\d{4}-\\d{2}-\\d{2}$"
echo -e "     - filename: /path/to/file2.log"
echo -e "       regex: ^\\w+\\s\\w+$"
echo -e "     - filename: /path/to/file3.log"
echo -e "       regex: ERROR.*"
echo -e ""
echo -e "2. Enable and start the service:"
echo -e "   sudo systemctl enable ${SERVICE_NAME} --now"
echo -e ""
echo -e "3. Check service status:"
echo -e "   sudo systemctl status ${SERVICE_NAME}"
echo -e ""
echo -e "4. View logs:"
echo -e "   sudo journalctl -u ${SERVICE_NAME} -f"
echo -e "${GREEN}==========================================${NC}"

exit 0 