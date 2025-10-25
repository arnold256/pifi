# Quick Start Guide
## Get Your Raspberry Pi WiFi Manager Running in 5 Minutes

### What You'll Get

After following this guide, your Raspberry Pi will:
- ✅ Automatically create a WiFi hotspot when not connected
- ✅ Show a configuration portal at http://192.168.4.1
- ✅ Let you configure WiFi from your phone/laptop
- ✅ Auto-connect to saved networks
- ✅ Switch back to hotspot mode when out of range

### Prerequisites

- Raspberry Pi Zero 2 W (or any Pi with WiFi)
- Raspberry Pi OS Bookworm or newer
- SD card with Raspberry Pi OS installed
- Keyboard and monitor OR SSH access

### Installation (3 Commands)

```bash
# 1. Download the files to your Pi
# (Upload them or git clone your repository)

# 2. Make the install script executable
chmod +x install_wifi_manager.sh

# 3. Run the installer
sudo ./install_wifi_manager.sh
```

**That's it!** The script will:
- Install required packages
- Set up the services
- Configure NetworkManager
- Enable everything to start on boot

### First Use

1. **Reboot your Pi:**
   ```bash
   sudo reboot
   ```

2. **Wait ~20 seconds** after boot

3. **Look for WiFi network** named `PiConfigAP`

4. **Connect to it** from your phone or laptop
   - Password: (none - open network by default)

5. **Browser should open automatically** to configuration page
   - If not, go to: **http://192.168.4.1**

6. **Enter your WiFi credentials** and click "Save & Connect"

7. **Wait 15-30 seconds** - the hotspot will disappear when connected

8. **Done!** Your Pi is now on your WiFi network

### Finding Your Pi

After connecting to your WiFi, find your Pi's IP address:

**Option 1 - Check your router:**
- Look for "raspberrypi" in connected devices

**Option 2 - Use hostname:**
```bash
ssh pi@raspberrypi.local
```

**Option 3 - Scan network:**
```bash
nmap -sn 192.168.1.0/24  # Adjust for your network
```

### Common Scenarios

#### Scenario 1: Moving to New Location
*"I'm taking my Pi to a friend's house"*

1. Pi boots and can't find your home WiFi
2. After ~20 seconds, hotspot appears
3. Connect and configure new WiFi
4. Done!

#### Scenario 2: WiFi Password Changed
*"I changed my router password"*

1. Pi can't connect with old password
2. Hotspot appears automatically
3. Connect and enter new password
4. Pi reconnects

#### Scenario 3: Multiple Locations
*"I use my Pi at home and at work"*

1. Configure home WiFi when at home
2. Configure work WiFi when at work
3. Pi automatically connects to whichever is available
4. Uses hotspot if neither are available

### Customization

#### Change Hotspot Name (Before Install)

```bash
sudo AP_SSID="MyPi" ./install_wifi_manager.sh
```

#### Add Hotspot Password (Before Install)

```bash
sudo AP_SSID="MyPi" AP_PASSWORD="MyPassword123" ./install_wifi_manager.sh
```

#### Change Settings (After Install)

1. Connect to the hotspot
2. Go to http://192.168.4.1
3. Use the "Access Point Settings" section
4. Save changes

### Troubleshooting

#### Hotspot Doesn't Appear

```bash
# Check if service is running
sudo systemctl status wifi-manager

# View logs
sudo journalctl -u wifi-manager -n 50

# Restart service
sudo systemctl restart wifi-manager
```

#### Can't Access Portal

```bash
# Make sure you're on the Pi's hotspot
# Try: http://192.168.4.1
# Or:  http://raspberrypi.local

# Check portal status
sudo systemctl status config-portal
```

#### WiFi Won't Connect

```bash
# Check saved networks
nmcli connection show

# Try manual connect
nmcli device wifi connect "YourSSID" password "YourPassword"

# View logs
sudo journalctl -u wifi-manager -f
```

### Useful Commands

```bash
# View status
./wifi_manager_helper.sh status

# View logs
./wifi_manager_helper.sh logs

# Restart services
sudo systemctl restart wifi-manager config-portal

# Check WiFi networks
nmcli device wifi list
```

### What's Happening Behind the Scenes

```
Boot
  ↓
Check for known WiFi networks
  ↓
Found? ───Yes──→ Connect ──→ Success! ──→ Monitor connection
  │                                            ↓
  No                                    Connection lost?
  ↓                                            ↓
Start hotspot                                 Yes
  ↓                                            ↓
Wait for configuration                   Start hotspot
  ↓                                            ↑
User configures WiFi                          │
  ↓                                            │
Save & try to connect                         │
  ↓                                            │
Success? ───Yes──→ Stop hotspot ─────────────┘
  │
  No
  ↓
Show error, keep hotspot running
```

### Default Settings

| Setting | Value |
|---------|-------|
| Hotspot SSID | `PiConfigAP` |
| Hotspot IP | `192.168.4.1` |
| Hotspot Password | (none - open) |
| Portal URL | http://192.168.4.1 |
| Check Interval | 10 seconds |
| Connection Timeout | ~20 seconds |

### Security Note

**Default configuration has NO password** for the hotspot.

For better security:
```bash
# Set a password during install
sudo AP_SSID="MyPi" AP_PASSWORD="SecurePass123" ./install_wifi_manager.sh
```

Or configure it later through the web portal.

### Getting Help

1. **Check the full README.md** for detailed documentation
2. **View logs:** `sudo journalctl -u wifi-manager -f`
3. **Check service status:** `sudo systemctl status wifi-manager`
4. **Use helper script:** `./wifi_manager_helper.sh status`

### Next Steps

Once your Pi is connected:
- Set up your projects
- Configure SSH keys for secure access
- Set up automatic updates
- Install your favorite software

**Enjoy your auto-configuring Raspberry Pi!** 🎉
