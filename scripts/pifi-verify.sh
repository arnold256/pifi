#!/usr/bin/env bash
#
# WiFi Manager Verification and Repair Script
#
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== WiFi Manager Verification ===${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: This script must be run as root${NC}"
    echo "Please run: sudo $0"
    exit 1
fi

echo -e "${YELLOW}[1] Checking Python installation...${NC}"
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}✗ Python3 not found${NC}"
    exit 1
fi
PYTHON_VERSION=$(python3 --version)
echo -e "${GREEN}✓ $PYTHON_VERSION${NC}"

echo -e "${YELLOW}[2] Checking NetworkManager...${NC}"
if ! command -v nmcli &> /dev/null; then
    echo -e "${RED}✗ NetworkManager not found${NC}"
    exit 1
fi
NM_VERSION=$(nmcli --version | head -1)
echo -e "${GREEN}✓ $NM_VERSION${NC}"

echo -e "${YELLOW}[3] Checking Flask...${NC}"
if python3 -c "import flask" 2>/dev/null; then
    FLASK_VERSION=$(python3 -c "import flask; print(f'Flask {flask.__version__}')")
    echo -e "${GREEN}✓ $FLASK_VERSION${NC}"
else
    echo -e "${RED}✗ Flask not installed${NC}"
    echo -e "${YELLOW}Installing Flask...${NC}"
    pip3 install --break-system-packages flask || pip3 install flask
fi

echo ""
echo -e "${YELLOW}[4] Checking WiFi Manager files...${NC}"

# Check if wifi_manager.py exists
if [ -f "/usr/local/bin/wifi_manager.py" ]; then
    echo -e "${GREEN}✓ wifi_manager.py exists${NC}"
    
    # Check for syntax errors
    if python3 -m py_compile /usr/local/bin/wifi_manager.py 2>/tmp/wifi_syntax_error.txt; then
        echo -e "${GREEN}✓ wifi_manager.py syntax OK${NC}"
    else
        echo -e "${RED}✗ wifi_manager.py has syntax errors:${NC}"
        cat /tmp/wifi_syntax_error.txt
        echo ""
        echo -e "${YELLOW}Would you like to reinstall wifi_manager.py? (y/n)${NC}"
        read -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Reinstalling wifi_manager.py...${NC}"
            # Copy from the source directory
            if [ -f "wifi_manager_nm.py" ]; then
                cp wifi_manager_nm.py /usr/local/bin/wifi_manager.py
                chmod +x /usr/local/bin/wifi_manager.py
                echo -e "${GREEN}✓ Reinstalled${NC}"
            else
                echo -e "${RED}✗ Source file wifi_manager_nm.py not found${NC}"
                echo "Please ensure you're running this from the directory containing the source files"
                exit 1
            fi
        fi
    fi
else
    echo -e "${RED}✗ wifi_manager.py not found${NC}"
    echo -e "${YELLOW}Would you like to install it? (y/n)${NC}"
    read -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if [ -f "wifi_manager_nm.py" ]; then
            cp wifi_manager_nm.py /usr/local/bin/wifi_manager.py
            chmod +x /usr/local/bin/wifi_manager.py
            echo -e "${GREEN}✓ Installed${NC}"
        else
            echo -e "${RED}✗ Source file wifi_manager_nm.py not found${NC}"
            exit 1
        fi
    fi
fi

# Check config_portal.py
if [ -f "/usr/local/bin/config_portal.py" ]; then
    echo -e "${GREEN}✓ config_portal.py exists${NC}"
    
    if python3 -m py_compile /usr/local/bin/config_portal.py 2>/tmp/portal_syntax_error.txt; then
        echo -e "${GREEN}✓ config_portal.py syntax OK${NC}"
    else
        echo -e "${RED}✗ config_portal.py has syntax errors:${NC}"
        cat /tmp/portal_syntax_error.txt
        echo ""
        echo -e "${YELLOW}Would you like to reinstall config_portal.py? (y/n)${NC}"
        read -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if [ -f "config_portal_nm.py" ]; then
                cp config_portal_nm.py /usr/local/bin/config_portal.py
                chmod +x /usr/local/bin/config_portal.py
                echo -e "${GREEN}✓ Reinstalled${NC}"
            else
                echo -e "${RED}✗ Source file config_portal_nm.py not found${NC}"
                exit 1
            fi
        fi
    fi
else
    echo -e "${RED}✗ config_portal.py not found${NC}"
    echo -e "${YELLOW}Would you like to install it? (y/n)${NC}"
    read -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if [ -f "config_portal_nm.py" ]; then
            cp config_portal_nm.py /usr/local/bin/config_portal.py
            chmod +x /usr/local/bin/config_portal.py
            echo -e "${GREEN}✓ Installed${NC}"
        else
            echo -e "${RED}✗ Source file config_portal_nm.py not found${NC}"
            exit 1
        fi
    fi
fi

echo ""
echo -e "${YELLOW}[5] Checking service files...${NC}"

if [ -f "/etc/systemd/system/wifi-manager.service" ]; then
    echo -e "${GREEN}✓ wifi-manager.service exists${NC}"
else
    echo -e "${RED}✗ wifi-manager.service not found${NC}"
    if [ -f "wifi-manager.service" ]; then
        cp wifi-manager.service /etc/systemd/system/
        echo -e "${GREEN}✓ Installed${NC}"
    fi
fi

if [ -f "/etc/systemd/system/config-portal.service" ]; then
    echo -e "${GREEN}✓ config-portal.service exists${NC}"
else
    echo -e "${RED}✗ config-portal.service not found${NC}"
    if [ -f "config-portal.service" ]; then
        cp config-portal.service /etc/systemd/system/
        echo -e "${GREEN}✓ Installed${NC}"
    fi
fi

echo ""
echo -e "${YELLOW}[6] Checking service status...${NC}"

systemctl daemon-reload

if systemctl is-enabled wifi-manager.service &>/dev/null; then
    echo -e "${GREEN}✓ wifi-manager.service is enabled${NC}"
else
    echo -e "${YELLOW}⚠ wifi-manager.service not enabled${NC}"
    echo -e "${YELLOW}Enabling...${NC}"
    systemctl enable wifi-manager.service
fi

if systemctl is-enabled config-portal.service &>/dev/null; then
    echo -e "${GREEN}✓ config-portal.service is enabled${NC}"
else
    echo -e "${YELLOW}⚠ config-portal.service not enabled${NC}"
    echo -e "${YELLOW}Enabling...${NC}"
    systemctl enable config-portal.service
fi

echo ""
echo -e "${YELLOW}[7] Testing service start...${NC}"

# Try to start services
systemctl restart wifi-manager.service || true
sleep 2

if systemctl is-active wifi-manager.service &>/dev/null; then
    echo -e "${GREEN}✓ wifi-manager.service is running${NC}"
else
    echo -e "${RED}✗ wifi-manager.service failed to start${NC}"
    echo -e "${YELLOW}Last 20 log lines:${NC}"
    journalctl -u wifi-manager -n 20 --no-pager
fi

systemctl restart config-portal.service || true
sleep 2

if systemctl is-active config-portal.service &>/dev/null; then
    echo -e "${GREEN}✓ config-portal.service is running${NC}"
else
    echo -e "${RED}✗ config-portal.service failed to start${NC}"
    echo -e "${YELLOW}Last 20 log lines:${NC}"
    journalctl -u config-portal -n 20 --no-pager
fi

echo ""
echo -e "${YELLOW}[8] Testing functionality...${NC}"

# Check if wlan0 exists
if nmcli device status | grep -q wlan0; then
    echo -e "${GREEN}✓ wlan0 device found${NC}"
else
    echo -e "${RED}✗ wlan0 device not found${NC}"
    echo "This may not be a WiFi-capable device"
fi

# Check if AP connection exists
if nmcli connection show pi-hotspot &>/dev/null; then
    echo -e "${GREEN}✓ AP connection (pi-hotspot) exists${NC}"
else
    echo -e "${YELLOW}⚠ AP connection not found (will be created on first run)${NC}"
fi

echo ""
echo -e "${BLUE}=== Summary ===${NC}"
echo ""

# Count issues
ISSUES=0

if ! systemctl is-active wifi-manager.service &>/dev/null; then
    ISSUES=$((ISSUES + 1))
    echo -e "${RED}• wifi-manager.service not running${NC}"
fi

if ! systemctl is-active config-portal.service &>/dev/null; then
    ISSUES=$((ISSUES + 1))
    echo -e "${RED}• config-portal.service not running${NC}"
fi

if [ $ISSUES -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed!${NC}"
    echo ""
    echo "Your WiFi Manager should be working correctly."
    echo "If not connected to WiFi, an AP should appear within 20-30 seconds."
    echo ""
    echo "Useful commands:"
    echo "  sudo journalctl -u wifi-manager -f     # Watch logs"
    echo "  sudo systemctl status wifi-manager     # Check status"
    echo "  nmcli device status                    # Check WiFi device"
    echo "  nmcli connection show                  # List connections"
else
    echo -e "${RED}✗ Found $ISSUES issue(s)${NC}"
    echo ""
    echo "Check logs with:"
    echo "  sudo journalctl -u wifi-manager -n 50"
    echo "  sudo journalctl -u config-portal -n 50"
fi

echo ""
