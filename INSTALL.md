# RustEx Installation Guide

This document provides instructions for installing RustEx as a systemd service on a Linux system.

## Quick Installation

You can quickly install RustEx using the following command:

```bash
curl -sSL https://raw.githubusercontent.com/stenstromen/rustex/main/install.sh | sudo bash
```

This will:

1. Download the latest RustEx binary
2. Create a dedicated user for the service
3. Set up a systemd service
4. Configure the necessary directories and permissions

## Post-Installation

After running the installer, you'll need to:

1. Create a configuration file at `/opt/rustex/config.yaml`

   Example configuration:

   ```yaml
   ---
   webhook_url: https://discord.com/api/webhooks/.../...
   files:
     - filename: /path/to/file1.log
       regex: ^\d{4}-\d{2}-\d{2}$
     - filename: /path/to/file2.log
       regex: ^\w+\s\w+$
     - filename: /path/to/file3.log
       regex: ERROR.*
   ```

2. Enable and start the service:

   ```bash
   sudo systemctl enable rustex
   sudo systemctl start rustex
   ```

3. Verify that the service is running correctly:

   ```bash
   sudo systemctl status rustex
   ```

## Troubleshooting

If you encounter any issues, you can check the service logs with:

```bash
sudo journalctl -u rustex -f
```

## Manual Installation

If you prefer to install manually:

1. Download the `install.sh` script
2. Review its contents to ensure it meets your requirements
3. Make it executable: `chmod +x install.sh`
4. Run it with root privileges: `sudo ./install.sh`

## Uninstallation

To remove RustEx:

```bash
# Stop and disable the service
sudo systemctl stop rustex
sudo systemctl disable rustex

# Remove the service file
sudo rm /etc/systemd/system/rustex.service
sudo systemctl daemon-reload

# Remove the user and installation directory
sudo userdel -r rustex

# Or if you want to keep the configuration for later
sudo userdel rustex
sudo rm -rf /opt/rustex
```
