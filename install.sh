#!/usr/bin/env bash
#
# Direct Installation Script - Simple File Copy Method
# Use this if the main installer has issues
#
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}WiFi Manager - Direct Installation${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Configuration
AP_SSID="${AP_SSID:-PiConfigAP}"
AP_PASSWORD="${AP_PASSWORD:-}"
COUNTRY="${COUNTRY:-AU}"

# Check root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: Must run as root${NC}"
    echo "Use: sudo $0"
    exit 1
fi

# Check we're in the right directory
if [ ! -f "src/wifi_manager.py" ] || [ ! -f "src/config_portal.py" ]; then
    echo -e "${RED}Error: Source files not found${NC}"
    echo "Please run this script from the pifi repository root directory"
    echo "Expected structure:"
    echo "  src/wifi_manager.py"
    echo "  src/config_portal.py"
    echo "  systemd/wifi-manager.service"
    echo "  systemd/config-portal.service"
    exit 1
fi

echo -e "${GREEN}[1/6]${NC} Installing packages..."
apt-get update
apt-get install -y python3-pip python3-flask network-manager

# Install Flask (try both methods)
pip3 install --break-system-packages flask 2>/dev/null || pip3 install flask || true

echo -e "${GREEN}[2/6]${NC} Configuring NetworkManager..."
nmcli device set wlan0 managed yes 2>/dev/null || true

mkdir -p /etc/NetworkManager/conf.d

cat > /etc/NetworkManager/conf.d/wifi-country.conf <<EOF
[device-wifi]
wifi.scan-rand-mac-address=no

[connection-wifi]
wifi.cloned-mac-address=preserve
EOF

cat > /etc/NetworkManager/conf.d/wifi-powersave.conf <<EOF
[connection]
wifi.powersave=2
EOF

echo -e "${GREEN}[3/6]${NC} Installing scripts..."

# Copy Python scripts
cp src/wifi_manager.py /usr/local/bin/wifi_manager.py
cp src/config_portal.py /usr/local/bin/config_portal.py

chmod +x /usr/local/bin/wifi_manager.py
chmod +x /usr/local/bin/config_portal.py

# Update AP SSID in the script
sed -i "s/AP_SSID = \"PiConfigAP\"/AP_SSID = \"${AP_SSID}\"/" /usr/local/bin/wifi_manager.py

# Save AP password if provided
if [ -n "$AP_PASSWORD" ]; then
    echo "AP_PASSWORD=\"${AP_PASSWORD}\"" > /etc/wifi_manager_ap.conf
    chmod 600 /etc/wifi_manager_ap.conf
    echo -e "${GREEN}AP password configured${NC}"
fi

echo -e "${GREEN}[4/6]${NC} Installing service files..."

# Copy service files
cp systemd/wifi-manager.service /etc/systemd/system/
cp systemd/config-portal.service /etc/systemd/system/

echo -e "${GREEN}[5/6]${NC} Enabling services..."
systemctl daemon-reload
systemctl enable wifi-manager.service
systemctl enable config-portal.service
systemctl enable NetworkManager.service

echo -e "${GREEN}[6/6]${NC} Verifying installation..."

# Quick verification
echo ""
echo "Checking Python syntax..."
if python3 -m py_compile /usr/local/bin/wifi_manager.py; then
    echo -e "${GREEN}✓ wifi_manager.py syntax OK${NC}"
else
    echo -e "${RED}✗ wifi_manager.py syntax error${NC}"
    exit 1
fi

if python3 -m py_compile /usr/local/bin/config_portal.py; then
    echo -e "${GREEN}✓ config_portal.py syntax OK${NC}"
else
    echo -e "${RED}✗ config_portal.py syntax error${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Installation Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Configuration:${NC}"
echo "  AP SSID: $AP_SSID"
echo "  AP IP: 192.168.4.1"
if [ -n "$AP_PASSWORD" ]; then
    echo "  AP Password: (configured)"
else
    echo "  AP Password: (open network)"
fi
echo "  Country: $COUNTRY"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "  1. Reboot: ${GREEN}sudo reboot${NC}"
echo "  2. After reboot, connect to WiFi: ${GREEN}${AP_SSID}${NC}"
echo "  3. Open browser to: ${GREEN}http://192.168.4.1${NC}"
echo ""
echo -e "${YELLOW}Useful Commands:${NC}"
echo "  sudo journalctl -u wifi-manager -f"
echo "  sudo systemctl status wifi-manager"
echo "  ./verify_and_fix.sh  # Run verification script"
echo ""
echo -e "${GREEN}Reboot now? (y/N)${NC}"
read -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Rebooting..."
    reboot
fi
