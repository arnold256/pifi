#!/usr/bin/env bash
#
# Quick Reference and Testing Script
# Raspberry Pi WiFi Manager with NetworkManager
#

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

show_status() {
    echo -e "${BLUE}=== System Status ===${NC}"
    echo ""
    
    echo -e "${GREEN}WiFi Manager Service:${NC}"
    systemctl status wifi-manager --no-pager -l | head -15
    echo ""
    
    echo -e "${GREEN}Config Portal Service:${NC}"
    systemctl status config-portal --no-pager -l | head -15
    echo ""
    
    echo -e "${GREEN}NetworkManager Status:${NC}"
    nmcli device status
    echo ""
    
    echo -e "${GREEN}Active Connections:${NC}"
    nmcli connection show --active
    echo ""
}

show_logs() {
    echo -e "${BLUE}=== Recent Logs ===${NC}"
    echo ""
    echo -e "${GREEN}WiFi Manager Logs (last 20 lines):${NC}"
    journalctl -u wifi-manager -n 20 --no-pager
    echo ""
    echo -e "${GREEN}Config Portal Logs (last 20 lines):${NC}"
    journalctl -u config-portal -n 20 --no-pager
}

show_connections() {
    echo -e "${BLUE}=== WiFi Connections ===${NC}"
    echo ""
    echo -e "${GREEN}All Saved Connections:${NC}"
    nmcli -t -f NAME,TYPE,AUTOCONNECT,AUTOCONNECT-PRIORITY connection show | \
        grep '802-11-wireless' | column -t -s ':'
    echo ""
    
    echo -e "${GREEN}Available Networks:${NC}"
    nmcli device wifi list
    echo ""
}

test_ap() {
    echo -e "${BLUE}=== Testing AP Mode ===${NC}"
    echo ""
    
    echo -e "${YELLOW}Disconnecting from WiFi...${NC}"
    nmcli device disconnect wlan0
    sleep 2
    
    echo -e "${YELLOW}Activating AP mode...${NC}"
    nmcli connection up pi-hotspot
    sleep 3
    
    echo -e "${GREEN}AP Status:${NC}"
    nmcli connection show pi-hotspot | grep -E "(connection.id|802-11-wireless.ssid|ipv4.addresses)"
    echo ""
    
    echo -e "${GREEN}Testing portal...${NC}"
    curl -s http://192.168.4.1 | head -5
    echo ""
}

test_portal() {
    echo -e "${BLUE}=== Testing Config Portal ===${NC}"
    echo ""
    
    echo -e "${YELLOW}Checking if portal is accessible...${NC}"
    if curl -s -f http://localhost > /dev/null; then
        echo -e "${GREEN}✓ Portal is running and accessible${NC}"
    else
        echo -e "${RED}✗ Portal is not accessible${NC}"
    fi
    echo ""
    
    echo -e "${YELLOW}Checking port 80...${NC}"
    if netstat -tlnp | grep -q ":80"; then
        echo -e "${GREEN}✓ Port 80 is listening${NC}"
        netstat -tlnp | grep ":80"
    else
        echo -e "${RED}✗ Port 80 is not listening${NC}"
    fi
    echo ""
}

restart_services() {
    echo -e "${BLUE}=== Restarting Services ===${NC}"
    echo ""
    
    echo -e "${YELLOW}Stopping services...${NC}"
    systemctl stop wifi-manager config-portal
    sleep 2
    
    echo -e "${YELLOW}Starting services...${NC}"
    systemctl start wifi-manager config-portal
    sleep 3
    
    echo -e "${GREEN}Service Status:${NC}"
    systemctl is-active wifi-manager && echo "✓ WiFi Manager: Running" || echo "✗ WiFi Manager: Stopped"
    systemctl is-active config-portal && echo "✓ Config Portal: Running" || echo "✗ Config Portal: Stopped"
    echo ""
}

show_help() {
    echo -e "${BLUE}=== WiFi Manager Quick Reference ===${NC}"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  status      - Show service and connection status"
    echo "  logs        - Show recent logs from services"
    echo "  connections - Show WiFi connections and available networks"
    echo "  test-ap     - Test AP mode (WARNING: disconnects WiFi)"
    echo "  test-portal - Test configuration portal"
    echo "  restart     - Restart both services"
    echo "  help        - Show this help message"
    echo ""
    echo "Common NetworkManager Commands:"
    echo "  nmcli device status              - Show device status"
    echo "  nmcli connection show            - List all connections"
    echo "  nmcli device wifi list           - Scan for WiFi networks"
    echo "  nmcli device wifi connect SSID   - Connect to a network"
    echo "  nmcli connection up pi-hotspot   - Start AP mode"
    echo "  nmcli connection down pi-hotspot - Stop AP mode"
    echo ""
    echo "Monitoring:"
    echo "  journalctl -u wifi-manager -f   - Follow WiFi Manager logs"
    echo "  journalctl -u config-portal -f  - Follow Config Portal logs"
    echo "  systemctl status wifi-manager   - Check service status"
    echo ""
}

# Main script
case "${1:-}" in
    status)
        show_status
        ;;
    logs)
        show_logs
        ;;
    connections)
        show_connections
        ;;
    test-ap)
        if [ "$EUID" -ne 0 ]; then 
            echo -e "${RED}Error: Must run as root for AP testing${NC}"
            echo "Use: sudo $0 test-ap"
            exit 1
        fi
        test_ap
        ;;
    test-portal)
        test_portal
        ;;
    restart)
        if [ "$EUID" -ne 0 ]; then 
            echo -e "${RED}Error: Must run as root to restart services${NC}"
            echo "Use: sudo $0 restart"
            exit 1
        fi
        restart_services
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        show_help
        echo ""
        echo -e "${YELLOW}No command specified. Showing status...${NC}"
        echo ""
        show_status
        ;;
esac
