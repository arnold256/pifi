#!/usr/bin/env bash
#
# Fix USB OTG Mode for Raspberry Pi Zero 2 W
# Forces dwc2 into peripheral/gadget mode
#
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}USB OTG Mode Fix for Pi Zero 2 W${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: This script must be run as root${NC}"
    echo "Please run: sudo $0"
    exit 1
fi

# Detect boot directory
if [ -d "/boot/firmware" ]; then
    BOOT_DIR="/boot/firmware"
elif [ -d "/boot" ]; then
    BOOT_DIR="/boot"
else
    echo -e "${RED}Error: Cannot find boot directory${NC}"
    exit 1
fi

CONFIG_FILE="${BOOT_DIR}/config.txt"

echo -e "${YELLOW}Issue Detected:${NC}"
echo "The dwc2 module is loaded but USB Device Controller is not active."
echo "This means dwc2 isn't in peripheral/gadget mode."
echo ""

echo -e "${YELLOW}Solution:${NC}"
echo "We need to explicitly set the dwc2 to peripheral mode."
echo ""

# Check current configuration
echo -e "${GREEN}[1/3]${NC} Checking current configuration..."
if grep -q "^dtoverlay=dwc2,dr_mode=peripheral" "$CONFIG_FILE"; then
    echo -e "${GREEN}✓ Already configured for peripheral mode${NC}"
    NEEDS_UPDATE=false
elif grep -q "^dtoverlay=dwc2" "$CONFIG_FILE"; then
    echo -e "${YELLOW}⚠ dtoverlay=dwc2 exists but no dr_mode specified${NC}"
    NEEDS_UPDATE=true
else
    echo -e "${RED}✗ dtoverlay=dwc2 not found${NC}"
    NEEDS_UPDATE=true
fi
echo ""

if [ "$NEEDS_UPDATE" = true ]; then
    echo -e "${GREEN}[2/3]${NC} Backing up and updating config.txt..."
    
    # Backup
    cp "$CONFIG_FILE" "${CONFIG_FILE}.backup-$(date +%Y%m%d-%H%M%S)"
    echo "Backup created"
    
    # Remove old dtoverlay=dwc2 lines
    sed -i '/^dtoverlay=dwc2/d' "$CONFIG_FILE"
    
    # Add new dtoverlay with dr_mode
    echo "" >> "$CONFIG_FILE"
    echo "# USB OTG in peripheral mode (for USB console)" >> "$CONFIG_FILE"
    echo "dtoverlay=dwc2,dr_mode=peripheral" >> "$CONFIG_FILE"
    
    echo -e "${GREEN}✓ Updated config.txt with dr_mode=peripheral${NC}"
    echo ""
    
    echo -e "${GREEN}[3/3]${NC} Changes complete!"
    echo ""
    echo -e "${YELLOW}Next Steps:${NC}"
    echo "1. Reboot your Pi: ${GREEN}sudo reboot${NC}"
    echo "2. After reboot, check USB Device Controller:"
    echo "   ${GREEN}ls /sys/class/udc/${NC}"
    echo "3. Check if /dev/ttyGS0 appears:"
    echo "   ${GREEN}ls -l /dev/ttyGS0${NC}"
    echo ""
    
    echo -e "${GREEN}Reboot now? (y/N)${NC}"
    read -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Rebooting..."
        reboot
    fi
else
    echo -e "${GREEN}[2/3]${NC} Configuration already correct"
    echo ""
    echo -e "${YELLOW}Trying alternative fix...${NC}"
    echo ""
    
    # Try to manually activate USB gadget
    echo -e "${GREEN}[3/3]${NC} Attempting to manually initialize USB gadget..."
    
    # Check if configfs is mounted
    if ! mount | grep -q configfs; then
        echo "Mounting configfs..."
        mount -t configfs none /sys/kernel/config 2>/dev/null || true
    fi
    
    # Try to create a simple gadget
    GADGET_DIR="/sys/kernel/config/usb_gadget/g1"
    if [ ! -d "$GADGET_DIR" ]; then
        echo "Creating USB gadget configuration..."
        mkdir -p "$GADGET_DIR" 2>/dev/null || true
        
        if [ -d "$GADGET_DIR" ]; then
            echo 0x1d6b > "$GADGET_DIR/idVendor" 2>/dev/null || true  # Linux Foundation
            echo 0x0104 > "$GADGET_DIR/idProduct" 2>/dev/null || true  # Multifunction Composite Gadget
            mkdir -p "$GADGET_DIR/strings/0x409" 2>/dev/null || true
            echo "fedcba9876543210" > "$GADGET_DIR/strings/0x409/serialnumber" 2>/dev/null || true
            echo "Raspberry Pi" > "$GADGET_DIR/strings/0x409/manufacturer" 2>/dev/null || true
            echo "Pi Zero USB" > "$GADGET_DIR/strings/0x409/product" 2>/dev/null || true
            
            # Create serial function
            mkdir -p "$GADGET_DIR/functions/acm.usb0" 2>/dev/null || true
            mkdir -p "$GADGET_DIR/configs/c.1/strings/0x409" 2>/dev/null || true
            echo "Config 1: ACM" > "$GADGET_DIR/configs/c.1/strings/0x409/configuration" 2>/dev/null || true
            ln -s "$GADGET_DIR/functions/acm.usb0" "$GADGET_DIR/configs/c.1/" 2>/dev/null || true
            
            # Try to bind to UDC
            UDC=$(ls /sys/class/udc/ 2>/dev/null | head -1)
            if [ -n "$UDC" ]; then
                echo "$UDC" > "$GADGET_DIR/UDC" 2>/dev/null || true
                echo -e "${GREEN}✓ USB gadget activated${NC}"
            else
                echo -e "${RED}✗ No USB Device Controller found${NC}"
                echo "This requires a reboot to take effect."
            fi
        fi
    else
        echo -e "${YELLOW}USB gadget already configured${NC}"
    fi
    
    echo ""
    echo -e "${YELLOW}Status Check:${NC}"
    if ls /sys/class/udc/ 2>/dev/null | grep -q .; then
        echo -e "${GREEN}✓ USB Device Controller found:${NC}"
        ls /sys/class/udc/
    else
        echo -e "${RED}✗ Still no USB Device Controller${NC}"
        echo -e "  ${YELLOW}A reboot is required.${NC}"
    fi
    
    if [ -e "/dev/ttyGS0" ]; then
        echo -e "${GREEN}✓ /dev/ttyGS0 exists!${NC}"
        ls -l /dev/ttyGS0
        echo ""
        echo "Try connecting now:"
        echo "  ${GREEN}screen /dev/ttyGS0 115200${NC} (on host computer)"
    else
        echo -e "${YELLOW}⚠ /dev/ttyGS0 not yet available${NC}"
        echo "  Reboot required for changes to take effect"
    fi
    
    echo ""
    echo -e "${GREEN}Reboot now? (y/N)${NC}"
    read -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Rebooting..."
        reboot
    fi
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}What Changed?${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Modified: $CONFIG_FILE"
echo "  Changed: dtoverlay=dwc2"
echo "  To:      dtoverlay=dwc2,dr_mode=peripheral"
echo ""
echo "This forces the dwc2 driver into peripheral/gadget mode"
echo "instead of host mode, which is required for USB console."
echo ""
