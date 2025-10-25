#!/usr/bin/env bash
#
# PiFi Uninstall Script
# Completely removes PiFi WiFi Manager from your Raspberry Pi
#
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${RED}╔════════════════════════════════════════╗${NC}"
echo -e "${RED}║     PiFi Uninstall Script             ║${NC}"
echo -e "${RED}║   This will completely remove PiFi    ║${NC}"
echo -e "${RED}╚════════════════════════════════════════╝${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: This script must be run as root${NC}"
    echo "Please run: sudo $0"
    exit 1
fi

# Confirmation prompt
echo -e "${YELLOW}WARNING: This will remove:${NC}"
echo "  • WiFi Manager service"
echo "  • Configuration Portal service"
echo "  • All PiFi scripts and executables"
echo "  • All PiFi connections (pi-hotspot)"
echo "  • Configuration files"
echo "  • NetworkManager customizations"
echo ""
echo -e "${YELLOW}Your saved WiFi connections will NOT be removed.${NC}"
echo ""
read -p "Are you sure you want to uninstall PiFi? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Uninstall cancelled."
    exit 0
fi

echo ""
echo -e "${BLUE}Starting uninstall process...${NC}"
echo ""

# Step 1: Stop and disable services
echo -e "${GREEN}[1/8]${NC} Stopping services..."
systemctl stop wifi-manager.service 2>/dev/null || echo "  wifi-manager.service not running"
systemctl stop config-portal.service 2>/dev/null || echo "  config-portal.service not running"

echo -e "${GREEN}[2/8]${NC} Disabling services..."
systemctl disable wifi-manager.service 2>/dev/null || echo "  wifi-manager.service not enabled"
systemctl disable config-portal.service 2>/dev/null || echo "  config-portal.service not enabled"

# Step 2: Remove service files
echo -e "${GREEN}[3/8]${NC} Removing service files..."
if [ -f "/etc/systemd/system/wifi-manager.service" ]; then
    rm -f /etc/systemd/system/wifi-manager.service
    echo "  ✓ Removed wifi-manager.service"
else
    echo "  • wifi-manager.service not found"
fi

if [ -f "/etc/systemd/system/config-portal.service" ]; then
    rm -f /etc/systemd/system/config-portal.service
    echo "  ✓ Removed config-portal.service"
else
    echo "  • config-portal.service not found"
fi

# Reload systemd
systemctl daemon-reload
systemctl reset-failed 2>/dev/null || true

# Step 3: Remove Python scripts
echo -e "${GREEN}[4/8]${NC} Removing Python scripts..."
if [ -f "/usr/local/bin/wifi_manager.py" ]; then
    rm -f /usr/local/bin/wifi_manager.py
    echo "  ✓ Removed /usr/local/bin/wifi_manager.py"
else
    echo "  • wifi_manager.py not found"
fi

if [ -f "/usr/local/bin/config_portal.py" ]; then
    rm -f /usr/local/bin/config_portal.py
    echo "  ✓ Removed /usr/local/bin/config_portal.py"
else
    echo "  • config_portal.py not found"
fi

# Step 4: Remove NetworkManager AP connections
echo -e "${GREEN}[5/8]${NC} Removing AP connections..."
AP_REMOVED=0
while nmcli connection show pi-hotspot &>/dev/null; do
    nmcli connection delete pi-hotspot 2>/dev/null && AP_REMOVED=$((AP_REMOVED + 1))
    sleep 0.5
done

if [ $AP_REMOVED -gt 0 ]; then
    echo "  ✓ Removed $AP_REMOVED pi-hotspot connection(s)"
else
    echo "  • No pi-hotspot connections found"
fi

# Step 5: Remove configuration files
echo -e "${GREEN}[6/8]${NC} Removing configuration files..."
if [ -f "/etc/wifi_manager_ap.conf" ]; then
    rm -f /etc/wifi_manager_ap.conf
    echo "  ✓ Removed /etc/wifi_manager_ap.conf"
else
    echo "  • /etc/wifi_manager_ap.conf not found"
fi

# Step 6: Remove NetworkManager customizations
echo -e "${GREEN}[7/8]${NC} Removing NetworkManager customizations..."
if [ -f "/etc/NetworkManager/conf.d/wifi-country.conf" ]; then
    rm -f /etc/NetworkManager/conf.d/wifi-country.conf
    echo "  ✓ Removed wifi-country.conf"
else
    echo "  • wifi-country.conf not found"
fi

if [ -f "/etc/NetworkManager/conf.d/wifi-powersave.conf" ]; then
    rm -f /etc/NetworkManager/conf.d/wifi-powersave.conf
    echo "  ✓ Removed wifi-powersave.conf"
else
    echo "  • wifi-powersave.conf not found"
fi

# Remove empty conf.d directory if it exists and is empty
if [ -d "/etc/NetworkManager/conf.d" ] && [ -z "$(ls -A /etc/NetworkManager/conf.d)" ]; then
    rmdir /etc/NetworkManager/conf.d 2>/dev/null || true
fi

# Step 7: Clean up Python bytecode cache
echo -e "${GREEN}[8/8]${NC} Cleaning up..."
rm -rf /usr/local/bin/__pycache__ 2>/dev/null || true
rm -f /usr/local/bin/*.pyc 2>/dev/null || true

# Restart NetworkManager to apply changes
echo ""
echo -e "${BLUE}Restarting NetworkManager...${NC}"
systemctl restart NetworkManager
sleep 2

# Final status check
echo ""
echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         Uninstall Complete!            ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

# Verify removal
ISSUES=0

if systemctl is-active wifi-manager.service &>/dev/null; then
    echo -e "${RED}✗ wifi-manager.service is still running${NC}"
    ISSUES=$((ISSUES + 1))
else
    echo -e "${GREEN}✓ wifi-manager.service removed${NC}"
fi

if systemctl is-active config-portal.service &>/dev/null; then
    echo -e "${RED}✗ config-portal.service is still running${NC}"
    ISSUES=$((ISSUES + 1))
else
    echo -e "${GREEN}✓ config-portal.service removed${NC}"
fi

if [ -f "/usr/local/bin/wifi_manager.py" ]; then
    echo -e "${RED}✗ wifi_manager.py still exists${NC}"
    ISSUES=$((ISSUES + 1))
else
    echo -e "${GREEN}✓ wifi_manager.py removed${NC}"
fi

if [ -f "/usr/local/bin/config_portal.py" ]; then
    echo -e "${RED}✗ config_portal.py still exists${NC}"
    ISSUES=$((ISSUES + 1))
else
    echo -e "${GREEN}✓ config_portal.py removed${NC}"
fi

if nmcli connection show pi-hotspot &>/dev/null; then
    echo -e "${YELLOW}⚠ pi-hotspot connection still exists${NC}"
    echo "  Run manually: sudo nmcli connection delete pi-hotspot"
else
    echo -e "${GREEN}✓ pi-hotspot connection removed${NC}"
fi

echo ""
if [ $ISSUES -eq 0 ]; then
    echo -e "${GREEN}════════════════════════════════════════${NC}"
    echo -e "${GREEN}PiFi has been completely removed!${NC}"
    echo -e "${GREEN}════════════════════════════════════════${NC}"
else
    echo -e "${YELLOW}════════════════════════════════════════${NC}"
    echo -e "${YELLOW}Uninstall completed with $ISSUES issue(s)${NC}"
    echo -e "${YELLOW}Please review the messages above${NC}"
    echo -e "${YELLOW}════════════════════════════════════════${NC}"
fi

echo ""
echo -e "${BLUE}What was NOT removed:${NC}"
echo "  • Your saved WiFi connections"
echo "  • NetworkManager itself"
echo "  • Python3 and Flask"
echo "  • System packages (no harm in keeping them)"
echo ""
echo -e "${BLUE}Your WiFi should still work normally.${NC}"
echo ""
echo -e "${YELLOW}If you want to reconnect to WiFi manually:${NC}"
echo "  sudo nmcli device wifi connect \"SSID\" password \"PASSWORD\""
echo ""
echo -e "${YELLOW}To reinstall PiFi later:${NC}"
echo "  git clone https://github.com/arnold256/pifi.git"
echo "  cd pifi"
echo "  sudo ./install.sh"
echo ""
