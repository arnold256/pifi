#!/usr/bin/env python3
"""
WiFi Configuration Portal for Raspberry Pi OS (NetworkManager)
Web interface for configuring WiFi connections
"""
from flask import Flask, request, render_template_string, redirect
import subprocess
import shlex
import html
import os
import logging

APP = Flask(__name__)
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Configuration
AP_CONNECTION_NAME = "pi-hotspot"
AP_CONFIG_FILE = "/etc/wifi_manager_ap.conf"

HTML_FORM = """<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Pi WiFi Configuration</title>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }
        .container {
            background: white;
            border-radius: 12px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.2);
            max-width: 500px;
            width: 100%;
            padding: 40px;
        }
        h2 {
            color: #333;
            margin-bottom: 10px;
            font-size: 28px;
        }
        .subtitle {
            color: #666;
            margin-bottom: 30px;
            font-size: 14px;
        }
        fieldset {
            border: 2px solid #e0e0e0;
            border-radius: 8px;
            padding: 20px;
            margin-bottom: 20px;
        }
        legend {
            color: #667eea;
            font-weight: 600;
            padding: 0 10px;
            font-size: 16px;
        }
        label {
            display: block;
            margin-bottom: 5px;
            color: #555;
            font-weight: 500;
            font-size: 14px;
        }
        input, select {
            width: 100%;
            padding: 12px;
            margin-bottom: 15px;
            border: 1px solid #ddd;
            border-radius: 6px;
            font-size: 14px;
            transition: border-color 0.3s;
        }
        input:focus, select:focus {
            outline: none;
            border-color: #667eea;
        }
        button {
            width: 100%;
            padding: 14px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border: none;
            border-radius: 6px;
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
            transition: transform 0.2s;
        }
        button:hover {
            transform: translateY(-2px);
        }
        button:active {
            transform: translateY(0);
        }
        .help-text {
            font-size: 12px;
            color: #888;
            margin-top: -10px;
            margin-bottom: 15px;
        }
        .scan-list {
            max-height: 200px;
            overflow-y: auto;
            border: 1px solid #ddd;
            border-radius: 6px;
            margin-bottom: 15px;
        }
        .scan-item {
            padding: 10px;
            border-bottom: 1px solid #f0f0f0;
            cursor: pointer;
            transition: background-color 0.2s;
        }
        .scan-item:hover {
            background-color: #f8f8f8;
        }
        .scan-item:last-child {
            border-bottom: none;
        }
        .signal-strength {
            float: right;
            color: #888;
            font-size: 12px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h2>🔧 WiFi Setup</h2>
        <p class="subtitle">Configure your Raspberry Pi network connection</p>
        
        <form method="post" action="/configure">
            <fieldset>
                <legend>📡 Connect to WiFi Network</legend>
                
                {% if networks %}
                <label>Available Networks:</label>
                <div class="scan-list">
                    {% for net in networks %}
                    <div class="scan-item" onclick="document.getElementById('ssid').value='{{ net.ssid }}'">
                        <strong>{{ net.ssid }}</strong>
                        <span class="signal-strength">{{ net.signal }}</span>
                    </div>
                    {% endfor %}
                </div>
                {% endif %}
                
                <label for="ssid">Network Name (SSID):</label>
                <input type="text" id="ssid" name="ssid" placeholder="Enter WiFi network name" required>
                
                <label for="password">Password:</label>
                <input type="password" id="password" name="password" placeholder="Leave blank for open networks">
                <p class="help-text">Enter the WiFi password (WPA/WPA2)</p>
            </fieldset>
            
            <fieldset>
                <legend>📶 Access Point Settings</legend>
                
                <label for="ap_ssid">AP Name (SSID):</label>
                <input type="text" id="ap_ssid" name="ap_ssid" placeholder="Leave blank to keep current: {{ current_ap }}">
                
                <label for="ap_pass">AP Password:</label>
                <input type="password" id="ap_pass" name="ap_pass" placeholder="8+ characters for WPA2 security">
                <p class="help-text">Optional: Set a password to secure your access point</p>
            </fieldset>
            
            <button type="submit">💾 Save & Connect</button>
        </form>
    </div>
</body>
</html>
"""

HTML_RESULT = """<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Configuration Saved</title>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }
        .container {
            background: white;
            border-radius: 12px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.2);
            max-width: 500px;
            width: 100%;
            padding: 40px;
            text-align: center;
        }
        h2 {
            color: #667eea;
            margin-bottom: 20px;
            font-size: 32px;
        }
        .success-icon {
            font-size: 64px;
            margin-bottom: 20px;
        }
        p {
            color: #555;
            margin-bottom: 15px;
            line-height: 1.6;
        }
        .info-box {
            background: #f8f9fa;
            border-left: 4px solid #667eea;
            padding: 15px;
            margin: 20px 0;
            text-align: left;
        }
        .info-box strong {
            color: #667eea;
        }
        a {
            display: inline-block;
            margin-top: 20px;
            color: #667eea;
            text-decoration: none;
            font-weight: 600;
        }
        a:hover {
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="success-icon">✅</div>
        <h2>Configuration Saved!</h2>
        
        <div class="info-box">
            <p><strong>WiFi Network:</strong> {{ ssid }}</p>
            {% if ap_ssid %}
            <p><strong>AP Name:</strong> {{ ap_ssid }}</p>
            {% endif %}
        </div>
        
        <p>Your Raspberry Pi is now attempting to connect to the WiFi network.</p>
        <p><strong>What happens next:</strong></p>
        <p>⏱️ Wait 15-30 seconds for the connection to establish.</p>
        <p>📡 If successful, this access point will disappear.</p>
        <p>🌐 You can then access your Pi on your main network.</p>
        <p>🔄 If the connection fails, the access point will restart automatically.</p>
        
        <a href="/">← Back to Configuration</a>
    </div>
</body>
</html>
"""


def run(cmd: str):
    """Execute shell command"""
    try:
        result = subprocess.run(
            shlex.split(cmd),
            capture_output=True,
            text=True,
            timeout=30
        )
        return result
    except Exception as e:
        logger.error(f"Command failed: {cmd} - {e}")
        return None


def scan_networks():
    """Scan for available WiFi networks"""
    try:
        result = run("nmcli -t -f SSID,SIGNAL,SECURITY device wifi list")
        if not result or result.returncode != 0:
            return []
        
        networks = []
        seen_ssids = set()
        
        for line in result.stdout.splitlines():
            parts = line.split(':')
            if len(parts) >= 2:
                ssid = parts[0].strip()
                if ssid and ssid not in seen_ssids:
                    seen_ssids.add(ssid)
                    signal = parts[1] if len(parts) > 1 else "?"
                    networks.append({
                        'ssid': ssid,
                        'signal': f"{signal}%" if signal.isdigit() else signal
                    })
        
        # Sort by signal strength
        networks.sort(key=lambda x: int(x['signal'].rstrip('%')) if x['signal'].rstrip('%').isdigit() else 0, reverse=True)
        return networks[:10]  # Top 10
        
    except Exception as e:
        logger.error(f"Network scan failed: {e}")
        return []


def get_current_ap_ssid():
    """Get current AP SSID from NetworkManager"""
    try:
        result = run(f"nmcli -t -f 802-11-wireless.ssid connection show {AP_CONNECTION_NAME}")
        if result and result.returncode == 0:
            ssid = result.stdout.strip().split(':')[-1]
            return ssid if ssid else "PiConfigAP"
    except Exception:
        pass
    return "PiConfigAP"


def add_wifi_connection(ssid: str, password: str = None):
    """Add a new WiFi connection to NetworkManager"""
    try:
        logger.info(f"Adding WiFi connection: {ssid}")
        
        # Remove existing connection with same SSID if it exists (ignore errors)
        delete_result = subprocess.run(
            ["nmcli", "connection", "delete", ssid],
            capture_output=True,
            text=True
        )
        if delete_result.returncode == 0:
            logger.info(f"Deleted existing connection: {ssid}")
        
        # Build connection command
        cmd_parts = [
            "nmcli", "connection", "add",
            "type", "wifi",
            "ifname", "wlan0",
            "con-name", ssid,
            "ssid", ssid,
            "autoconnect", "yes"
        ]
        
        if password:
            cmd_parts.extend([
                "wifi-sec.key-mgmt", "wpa-psk",
                "wifi-sec.psk", password
            ])
        else:
            # Open network
            cmd_parts.extend([
                "wifi-sec.key-mgmt", "none"
            ])
        
        logger.info(f"Executing: {' '.join(cmd_parts[:8])}...")  # Log command (without password)
        result = subprocess.run(cmd_parts, capture_output=True, text=True, timeout=30)
        
        if result.returncode == 0:
            logger.info(f"WiFi connection added successfully: {ssid}")
            # Try to activate it
            logger.info(f"Attempting to connect to: {ssid}")
            activate_result = subprocess.run(
                ["nmcli", "connection", "up", ssid],
                capture_output=True,
                text=True,
                timeout=30
            )
            if activate_result.returncode == 0:
                logger.info(f"Successfully connected to: {ssid}")
                return True
            else:
                logger.warning(f"Added but couldn't immediately connect to: {ssid}")
                logger.warning(f"Connection error: {activate_result.stderr.strip()}")
                return True
        else:
            # Log full error
            logger.error(f"Failed to add connection: {ssid}")
            logger.error(f"Error output: {result.stderr.strip()}")
            logger.error(f"Return code: {result.returncode}")
            return False
            
    except subprocess.TimeoutExpired:
        logger.error(f"Timeout adding WiFi connection: {ssid}")
        return False
    except Exception as e:
        logger.error(f"Error adding WiFi connection: {ssid} - {str(e)}")
        return False


def update_ap_settings(ssid: str = None, password: str = None):
    """Update AP connection settings"""
    try:
        if not ssid and not password:
            return False
        
        logger.info(f"Updating AP settings - SSID: {ssid}, Password: {'set' if password else 'not set'}")
        
        # Update SSID
        if ssid:
            result = run(f"nmcli connection modify {AP_CONNECTION_NAME} 802-11-wireless.ssid '{ssid}'")
            if result and result.returncode != 0:
                logger.error("Failed to update AP SSID")
                return False
        
        # Update password
        if password and len(password) >= 8:
            run(f"nmcli connection modify {AP_CONNECTION_NAME} wifi-sec.key-mgmt wpa-psk")
            run(f"nmcli connection modify {AP_CONNECTION_NAME} wifi-sec.psk '{password}'")
            # Save password to config file
            try:
                with open(AP_CONFIG_FILE, 'w') as f:
                    f.write(f'AP_PASSWORD="{password}"\n')
                os.chmod(AP_CONFIG_FILE, 0o600)
            except Exception as e:
                logger.error(f"Failed to save AP password: {e}")
        elif password:
            logger.warning("AP password too short (must be 8+ characters)")
        
        # Restart AP connection if it's active
        result = run(f"nmcli connection show --active | grep {AP_CONNECTION_NAME}")
        if result and result.returncode == 0:
            run(f"nmcli connection down {AP_CONNECTION_NAME}")
            run(f"nmcli connection up {AP_CONNECTION_NAME}")
        
        logger.info("AP settings updated successfully")
        return True
        
    except Exception as e:
        logger.error(f"Error updating AP settings: {e}")
        return False


@APP.route("/")
@APP.route("/index.html")
@APP.route("/generate_204")  # Android captive portal detection
@APP.route("/hotspot-detect.html")  # iOS captive portal detection
def index():
    """Main configuration page"""
    networks = scan_networks()
    current_ap = get_current_ap_ssid()
    return render_template_string(HTML_FORM, networks=networks, current_ap=current_ap)


@APP.route("/configure", methods=["POST"])
def configure():
    """Handle configuration form submission"""
    try:
        ssid = request.form.get("ssid", "").strip()
        password = request.form.get("password", "").strip()
        ap_ssid = request.form.get("ap_ssid", "").strip()
        ap_pass = request.form.get("ap_pass", "").strip()
        
        success = False
        
        # Add WiFi connection
        if ssid:
            success = add_wifi_connection(ssid, password if password else None)
        
        # Update AP settings
        if ap_ssid or ap_pass:
            update_ap_settings(ap_ssid if ap_ssid else None, ap_pass if ap_pass else None)
        
        return render_template_string(
            HTML_RESULT,
            ssid=html.escape(ssid if ssid else "(unchanged)"),
            ap_ssid=html.escape(ap_ssid if ap_ssid else "")
        )
        
    except Exception as e:
        logger.error(f"Configuration error: {e}")
        return f"<h1>Error</h1><p>{html.escape(str(e))}</p><a href='/'>Back</a>", 500


@APP.route("/status")
def status():
    """API endpoint for connection status"""
    try:
        result = run("nmcli -t -f TYPE,STATE device")
        if result and result.returncode == 0:
            for line in result.stdout.splitlines():
                if "wifi:connected" in line:
                    conn_result = run("nmcli -t -f GENERAL.CONNECTION device show wlan0")
                    if conn_result:
                        return {"status": "connected", "connection": conn_result.stdout.strip()}
        return {"status": "disconnected"}
    except Exception as e:
        return {"status": "error", "message": str(e)}, 500


if __name__ == "__main__":
    # Ensure running as root
    if os.geteuid() != 0:
        print("This script must be run as root")
        exit(1)
    
    logger.info("Starting WiFi configuration portal...")
    APP.run(host="0.0.0.0", port=80, debug=False)
