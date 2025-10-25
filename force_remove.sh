#!/usr/bin/env bash
#
# PiFi Force Removal Script
# Nuclear option - removes everything even if services are stuck
#
set -euo pipefail

RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${RED}╔════════════════════════════════════════╗${NC}"
echo -e "${RED}║   PiFi FORCE REMOVAL - DANGER ZONE    ║${NC}"
echo -e "${RED}║                                        ║${NC}"
echo -e "${RED}║   This will forcefully remove PiFi    ║${NC}"
echo -e "${RED}║   even if services are broken/stuck   ║${NC}"
echo -e "${RED}╚════════════════════════════════════════╝${NC}"
echo ""

# Check root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Must run as root${NC}"
    echo "Use: sudo $0"
    exit 1
fi

echo -e "${YELLOW}WARNING: This is a forceful removal that:${NC}"
echo "  • Kills running processes"
echo "  • Force removes service files"
echo "  • Removes all PiFi connections"
echo "  • Cleans up configuration forcefully"
echo ""
echo -e "${RED}Only use this if normal uninstall failed!${NC}"
echo ""
read -p "Are you SURE you want to force remove PiFi? (type 'YES' to confirm) " -r
echo
if [[ ! $REPLY == "YES" ]]; then
    echo "Force removal cancelled."
    exit 0
fi

echo ""
echo "Starting force removal..."
echo ""

# Kill processes
echo "[1] Killing processes..."
pkill -9 -f wifi_manager.py 2>/dev/null && echo "  ✓ Killed wifi_manager.py" || echo "  • No process found"
pkill -9 -f config_portal.py 2>/dev/null && echo "  ✓ Killed config_portal.py" || echo "  • No process found"

# Force stop services
echo "[2] Force stopping services..."
systemctl stop wifi-manager.service 2>/dev/null || true
systemctl stop config-portal.service 2>/dev/null || true
systemctl kill wifi-manager.service 2>/dev/null || true
systemctl kill config-portal.service 2>/dev/null || true
echo "  ✓ Services stopped"

# Disable services
echo "[3] Disabling services..."
systemctl disable wifi-manager.service 2>/dev/null || true
systemctl disable config-portal.service 2>/dev/null || true
echo "  ✓ Services disabled"

# Remove service files
echo "[4] Removing service files..."
rm -f /etc/systemd/system/wifi-manager.service
rm -f /etc/systemd/system/config-portal.service
rm -f /etc/systemd/system/wifi-manager.service.d/* 2>/dev/null || true
rm -f /etc/systemd/system/config-portal.service.d/* 2>/dev/null || true
rmdir /etc/systemd/system/wifi-manager.service.d 2>/dev/null || true
rmdir /etc/systemd/system/config-portal.service.d 2>/dev/null || true
echo "  ✓ Service files removed"

# Reset systemd
echo "[5] Resetting systemd..."
systemctl daemon-reload
systemctl reset-failed 2>/dev/null || true
echo "  ✓ SystemD reset"

# Remove scripts
echo "[6] Removing scripts..."
rm -f /usr/local/bin/wifi_manager.py
rm -f /usr/local/bin/config_portal.py
rm -f /usr/local/bin/wifi_manager.pyc
rm -f /usr/local/bin/config_portal.pyc
rm -rf /usr/local/bin/__pycache__
echo "  ✓ Scripts removed"

# Remove ALL pi-hotspot connections
echo "[7] Removing ALL pi-hotspot connections..."
REMOVED_COUNT=0
for i in {1..10}; do
    if nmcli connection delete pi-hotspot 2>/dev/null; then
        REMOVED_COUNT=$((REMOVED_COUNT + 1))
    else
        break
    fi
done
if [ $REMOVED_COUNT -gt 0 ]; then
    echo "  ✓ Removed $REMOVED_COUNT connection(s)"
else
    echo "  • No connections to remove"
fi

# Force disconnect wlan0 if connected to pi-hotspot
echo "[8] Disconnecting wlan0..."
if nmcli device show wlan0 2>/dev/null | grep -q "pi-hotspot"; then
    nmcli device disconnect wlan0 2>/dev/null || true
    echo "  ✓ Disconnected"
else
    echo "  • Not connected to pi-hotspot"
fi

# Remove configuration files
echo "[9] Removing configuration files..."
rm -f /etc/wifi_manager_ap.conf
rm -f /etc/NetworkManager/conf.d/wifi-country.conf
rm -f /etc/NetworkManager/conf.d/wifi-powersave.conf
echo "  ✓ Configuration files removed"

# Clean up any leftover files
echo "[10] Cleaning up..."
rm -f /tmp/wifi_manager* 2>/dev/null || true
rm -f /tmp/config_portal* 2>/dev/null || true
rm -f /var/run/wifi_manager* 2>/dev/null || true
rm -f /var/log/wifi_manager* 2>/dev/null || true
echo "  ✓ Cleanup complete"

# Restart NetworkManager
echo "[11] Restarting NetworkManager..."
systemctl restart NetworkManager
sleep 3
echo "  ✓ NetworkManager restarted"

echo ""
echo -e "${RED}╔════════════════════════════════════════╗${NC}"
echo -e "${RED}║     Force Removal Complete!           ║${NC}"
echo -e "${RED}╚════════════════════════════════════════╝${NC}"
echo ""

# Final check
echo "Verification:"
if pgrep -f wifi_manager.py >/dev/null; then
    echo -e "${RED}✗ wifi_manager.py still running (try reboot)${NC}"
else
    echo -e "✓ wifi_manager.py not running"
fi

if pgrep -f config_portal.py >/dev/null; then
    echo -e "${RED}✗ config_portal.py still running (try reboot)${NC}"
else
    echo -e "✓ config_portal.py not running"
fi

if [ -f "/usr/local/bin/wifi_manager.py" ]; then
    echo -e "${RED}✗ Scripts still exist (removal may have failed)${NC}"
else
    echo -e "✓ Scripts removed"
fi

if systemctl list-unit-files | grep -q wifi-manager; then
    echo -e "${YELLOW}⚠ Service files still listed (reboot recommended)${NC}"
else
    echo -e "✓ Service files removed"
fi

echo ""
echo -e "${YELLOW}Recommendation: Reboot your Pi to complete removal${NC}"
echo "  sudo reboot"
echo ""
echo "After reboot, verify removal:"
echo "  systemctl status wifi-manager"
echo "  nmcli connection show"
echo ""
