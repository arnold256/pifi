#!/usr/bin/env python3
"""
WiFi Manager for Raspberry Pi OS (NetworkManager)
Automatically switches between AP mode and client mode
"""
import os
import subprocess
import time
import shlex
import logging

# Configuration
AP_SSID = "PiConfigAP"
AP_CONNECTION_NAME = "pi-hotspot"
WLAN_IF = "wlan0"
AP_IP = "192.168.4.1/24"
CHECK_INTERVAL = 10  # seconds

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


def run(cmd: str, check=False):
    """Run a shell command and return result"""
    try:
        result = subprocess.run(
            shlex.split(cmd),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=30
        )
        if check and result.returncode != 0:
            logger.error(f"Command failed: {cmd}\nError: {result.stderr}")
        return result
    except subprocess.TimeoutExpired:
        logger.error(f"Command timed out: {cmd}")
        return None
    except Exception as e:
        logger.error(f"Error running command '{cmd}': {e}")
        return None


def is_wifi_connected() -> bool:
    """Check if connected to any WiFi network as a client"""
    result = run("nmcli -t -f TYPE,STATE device")
    if result and result.returncode == 0:
        for line in result.stdout.splitlines():
            # Check for exact "connected" state, not "disconnected"
            if line.startswith("wifi:connected"):
                # Check if it's not our AP connection
                conn_result = run("nmcli -t -f GENERAL.CONNECTION device show wlan0")
                if conn_result and conn_result.returncode == 0:
                    conn_name = conn_result.stdout.strip().split(':')[-1]
                    if conn_name and conn_name != AP_CONNECTION_NAME:
                        logger.info(f"Connected to WiFi: {conn_name}")
                        return True
    return False


def is_ap_active() -> bool:
    """Check if AP mode is currently active"""
    result = run(f"nmcli -t -f GENERAL.CONNECTION device show {WLAN_IF}")
    if result and result.returncode == 0:
        conn_name = result.stdout.strip().split(':')[-1]
        if conn_name == AP_CONNECTION_NAME:
            logger.debug("AP mode is active")
            return True
    return False


def ap_connection_exists() -> bool:
    """Check if AP connection profile exists"""
    result = run(f"nmcli -t -f NAME connection show {AP_CONNECTION_NAME}")
    return result is not None and result.returncode == 0


def create_ap_connection():
    """Create NetworkManager AP connection if it doesn't exist"""
    if ap_connection_exists():
        logger.info("AP connection already exists")
        return True
    
    logger.info(f"Creating AP connection: {AP_CONNECTION_NAME}")
    
    # Read AP password from config file if it exists
    ap_password = None
    config_file = "/etc/wifi_manager_ap.conf"
    if os.path.exists(config_file):
        try:
            with open(config_file, 'r') as f:
                for line in f:
                    if line.startswith("AP_PASSWORD="):
                        ap_password = line.split('=', 1)[1].strip().strip('"\'')
        except Exception as e:
            logger.error(f"Error reading AP config: {e}")
    
    # Create AP connection
    cmd_parts = [
        "nmcli", "connection", "add",
        "type", "wifi",
        "ifname", WLAN_IF,
        "con-name", AP_CONNECTION_NAME,
        "autoconnect", "no",
        "ssid", AP_SSID,
        "mode", "ap",
        "ipv4.method", "shared",
        "ipv4.addresses", AP_IP
    ]
    
    # Add WPA2 security if password is configured
    if ap_password and len(ap_password) >= 8:
        cmd_parts.extend([
            "wifi-sec.key-mgmt", "wpa-psk",
            "wifi-sec.psk", ap_password
        ])
    
    result = subprocess.run(cmd_parts, capture_output=True, text=True)
    
    if result.returncode == 0:
        logger.info("AP connection created successfully")
        return True
    else:
        logger.error(f"Failed to create AP connection: {result.stderr}")
        return False


def start_ap():
    """Activate AP mode"""
    if is_ap_active():
        logger.debug("AP already active")
        return
    
    logger.info("Starting AP mode...")
    
    # Ensure AP connection exists
    if not create_ap_connection():
        logger.error("Cannot start AP - connection creation failed")
        return
    
    # Deactivate any active WiFi connections
    result = run(f"nmcli device disconnect {WLAN_IF}")
    time.sleep(2)
    
    # Activate AP
    result = run(f"nmcli connection up {AP_CONNECTION_NAME}")
    if result and result.returncode == 0:
        logger.info(f"AP mode activated: {AP_SSID}")
    else:
        logger.error("Failed to activate AP mode")


def stop_ap():
    """Deactivate AP mode"""
    if not is_ap_active():
        return
    
    logger.info("Stopping AP mode...")
    run(f"nmcli connection down {AP_CONNECTION_NAME}")


def try_connect_wifi():
    """Try to connect to available known networks"""
    logger.info("Scanning for known networks...")
    
    # Get list of known WiFi connections (excluding AP)
    result = run("nmcli -t -f NAME,TYPE connection show")
    if not result or result.returncode != 0:
        return False
    
    wifi_connections = []
    for line in result.stdout.splitlines():
        name, conn_type = line.split(':', 1)
        if conn_type == "802-11-wireless" and name != AP_CONNECTION_NAME:
            wifi_connections.append(name)
    
    if not wifi_connections:
        logger.debug("No known WiFi networks configured")
        return False
    
    # Try each connection
    for conn_name in wifi_connections:
        logger.info(f"Attempting to connect to: {conn_name}")
        result = run(f"nmcli connection up {conn_name}")
        if result and result.returncode == 0:
            logger.info(f"Successfully connected to: {conn_name}")
            return True
        time.sleep(2)
    
    return False


def main():
    """Main loop"""
    logger.info("WiFi Manager starting...")
    logger.info(f"AP SSID: {AP_SSID}")
    logger.info(f"Interface: {WLAN_IF}")
    
    # Ensure AP connection exists
    create_ap_connection()
    
    last_state = None
    consecutive_failures = 0
    
    while True:
        try:
            connected = is_wifi_connected()
            ap_active = is_ap_active()
            
            if connected and ap_active:
                # Connected to WiFi but AP is still on - turn off AP
                logger.info("WiFi connected - stopping AP")
                stop_ap()
                consecutive_failures = 0
                
            elif not connected and not ap_active:
                # Not connected and AP is off
                consecutive_failures += 1
                
                # Try to connect to known networks first
                if consecutive_failures <= 2:
                    logger.info("Attempting to connect to known WiFi...")
                    if try_connect_wifi():
                        consecutive_failures = 0
                        time.sleep(CHECK_INTERVAL)
                        continue
                
                # Start AP if connection attempts fail
                logger.info("No WiFi connection - starting AP mode")
                start_ap()
                consecutive_failures = 0
                
            elif connected and not ap_active:
                # All good - connected to WiFi
                consecutive_failures = 0
                if last_state != "connected":
                    logger.info("WiFi connection stable")
                    
            elif not connected and ap_active:
                # AP is running, periodically try to connect
                if consecutive_failures > 0 and consecutive_failures % 6 == 0:  # Every minute
                    logger.info("Periodic WiFi connection attempt...")
                    stop_ap()
                    if try_connect_wifi():
                        consecutive_failures = 0
                    else:
                        start_ap()
                consecutive_failures += 1
            
            last_state = "connected" if connected else "ap"
            
        except Exception as e:
            logger.error(f"Error in main loop: {e}")
        
        time.sleep(CHECK_INTERVAL)


if __name__ == "__main__":
    # Ensure running as root
    if os.geteuid() != 0:
        print("This script must be run as root")
        exit(1)
    
    main()
