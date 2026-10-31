# Plasma Mobile on RPi4 - Quick Reference Card

## 🚀 One-Line Install
```bash
curl -fsSL https://raw.githubusercontent.com/Philip-McColl-sd/Little_Rascal_Smart_Phone/main/scripts/setup.sh | bash
```

## 📝 Manual Installation (Copy-Paste Commands)

### 1. Flash Configuration
- Raspberry Pi OS Lite (64-bit)
- Configure: Username, Password, SSH only
- Skip: WiFi, hostname, locale

### 2. First Boot
```bash
# When you see "completed socket interaction" - PRESS ENTER!
```

### 3. WiFi Setup (if not using ethernet)
```bash
sudo raspi-config
# Select: System Options → Wireless LAN
```

### 4. SSH Connection
```bash
hostname -I  # Get IP address
# Then from laptop: ssh username@IP_ADDRESS
```

### 5. Fix IPv6 Issues
```bash
# Debian 13 (Trixie) has no /etc/sysctl.conf; use a drop-in file
sudo nano /etc/sysctl.d/99-disable-ipv6.conf
# Add these lines:
# net.ipv6.conf.all.disable_ipv6 = 1
# net.ipv6.conf.default.disable_ipv6 = 1
# net.ipv6.conf.lo.disable_ipv6 = 1
sudo sysctl --system
```

### 6. Update System
```bash
sudo apt update && sudo apt full-upgrade -y
```

### 7. Install Plasma Mobile
```bash
sudo apt-get -o Acquire::ForceIPv4=true install -y plasma-mobile plasma-mobile-tweaks plasma-settings plasma-phonebook plasma-dialer spacebar angelfish okular-mobile kscreen
```

### 8. Install Display Manager
```bash
sudo apt-get -o Acquire::ForceIPv4=true install -y sddm
```

### 9. Enable Graphical Boot
```bash
sudo systemctl enable sddm
sudo systemctl set-default graphical.target
```

### 10. Reboot
```bash
sudo reboot
```

## 📡 Cellular Modem Setup (Optional) — Waveshare SIM7600G-H 4G HAT

### 11. Physical Setup (BEFORE powering anything on)
1. Insert SIM fully, correct orientation, until it clicks/seats
   (hot-swap while running is NOT detected)
2. Click both antennas firmly onto the HAT:
   - MAIN = required (TX+RX)
   - AUX = optional (RX diversity)
   - Press until the u.FL connector seats — a loose MAIN antenna looks fine
     on signal but silently fails to attach
3. Seat the HAT firmly on the Pi's GPIO header

### 12. Power On (once, cleanly)
```bash
# Power the Pi first, then hold the modem's PWR button ~2-3s
# Don't touch SIM/antennas after this - any change needs a full power cycle
```

### 13. Check Registration
```bash
mmcli -L
mmcli -m 0
```
Look for: `state: registered`, `registration: home`,
`packet service state: attached`

### 14. Test a Voice Call
```bash
sudo mmcli -m 0 --voice-create-call="number=+56XXXXXXXXX"
mmcli --call=<path>
```
Expected: `dialing` → `ringing-out` → `active` once answered
(Audio needs SPK+/SPK-/MIC+/MIC- wired to a speaker/mic — not covered here)

### 15. Set Up Mobile Data
```bash
# Installed by setup.sh: suggests the APN for your SIM
sudo little-rascal-mobile-data

# Manual alternative (WOM Chile shown; use your carrier's APN)
sudo nmcli connection add type gsm ifname "*" con-name "Mobile Data" apn internet connection.autoconnect yes ipv4.route-metric 700 ipv6.method disabled
sudo nmcli connection up "Mobile Data"

# Test through the modem (normal traffic stays on Wi-Fi)
ping -I wwan0 -c 4 8.8.8.8
```

## 📷 Camera (Optional)

`setup.sh` installs the **Camera** app. For a manual install, see Step 9 of the
full guide.

- Photos: `~/Pictures/Camera/` (1944x2592)
- Videos: `~/Videos/Camera/` (1280x720, about 30 fps, no sound)
- Upside down? Change `ROTATION` in `/usr/local/bin/little-rascal-camera`
  (270 or 90)

## 🔧 Quick Fixes

### Rotate Screen (90° clockwise)
```bash
sudo nano /boot/firmware/config.txt
# Add: display_rotate=1
sudo reboot
```

### Increase GPU Memory
```bash
sudo nano /boot/firmware/config.txt
# Add: gpu_mem=256
sudo reboot
```

### Restart Display Manager
```bash
sudo systemctl restart sddm
```

### Check SDDM Status
```bash
sudo systemctl status sddm
```

### Get IP Address
```bash
hostname -I
```

### View Logs
```bash
journalctl -xe
```

## 🐛 Emergency Troubleshooting

| Problem | Solution |
|---------|----------|
| Boot hangs | Press ENTER |
| No GUI | `sudo apt install sddm && sudo systemctl start sddm` |
| Network errors | Disable IPv6 (see step 5) |
| SSH fails | IP changed, get new IP with `hostname -I` |
| Black screen | `sudo systemctl restart sddm` |
| Modem stuck "searching" | Power cycle with SIM/antennas seated before power-on (step 11-12) |
| Call stuck "dialing", self-terminates | Recheck step 13; if that's fine, it may be the network (no 3G/2G fallback) |
| Mobile data won't start | Check registration (step 13) and your carrier's APN |
| Camera error: "__init__ sequence did not complete" | Another app has the camera open; close it |
| Camera picture black | Remove any lens cover, add light, then reseat the ribbon cable |
| Videos won't open, VLC closes | Check `/usr/local/share/applications/vlc.desktop` exists (full guide, Step 9.1) |
| `mmcli --command` → "Unauthorized: debug mode" | Restart ModemManager in debug mode (see full guide) |

## 📦 Useful Commands

### Check if Plasma Mobile installed
```bash
dpkg -l | grep plasma-mobile
```

### Install more apps
```bash
sudo apt search app-name
sudo apt install app-name
```

### System info
```bash
neofetch
```

### Disk usage
```bash
df -h
```

### Memory usage
```bash
free -h
```

### System monitor
```bash
htop
```

## 📱 Post-Installation Apps to Try

```bash
# Web browsers
sudo apt install firefox-esr

# Communication
sudo apt install telegram-desktop

# Media
sudo apt install vlc

# Office
sudo apt install libreoffice

# Development
sudo apt install code-oss

# File management
sudo apt install nemo

# PDF reader
sudo apt install evince
```

## ⚡ Performance Tips

1. Use fast SD card (Class 10/A1)
2. Increase GPU memory to 256MB
3. Disable unused services:
```bash
sudo systemctl disable bluetooth  # if not using
sudo systemctl disable cups       # if no printer
```

## 🔑 Default Credentials

- **Username:** What you set during flash
- **Password:** What you set during flash
- **SSH:** Enabled if configured during flash

## 📊 System Requirements

- **Minimum:** RPi 4B (2GB RAM)
- **Recommended:** RPi 4B (4GB+ RAM)
- **Storage:** 32GB+ SD card
- **Internet:** Required for installation

## 🎯 Critical Success Factors

✅ Use Raspberry Pi OS (Debian-based)
✅ Disable IPv6 before installing
✅ Force IPv4 during package installation
✅ Install SDDM display manager
✅ Use minimal flash configuration

## ⏱️ Expected Timeline

- Flash: 5 minutes
- Boot & Setup: 10 minutes
- System Update: 10 minutes
- Plasma Install: 20 minutes
- Configure & Reboot: 5 minutes
- **Total: 30-60 minutes**

## 📞 Get Help

- GitHub Issues: [Your Repo URL]
- Flow Diagram: See Installation-Flow-Diagram.md
- Full Guide: See Plasma-Mobile-RPi4-Complete-Guide.md

---

**Print this card and keep it handy during installation!**

*Version 1.0 - 2025-10-25*
