# Troubleshooting: Python Syntax Errors

## The Problem

You're seeing syntax errors when the installation checks `/usr/local/bin/wifi_manager.py`.

## Likely Causes

1. **Incomplete Installation** - The install script didn't properly copy the Python code
2. **File Corruption** - Transfer or encoding issue
3. **Old Version** - You might have an older/incomplete version

## Quick Fix Solutions

### Solution 1: Use the Verification Script (Recommended)

Run the verification and repair script:

```bash
chmod +x verify_and_fix.sh
sudo ./verify_and_fix.sh
```

This will:
- Check for syntax errors
- Offer to reinstall the problematic files
- Verify all components
- Test the services

### Solution 2: Use Direct Installation

Use the simpler direct installation method:

```bash
# Make sure you're in the directory with all the source files
ls wifi_manager_nm.py config_portal_nm.py  # Should exist

# Run direct installer
chmod +x install_direct.sh
sudo ./install_direct.sh
```

This copies files directly instead of embedding them, which is more reliable.

### Solution 3: Manual Installation

If both above fail, install manually:

```bash
# 1. Ensure you have the source files
ls -la wifi_manager_nm.py config_portal_nm.py

# 2. Copy scripts
sudo cp wifi_manager_nm.py /usr/local/bin/wifi_manager.py
sudo cp config_portal_nm.py /usr/local/bin/config_portal.py

# 3. Make executable
sudo chmod +x /usr/local/bin/wifi_manager.py
sudo chmod +x /usr/local/bin/config_portal.py

# 4. Test syntax
python3 -m py_compile /usr/local/bin/wifi_manager.py
python3 -m py_compile /usr/local/bin/config_portal.py

# 5. Copy services
sudo cp wifi-manager.service /etc/systemd/system/
sudo cp config-portal.service /etc/systemd/system/

# 6. Enable and start
sudo systemctl daemon-reload
sudo systemctl enable wifi-manager config-portal
sudo systemctl start wifi-manager config-portal

# 7. Check status
sudo systemctl status wifi-manager
```

## Diagnostic Commands

### Check if files exist and are valid Python:

```bash
# Check file exists
ls -la /usr/local/bin/wifi_manager.py

# Check file size (should be ~8-9KB)
du -h /usr/local/bin/wifi_manager.py

# Check if it's a Python file
file /usr/local/bin/wifi_manager.py

# Check for syntax errors
python3 -m py_compile /usr/local/bin/wifi_manager.py

# If errors, show them
python3 /usr/local/bin/wifi_manager.py 2>&1 | head -20
```

### Check source files:

```bash
# Verify source files are valid
python3 -m py_compile wifi_manager_nm.py
python3 -m py_compile config_portal_nm.py

# Check encoding
file wifi_manager_nm.py
```

## Common Error Messages and Fixes

### Error: "SyntaxError: invalid syntax"

**Cause:** Incomplete or corrupted file

**Fix:**
```bash
sudo rm /usr/local/bin/wifi_manager.py
sudo cp wifi_manager_nm.py /usr/local/bin/wifi_manager.py
sudo chmod +x /usr/local/bin/wifi_manager.py
```

### Error: "ImportError: No module named 'X'"

**Cause:** Missing Python dependencies

**Fix:**
```bash
# Install missing module
pip3 install --break-system-packages flask
# Or without flag if it fails
pip3 install flask
```

### Error: "File not found"

**Cause:** Script not copied to destination

**Fix:**
```bash
# Copy from source
sudo cp wifi_manager_nm.py /usr/local/bin/wifi_manager.py
sudo chmod +x /usr/local/bin/wifi_manager.py
```

## Verify Installation

After fixing, verify everything works:

```bash
# 1. Check syntax
python3 -m py_compile /usr/local/bin/wifi_manager.py
python3 -m py_compile /usr/local/bin/config_portal.py

# 2. Check services
sudo systemctl status wifi-manager config-portal

# 3. Check logs
sudo journalctl -u wifi-manager -n 20
sudo journalctl -u config-portal -n 20

# 4. Test NetworkManager
nmcli device status
nmcli connection show
```

## Still Having Issues?

### Get detailed error info:

```bash
# Show exact syntax error
python3 /usr/local/bin/wifi_manager.py

# Show file contents (first 50 lines)
head -50 /usr/local/bin/wifi_manager.py

# Check for weird characters
cat -A /usr/local/bin/wifi_manager.py | head -20
```

### Compare with source:

```bash
# Compare installed vs source
diff /usr/local/bin/wifi_manager.py wifi_manager_nm.py
```

### Check file permissions:

```bash
# Should show: -rwxr-xr-x root root
ls -la /usr/local/bin/wifi_manager.py

# Fix if needed
sudo chown root:root /usr/local/bin/wifi_manager.py
sudo chmod 755 /usr/local/bin/wifi_manager.py
```

## Prevention

To avoid this in the future:

1. **Use direct installation method** - More reliable than heredoc embedding
2. **Transfer files properly** - Use SCP, SFTP, or Git (not copy-paste)
3. **Verify after transfer** - Run `python3 -m py_compile` before installing
4. **Keep source files** - Don't delete the originals

## Quick Reinstall

Complete clean reinstall:

```bash
# 1. Stop services
sudo systemctl stop wifi-manager config-portal

# 2. Remove old files
sudo rm /usr/local/bin/wifi_manager.py
sudo rm /usr/local/bin/config_portal.py

# 3. Reinstall using direct method
sudo ./install_direct.sh

# 4. Reboot
sudo reboot
```

## Check File Integrity

Verify the source files are correct:

```bash
# Check file sizes (approximate)
du -h wifi_manager_nm.py    # Should be ~8-9KB
du -h config_portal_nm.py   # Should be ~16-17KB

# Verify they're Python files
head -1 wifi_manager_nm.py   # Should show #!/usr/bin/env python3
head -1 config_portal_nm.py  # Should show #!/usr/bin/env python3

# Test syntax
python3 -m py_compile wifi_manager_nm.py && echo "OK" || echo "ERROR"
python3 -m py_compile config_portal_nm.py && echo "OK" || echo "ERROR"
```

## Need More Help?

Run the comprehensive verification script:

```bash
sudo ./verify_and_fix.sh
```

This will automatically detect and offer to fix most issues.
