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

# Download the latest release
echo -e "${GREEN}Fetching latest release information...${NC}"
DOWNLOAD_URL=$(curl -s "$LATEST_RELEASE_URL" | grep "browser_download_url" | grep -i "linux" | cut -d '"' -f 4)

if [ -z "$DOWNLOAD_URL" ]; then
    echo -e "${RED}Error: Could not find download URL for the latest release${NC}"
    exit 1
fi

echo -e "${GREEN}Downloading binary from: ${DOWNLOAD_URL}${NC}"
curl -L "$DOWNLOAD_URL" -o "/tmp/rustex.tar.gz"

# Extract the binary
echo -e "${GREEN}Extracting binary...${NC}"
tar -xzf "/tmp/rustex.tar.gz" -C "/tmp"
cp "/tmp/rustex" "$BINARY_PATH"
chmod +x "$BINARY_PATH"
rm -f "/tmp/rustex.tar.gz" "/tmp/rustex"

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

# Set proper ownership
echo -e "${GREEN}Setting permissions...${NC}"
chown -R "$USER_NAME:$USER_NAME" "$USER_HOME"

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