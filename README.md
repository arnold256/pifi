# PiFi - Automatic WiFi Manager for Raspberry Pi

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Python 3.9+](https://img.shields.io/badge/python-3.9+-blue.svg)](https://www.python.org/downloads/)
[![Raspberry Pi](https://img.shields.io/badge/Raspberry%20Pi-OS%20Bookworm-red.svg)](https://www.raspberrypi.com/software/)

Never get locked out of your Raspberry Pi again. PiFi automatically creates a WiFi hotspot with a web-based configuration portal whenever your Pi can't connect to a known network. Perfect for headless setups, IoT projects, and taking your Pi on the go.

✨ **Zero configuration** • 🔄 **Auto AP fallback** • 📱 **Captive portal** • 🎯 **Built for Pi OS Bookworm**

## Features

- **🔄 Automatic Mode Switching** - Seamlessly switches between WiFi client and access point modes
- **📱 Captive Portal** - Mobile-friendly web interface that auto-opens on connection
- **🔍 Network Scanner** - Shows available WiFi networks with signal strength
- **💾 Multi-Network Support** - Remembers and auto-connects to known networks
- **🔒 Secure** - Optional WPA2 password protection for AP mode
- **⚡ Fast Activation** - AP mode ready in 20-30 seconds
- **🛠️ Reliable** - Built on NetworkManager with comprehensive error handling
- **📊 Monitoring Tools** - Built-in utilities for status checking and diagnostics

## Perfect For

- **Headless Pi Projects** - No keyboard or monitor needed
- **IoT Deployments** - Self-configuring remote devices
- **Mobile Projects** - Robots, drones, portable devices
- **Multi-Location Setups** - Home, office, workshop
- **Education** - Easy setup for students and workshops
- **Gifts** - Non-technical users can configure easily

## Quick Start

### Installation (3 Commands)

```bash
git clone https://github.com/arnold256/pifi.git
cd pifi
sudo ./install.sh
```

Then reboot:
```bash
sudo reboot
```

### First Use

1. **Wait 20-30 seconds** after boot
2. **Connect** to WiFi network: `PiConfigAP` (from your phone/laptop)
3. **Configure** - Browser opens automatically to http://192.168.4.1
4. **Enter** your WiFi credentials and click "Save & Connect"
5. **Done!** Pi connects to your WiFi, AP disappears

## How It Works

```
┌─────────────────────────────────────────────────────────┐
│  Boot → Check for WiFi → Found? → Connect → Monitor    │
│                             │                            │
│                             ↓ Not Found                  │
│                      Create Access Point                 │
│                             │                            │
│                             ↓                            │
│                   User Connects to AP                    │
│                             │                            │
│                             ↓                            │
│                  Portal Opens Automatically              │
│                             │                            │
│                             ↓                            │
│              User Enters WiFi Credentials                │
│                             │                            │
│                             ↓                            │
│              Pi Connects → AP Stops → Success!          │
│                             │                            │
│                Connection Lost? ─┐                       │
│                                  │                       │
│         ┌────────────────────────┘                       │
│         └──→ Start AP Again (Automatic)                  │
└─────────────────────────────────────────────────────────┘
```

## System Requirements

### Hardware
- Raspberry Pi with WiFi (Zero 2 W, 3B+, 4B, 5)
- SD card with 100MB+ free space
- Power supply

### Software
- Raspberry Pi OS Bookworm (2023+)
- NetworkManager 1.42+
- Python 3.9+

## Documentation

- **[Installation Guide](docs/INSTALL.md)** - Detailed installation instructions
- **[Quick Start Guide](docs/QUICKSTART.md)** - Get running in 5 minutes
- **[User Guide](docs/USER_GUIDE.md)** - Complete usage documentation
- **[Troubleshooting](docs/TROUBLESHOOTING.md)** - Common issues and solutions
- **[API Reference](docs/API.md)** - For advanced users and developers

## Advanced Usage

### Custom AP Configuration

```bash
# Set custom AP name and password
sudo AP_SSID="MyPiAP" AP_PASSWORD="MySecurePass123" ./install.sh
```

### Monitoring

```bash
# Check status
./scripts/pifi-status.sh

# Watch logs
sudo journalctl -u wifi-manager -f

# Run diagnostics
sudo ./scripts/pifi-verify.sh
```

### Manual Control

```bash
# Start AP manually
sudo nmcli connection up pi-hotspot

# Connect to specific network
sudo nmcli device wifi connect "SSID" password "PASSWORD"

# List saved networks
nmcli connection show
```

## Architecture

PiFi consists of two main components:

1. **WiFi Manager** (`wifi_manager.py`)
   - Monitors WiFi connection state
   - Manages automatic switching between modes
   - Handles connection attempts and retries

2. **Configuration Portal** (`config_portal.py`)
   - Flask-based web server
   - Network scanning and display
   - WiFi credential management
   - Captive portal detection endpoints

Both services run as systemd daemons and use NetworkManager for all network operations.

## Compatibility

| OS Version | Status | Notes |
|------------|--------|-------|
| Bookworm (Debian 12) | ✅ Fully Supported | Recommended |

| Hardware | Status | Notes |
|----------|--------|-------|
| Pi Zero 2 W | ✅ Tested | Primary test platform |


## Troubleshooting

### AP Not Appearing

```bash
sudo systemctl status wifi-manager
sudo journalctl -u wifi-manager -n 50
sudo nmcli connection up pi-hotspot
```

### Portal Not Accessible

```bash
sudo systemctl restart config-portal
curl http://192.168.4.1
```

### WiFi Won't Connect

```bash
nmcli connection show
sudo journalctl -u wifi-manager -f
```

See [Troubleshooting Guide](docs/TROUBLESHOOTING.md) for more details.


## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.