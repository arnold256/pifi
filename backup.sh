#!/usr/bin/env bash
#
# PiFi Backup Script
# Backs up your PiFi configuration before uninstalling
#
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

BACKUP_DIR="$HOME/pifi_backup_$(date +%Y%m%d_%H%M%S)"

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║       PiFi Backup Script              ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${YELLOW}Note: Not running as root. Will backup what's accessible.${NC}"
    echo "For complete backup, run: sudo $0"
    echo ""
fi

echo "Creating backup directory: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

echo ""
echo -e "${GREEN}Backing up PiFi files...${NC}"
echo ""

# Backup Python scripts
echo "[1/7] Backing up Python scripts..."
if [ -f "/usr/local/bin/wifi_manager.py" ]; then
    sudo cp /usr/local/bin/wifi_manager.py "$BACKUP_DIR/"
    echo "  ✓ wifi_manager.py"
else
    echo "  • wifi_manager.py not found"
fi

if [ -f "/usr/local/bin/config_portal.py" ]; then
    sudo cp /usr/local/bin/config_portal.py "$BACKUP_DIR/"
    echo "  ✓ config_portal.py"
else
    echo "  • config_portal.py not found"
fi

# Backup service files
echo "[2/7] Backing up service files..."
if [ -f "/etc/systemd/system/wifi-manager.service" ]; then
    sudo cp /etc/systemd/system/wifi-manager.service "$BACKUP_DIR/"
    echo "  ✓ wifi-manager.service"
else
    echo "  • wifi-manager.service not found"
fi

if [ -f "/etc/systemd/system/config-portal.service" ]; then
    sudo cp /etc/systemd/system/config-portal.service "$BACKUP_DIR/"
    echo "  ✓ config-portal.service"
else
    echo "  • config-portal.service not found"
fi

# Backup configuration files
echo "[3/7] Backing up configuration files..."
if [ -f "/etc/wifi_manager_ap.conf" ]; then
    sudo cp /etc/wifi_manager_ap.conf "$BACKUP_DIR/"
    echo "  ✓ wifi_manager_ap.conf"
else
    echo "  • wifi_manager_ap.conf not found"
fi

# Backup NetworkManager customizations
echo "[4/7] Backing up NetworkManager configurations..."
if [ -f "/etc/NetworkManager/conf.d/wifi-country.conf" ]; then
    sudo cp /etc/NetworkManager/conf.d/wifi-country.conf "$BACKUP_DIR/"
    echo "  ✓ wifi-country.conf"
else
    echo "  • wifi-country.conf not found"
fi

if [ -f "/etc/NetworkManager/conf.d/wifi-powersave.conf" ]; then
    sudo cp /etc/NetworkManager/conf.d/wifi-powersave.conf "$BACKUP_DIR/"
    echo "  ✓ wifi-powersave.conf"
else
    echo "  • wifi-powersave.conf not found"
fi

# Export NetworkManager connections
echo "[5/7] Exporting NetworkManager connections..."
nmcli -t -f NAME,TYPE connection show > "$BACKUP_DIR/connections_list.txt" 2>/dev/null || true
echo "  ✓ connections_list.txt"

# Export pi-hotspot connection if it exists
if nmcli connection show pi-hotspot &>/dev/null; then
    sudo nmcli connection show pi-hotspot > "$BACKUP_DIR/pi-hotspot_details.txt" 2>/dev/null || true
    echo "  ✓ pi-hotspot_details.txt"
else
    echo "  • pi-hotspot connection not found"
fi

# Save service status
echo "[6/7] Saving service status..."
{
    echo "=== WiFi Manager Service Status ==="
    systemctl status wifi-manager.service --no-pager 2>/dev/null || echo "Service not found"
    echo ""
    echo "=== Config Portal Service Status ==="
    systemctl status config-portal.service --no-pager 2>/dev/null || echo "Service not found"
    echo ""
    echo "=== NetworkManager Status ==="
    systemctl status NetworkManager.service --no-pager 2>/dev/null || echo "Service not found"
} > "$BACKUP_DIR/service_status.txt"
echo "  ✓ service_status.txt"

# Save system information
echo "[7/7] Saving system information..."
{
    echo "=== System Information ==="
    echo "Date: $(date)"
    echo "Hostname: $(hostname)"
    echo "Kernel: $(uname -r)"
    echo ""
    echo "=== OS Version ==="
    cat /etc/os-release 2>/dev/null || echo "Not available"
    echo ""
    echo "=== NetworkManager Version ==="
    nmcli --version 2>/dev/null || echo "Not available"
    echo ""
    echo "=== Python Version ==="
    python3 --version 2>/dev/null || echo "Not available"
    echo ""
    echo "=== Device Status ==="
    nmcli device status 2>/dev/null || echo "Not available"
    echo ""
    echo "=== WiFi Networks ==="
    nmcli device wifi list 2>/dev/null || echo "Not available"
} > "$BACKUP_DIR/system_info.txt"
echo "  ✓ system_info.txt"

# Create README in backup
cat > "$BACKUP_DIR/README.txt" <<EOF
PiFi Backup
===========

This backup was created on: $(date)
Hostname: $(hostname)

Contents:
---------
- wifi_manager.py          Main WiFi management daemon
- config_portal.py         Configuration portal
- wifi-manager.service     SystemD service file
- config-portal.service    Portal service file
- wifi_manager_ap.conf     AP password configuration
- wifi-country.conf        WiFi country setting
- wifi-powersave.conf      WiFi power save setting
- connections_list.txt     List of all NetworkManager connections
- pi-hotspot_details.txt   Details of pi-hotspot connection
- service_status.txt       Status of PiFi services
- system_info.txt          System information snapshot

To Restore:
-----------
1. Copy files back to their original locations:
   sudo cp wifi_manager.py /usr/local/bin/
   sudo cp config_portal.py /usr/local/bin/
   sudo cp *.service /etc/systemd/system/
   sudo cp wifi_manager_ap.conf /etc/ (if exists)
   sudo cp wifi-*.conf /etc/NetworkManager/conf.d/

2. Set permissions:
   sudo chmod +x /usr/local/bin/wifi_manager.py
   sudo chmod +x /usr/local/bin/config_portal.py
   sudo chmod 600 /etc/wifi_manager_ap.conf (if exists)

3. Reload and start services:
   sudo systemctl daemon-reload
   sudo systemctl enable wifi-manager config-portal
   sudo systemctl start wifi-manager config-portal

4. Restart NetworkManager:
   sudo systemctl restart NetworkManager

For full reinstall, use:
   git clone https://github.com/arnold256/pifi.git
   cd pifi
   sudo ./install.sh
EOF

# Fix permissions
sudo chown -R $USER:$USER "$BACKUP_DIR" 2>/dev/null || chown -R $USER:$USER "$BACKUP_DIR"

echo ""
echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║       Backup Complete!                 ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""
echo "Backup saved to: $BACKUP_DIR"
echo ""
echo "Contents:"
ls -lh "$BACKUP_DIR" | tail -n +2 | awk '{printf "  %-30s %8s\n", $9, $5}'
echo ""
echo -e "${BLUE}To restore this backup later:${NC}"
echo "  See $BACKUP_DIR/README.txt for instructions"
echo ""
echo -e "${YELLOW}You can now safely uninstall PiFi:${NC}"
echo "  sudo ./uninstall.sh"
echo ""
