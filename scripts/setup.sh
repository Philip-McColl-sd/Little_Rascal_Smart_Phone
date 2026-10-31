#!/bin/bash
# SPDX-FileCopyrightText: 2025-2026 Philip McColl
# SPDX-License-Identifier: GPL-3.0-or-later
#
################################################################################
# Plasma Mobile on Raspberry Pi 4 - Automated Installation Script
# 
# This script automates the installation of Plasma Mobile on Raspberry Pi 4
# using Raspberry Pi OS (64-bit) Lite as the base system.
#
# Prerequisites:
#   - Fresh Raspberry Pi OS (64-bit) Lite installation
#   - Internet connection (Ethernet recommended)
#   - Sudo privileges
#
# Usage:
#   wget https://raw.githubusercontent.com/Philip-McColl-sd/Little_Rascal_Smart_Phone/main/scripts/setup.sh
#   chmod +x setup.sh
#   ./setup.sh
#
# Or one-liner:
#   curl -fsSL https://raw.githubusercontent.com/Philip-McColl-sd/Little_Rascal_Smart_Phone/main/scripts/setup.sh | bash
#
# Version: 1.0
# Date: 2025-10-25
# Tested: Raspberry Pi 4B (4GB), Raspberry Pi OS Lite 64-bit
#
# Copyright (C) 2025-2026 Philip McColl
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# WARNING: this script modifies system configuration (sudoers, SDDM,
# Plasma files). Use it at your own risk.
#
# Step 11 embeds the Camera app (GPL-3.0-or-later, like the rest of this file).
#
# This file embeds a modified copy of KDE's Logout.qml (section 9.5),
# which keeps its original copyright notices and remains licensed
# under GPL-2.0-or-later.
################################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Error handler
error_exit() {
    log_error "$1"
    exit 1
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
    error_exit "Please do not run this script as root. Run as normal user with sudo privileges."
fi

# Check if sudo is available
if ! command -v sudo &> /dev/null; then
    error_exit "sudo is required but not found. Please install sudo first."
fi

# Banner
echo "################################################################################"
echo "#                                                                              #"
echo "#           Plasma Mobile on Raspberry Pi 4 - Auto Installer                  #"
echo "#                                                                              #"
echo "#  This script will install Plasma Mobile on your Raspberry Pi 4              #"
echo "#  Total time: ~30-45 minutes depending on internet speed                     #"
echo "#                                                                              #"
echo "################################################################################"
echo ""

# Confirm before proceeding
# Prompts read from /dev/tty: under `curl ... | bash`, stdin is the script
# itself, so a plain `read` would swallow the next line of code.
read -p "Do you want to continue? (y/n) " -n 1 -r < /dev/tty
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_info "Installation cancelled."
    exit 0
fi

################################################################################
# Step 1: System Information
################################################################################
log_info "Gathering system information..."

# Check if running on Raspberry Pi
if [ ! -f /proc/device-tree/model ]; then
    log_warning "Unable to detect Raspberry Pi model"
else
    PI_MODEL=$(tr -d '\0' < /proc/device-tree/model)
    log_info "Detected: $PI_MODEL"
    
    if [[ ! "$PI_MODEL" =~ "Raspberry Pi 4" ]]; then
        log_warning "This script is designed for Raspberry Pi 4. Your device: $PI_MODEL"
        read -p "Continue anyway? (y/n) " -n 1 -r < /dev/tty
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi
fi

# Check architecture
ARCH=$(uname -m)
log_info "Architecture: $ARCH"

if [[ "$ARCH" != "aarch64" ]]; then
    log_warning "This script requires ARM64 architecture. Detected: $ARCH"
    read -p "Continue anyway? (y/n) " -n 1 -r < /dev/tty
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi

# Check Debian version
if [ -f /etc/os-release ]; then
    . /etc/os-release
    log_info "OS: $PRETTY_NAME"
fi

################################################################################
# Step 2: Network Connectivity Check
################################################################################
log_info "Checking network connectivity..."

if ! ping -c 1 8.8.8.8 &> /dev/null; then
    error_exit "No internet connection detected. Please connect to internet and try again."
fi

log_success "Network connectivity confirmed"

################################################################################
# Step 3: Disable IPv6 (Critical for package downloads)
################################################################################
log_info "Configuring IPv6 settings..."

# Debian 13 (Trixie) no longer ships /etc/sysctl.conf; use a drop-in file.
IPV6_CONF=/etc/sysctl.d/99-disable-ipv6.conf
if [ -f "$IPV6_CONF" ]; then
    log_info "IPv6 already disabled ($IPV6_CONF)"
else
    log_info "Disabling IPv6 to prevent download issues..."

    sudo tee "$IPV6_CONF" > /dev/null <<'EOF'
# Disable IPv6 for Plasma Mobile installation
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF

    # Apply changes
    sudo sysctl --system > /dev/null

    log_success "IPv6 disabled successfully"
fi

################################################################################
# Step 4: System Update
################################################################################
log_info "Updating system packages (this may take 5-10 minutes)..."

# Update package lists
sudo apt-get update -y || error_exit "Failed to update package lists"

# Upgrade existing packages
log_info "Upgrading system packages..."
sudo apt-get -o Acquire::ForceIPv4=true full-upgrade -y || error_exit "Failed to upgrade packages"

log_success "System updated successfully"

################################################################################
# Step 5: Install Plasma Mobile Packages
################################################################################
log_info "Installing Plasma Mobile (this may take 15-25 minutes)..."
log_warning "You may see warnings about 'delayed items' - this is normal!"

# Define packages to install
PLASMA_PACKAGES=(
    plasma-mobile
    plasma-mobile-tweaks
    plasma-settings
    plasma-phonebook
    plasma-dialer
    spacebar
    angelfish
    okular-mobile
    kscreen
)

# Install Plasma Mobile packages with IPv4 forcing
sudo apt-get -o Acquire::ForceIPv4=true install -y "${PLASMA_PACKAGES[@]}" || {
    log_error "Some packages failed to install. Retrying..."
    sudo apt-get -o Acquire::ForceIPv4=true install -y --fix-missing "${PLASMA_PACKAGES[@]}" || \
        error_exit "Failed to install Plasma Mobile packages"
}

log_success "Plasma Mobile packages installed"

################################################################################
# Step 6: Install SDDM Display Manager
################################################################################
log_info "Installing SDDM display manager..."

sudo apt-get -o Acquire::ForceIPv4=true install -y sddm || error_exit "Failed to install SDDM"

log_success "SDDM installed"

################################################################################
# Step 7: Configure System to Boot into Graphical Mode
################################################################################
log_info "Configuring graphical boot..."

# Only one service can own display-manager.service. Raspberry Pi OS images
# with a desktop ship LightDM, which makes a plain `enable sddm` fail.
for dm in lightdm gdm3 gdm lxdm; do
    sudo systemctl disable "$dm" 2>/dev/null || true
done
echo "/usr/sbin/sddm" | sudo tee /etc/X11/default-display-manager > /dev/null
sudo systemctl enable --force sddm || error_exit "Failed to enable SDDM"

# Set default target to graphical
sudo systemctl set-default graphical.target || error_exit "Failed to set graphical target"

log_success "Graphical boot configured"

################################################################################
# Step 8: Set Plasma Mobile Lock Screen as Default Login
################################################################################
log_info "Configuring Plasma Mobile lock screen as the login screen..."

# Make the Plasma Mobile lock screen the system-wide "login/welcome" screen.
# Effect: skip SDDM's plain desktop-style greeter; boot straight into the
# session and immediately show the phone-style lock screen instead. PIN/
# password is still required (security unchanged) - only the screen you
# authenticate on changes. Relogin=true means every logout goes straight
# back to the lock screen too, not the old greeter.
TARGET_USER="$(whoami)"

# Session= must match the installed .desktop file name exactly.
PLASMA_SESSION=$(ls /usr/share/wayland-sessions/ 2>/dev/null | grep -m 1 -i '^plasma-mobile.*\.desktop$' || true)
if [ -z "$PLASMA_SESSION" ]; then
    log_warning "No plasma-mobile session in /usr/share/wayland-sessions/; assuming plasma-mobile.desktop"
    PLASMA_SESSION="plasma-mobile.desktop"
fi
log_info "Autologin session: $PLASMA_SESSION"

sudo mkdir -p /etc/sddm.conf.d
sudo tee /etc/sddm.conf.d/autologin.conf > /dev/null <<EOF
[Autologin]
User=${TARGET_USER}
Session=${PLASMA_SESSION}
Relogin=true
EOF

# Lock the session ~2s after every login/boot, so the mobile lock screen
# (org.kde.plasma.mobileshell LockScreen.qml) is what the user actually
# sees and unlocks, every time. The 2s delay is a cheap guard to let the
# compositor/lock daemon come up before the lock call fires.
mkdir -p "$HOME/.config/autostart"
cat > "$HOME/.config/autostart/lock-on-login.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Lock on login
Exec=/bin/sh -c "sleep 2 && loginctl lock-session"
X-KDE-autostart-phase=2
NoDisplay=true
EOF

log_success "Plasma Mobile lock screen configured as default login"

################################################################################
# Step 9: Add "Switch Session" Button to the Logout Screen
################################################################################
log_info "Installing Switch Session button..."

# Adds a "Switch Session" button to the phone's power/logout screen that
# reaches the real SDDM greeter (session/DE picker) instead of the phone
# lock screen. Builds on the autologin setup from Step 8.

# 9.1 One-shot helper: hides autologin.conf and forces sddm to reload it.
#    Two non-obvious facts, both confirmed live:
#    - SDDM still reads a file inside /etc/sddm.conf.d/ even if you just
#      rename its extension (e.g. .conf.disabled) -- it must be moved
#      fully OUT of that directory.
#    - SDDM's daemon process reads config ONCE at startup and caches it.
#      A plain logout/display cycle within the same long-running sddm
#      process reuses the cached config and autologins anyway. Only a
#      full `systemctl restart sddm` makes it re-read the file, so this
#      helper schedules that restart a few seconds out (detached, since
#      this whole process/session gets torn down by the logout that
#      follows immediately after it runs).
sudo tee /usr/local/bin/plasma-mobile-disable-autologin-once.sh > /dev/null <<'EOF'
#!/bin/sh
mkdir -p /root/sddm-conf-backup
if [ -f /etc/sddm.conf.d/autologin.conf ]; then
    mv /etc/sddm.conf.d/autologin.conf /root/sddm-conf-backup/autologin.conf
fi
systemd-run --on-active=6s --description="Restart sddm to pick up disabled autologin" /usr/bin/systemctl restart sddm
EOF
sudo chmod 755 /usr/local/bin/plasma-mobile-disable-autologin-once.sh

# 9.2 Root-side restore helper: puts autologin.conf back if the button moved
#    it aside. The existence check must run as root -- /root is mode 700, so
#    a [ -f /root/... ] test run as the session user is always false and the
#    restore silently never happens (confirmed live: autologin stayed off).
sudo tee /usr/local/bin/plasma-mobile-restore-autologin.sh > /dev/null <<'EOF'
#!/bin/sh
if [ -f /root/sddm-conf-backup/autologin.conf ]; then
    mkdir -p /etc/sddm.conf.d
    mv /root/sddm-conf-backup/autologin.conf /etc/sddm.conf.d/autologin.conf
fi
EOF
sudo chmod 755 /usr/local/bin/plasma-mobile-restore-autologin.sh

# 9.3 Both helpers are triggered from the GUI (no terminal to type a
#    password into), so they need passwordless sudo -- for these two
#    scripts only.
echo "${TARGET_USER} ALL=(root) NOPASSWD: /usr/local/bin/plasma-mobile-disable-autologin-once.sh, /usr/local/bin/plasma-mobile-restore-autologin.sh" | \
    sudo tee /etc/sudoers.d/plasma-mobile-switch-session > /dev/null
sudo chmod 0440 /etc/sudoers.d/plasma-mobile-switch-session
sudo visudo -c -f /etc/sudoers.d/plasma-mobile-switch-session || error_exit "Invalid sudoers rule for switch-session"

# 9.4 Restore autologin automatically once a session starts normally again
#    (replaces the lock-on-login.desktop from Step 8). Kept as a script file
#    rather than an inline Exec= line: Desktop Entry Exec= quoting silently
#    mangled the nested if/sudo/mv logic, so the restore never ran.
sudo tee /usr/local/bin/lock-and-restore-autologin.sh > /dev/null <<'EOF'
#!/bin/sh
# Runs on every plasma-mobile session start (via lock-on-login.desktop).
sleep 2
loginctl lock-session
sudo -n /usr/local/bin/plasma-mobile-restore-autologin.sh
EOF
sudo chmod 755 /usr/local/bin/lock-and-restore-autologin.sh

cat > "$HOME/.config/autostart/lock-on-login.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Lock on login
Exec=/usr/local/bin/lock-and-restore-autologin.sh
X-KDE-autostart-phase=2
NoDisplay=true
EOF

# 9.5 Replace the logout screen's "switch user" button. The stock button
#    calls sessionManagement.switchUser(), which spawns a SECOND full
#    Wayland session concurrently with the first -- two compositors
#    fighting over this Pi's single GPU is what froze the display. This
#    version does a normal sequential logout instead (never two sessions
#    alive at once), after disabling autologin so the logout actually
#    lands on the real greeter.
LOGOUT_QML="/usr/share/plasma/look-and-feel/org.kde.breeze.mobile/contents/logout/Logout.qml"
if [ ! -f "$LOGOUT_QML" ]; then
    error_exit "Logout.qml not found at $LOGOUT_QML - is plasma-mobile fully installed?"
fi

if [ ! -f "${LOGOUT_QML}.backup" ]; then
    sudo cp "$LOGOUT_QML" "${LOGOUT_QML}.backup"
fi

sudo tee "$LOGOUT_QML" > /dev/null <<'EOF'
/*
 *   SPDX-FileCopyrightText: 2014 Aleix Pol Gonzalez <aleixpol@blue-systems.com>
 *   SPDX-FileCopyrightText: 2020 Linus Jahn <lnj@kaidan.im>
 *   SPDX-FileCopyrightText: 2020 Marco Martin <mart@kde.org
 *   SPDX-FileCopyrightText: 2022 Seshan Ravikumar <seshan10@me.com>
 *   SPDX-FileCopyrightText: 2026 Philip McColl
 *
 *   Modified 2026 by Philip McColl for Little Rascal Smart Phone:
 *   the "switch user" button performs a sequential logout instead of
 *   calling sessionManagement.switchUser(), to avoid two concurrent
 *   Wayland sessions on the Raspberry Pi GPU.
 *
 *   SPDX-License-Identifier: GPL-2.0-or-later
 */

import QtQuick 2.12
import QtQuick.Layouts 1.12
import QtQuick.Controls 2.8 as Controls

import org.kde.kirigami 2.20 as Kirigami
import org.kde.coreaddons 1.0 as KCoreAddons

import org.kde.plasma.private.sessions 2.0
import org.kde.plasma.private.mobileshell.shellsettingsplugin as ShellSettings
import org.kde.plasma.plasma5support as Plasma5Support

Item {
    id: root

    Kirigami.Theme.colorSet: Kirigami.Theme.Complementary
    Kirigami.Theme.inherit: false
    signal logoutRequested()
    signal haltRequested()
    signal suspendRequested(int spdMethod)
    signal rebootRequested()
    signal rebootRequested2(int opt)
    signal cancelRequested()
    signal lockScreenRequested()

    Controls.Action {
        onTriggered: root.cancelRequested()
        shortcut: "Escape"
    }

    SessionManagement {
        id: sessionManagement
    }

    // Runs plasma-mobile-disable-autologin-once.sh (passwordless sudo) so the
    // next SDDM display shows the real greeter/session-picker instead of
    // autologin silently re-entering plasma-mobile. Only logs out once this
    // finishes, so there is never a second concurrent Wayland session fighting
    // the first one for the GPU (that dual-session race is what froze the
    // display when this button used to call sessionManagement.switchUser()).
    Plasma5Support.DataSource {
        id: disableAutologinSource
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            disconnectSource(sourceName);
            closeAnim.closeToBlack = true;
            closeAnim.execute(root.logoutRequested);
        }
        function run() {
            connectSource("sudo -n /usr/local/bin/plasma-mobile-disable-autologin-once.sh");
        }
    }

    Rectangle {
        id: blackOverlay
        anchors.fill: parent
        color: "black"
        opacity: 0
        z: opacity > 0 ? 1 : 0
    }

    Rectangle {
        id: background
        anchors.fill: parent
        color: Kirigami.Theme.backgroundColor
        opacity: 0
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            closeAnim.execute(root.cancelRequested);
        }
    }

    Component.onCompleted: openAnim.restart()
    onVisibleChanged: {
        if (visible) {
            openAnim.restart()
        }
    }

    ParallelAnimation {
        id: openAnim
        running: true
        OpacityAnimator {
            target: buttons
            from: 0
            to: 1
            duration: Kirigami.Units.longDuration
            easing.type: Easing.InOutQuad
        }
        OpacityAnimator {
            target: background
            from: 0
            to: 0.6
            duration: Kirigami.Units.longDuration
            easing.type: Easing.InOutQuad
        }
    }

    SequentialAnimation {
        id: closeAnim
        running: false

        property bool closeToBlack: false
        property var callback
        function execute(call) {
            callback = call;
            closeAnim.restart();
        }
        ParallelAnimation {
            OpacityAnimator {
                target: buttons
                from: 1
                to: 0
                duration: Kirigami.Units.longDuration
                easing.type: Easing.InOutQuad
            }
            OpacityAnimator {
                target: background
                from: 0.6
                to: 0
                duration: Kirigami.Units.longDuration
                easing.type: Easing.InOutQuad
            }
            OpacityAnimator {
                target: blackOverlay
                from: 0
                to: closeAnim.closeToBlack ? 1 : 0
                duration: Kirigami.Units.longDuration
                easing.type: Easing.InOutQuad
            }
        }
        ScriptAction {
            script: {
                if (closeAnim.callback) {
                    closeAnim.callback();
                }
                buttons.opacity = 1;
                background.opacity = 0.6;
            }
        }
    }

    Item {
        id: buttons
        anchors.fill: parent
        opacity: 0

        ColumnLayout {
            anchors.centerIn: parent
            spacing: Kirigami.Units.gridUnit

            ActionButton {
                iconSource: "system-reboot"
                text: i18nd("plasma_lookandfeel_org.kde.lookandfeel", "Restart")
                onClicked: {
                    closeAnim.closeToBlack = true;
                    closeAnim.execute(root.rebootRequested);
                }
            }

            ActionButton {
                iconSource: "system-shutdown"
                text: i18nd("plasma_lookandfeel_org.kde.lookandfeel", "Shut Down")
                onClicked: {
                    closeAnim.closeToBlack = true;
                    closeAnim.execute(root.haltRequested);
                }
            }

            ActionButton {
                iconSource: "system-log-out"
                text: i18nd("plasma_lookandfeel_org.kde.lookandfeel", "Log Out")
                visible: ShellSettings.Settings.allowLogout
                onClicked: {
                    closeAnim.closeToBlack = true;
                    closeAnim.execute(root.logoutRequested);
                }
            }

            ActionButton {
                iconSource: "system-switch-user"
                text: i18nd("plasma_lookandfeel_org.kde.lookandfeel", "Switch Session")
                visible: ShellSettings.Settings.allowLogout
                onClicked: {
                    disableAutologinSource.run();
                }
            }
        }

        ActionButton {
            anchors {
                bottom: parent.bottom
                bottomMargin: Kirigami.Units.gridUnit
                horizontalCenter: parent.horizontalCenter
            }
            iconSource: "dialog-cancel"
            text: i18nd("plasma_lookandfeel_org.kde.lookandfeel", "Cancel")
            onClicked: {
                closeAnim.closeToBlack = false;
                closeAnim.execute(root.cancelRequested);
            }
        }
    }
}
EOF

log_success "Switch Session button installed"

################################################################################
# Step 10: Optional Configurations
################################################################################
log_info "Applying optional configurations..."

# Increase GPU memory for better performance
if [ -f /boot/firmware/config.txt ]; then
    CONFIG_FILE="/boot/firmware/config.txt"
elif [ -f /boot/config.txt ]; then
    CONFIG_FILE="/boot/config.txt"
else
    log_warning "Could not find config.txt"
    CONFIG_FILE=""
fi

if [ -n "$CONFIG_FILE" ]; then
    if ! grep -q "gpu_mem" "$CONFIG_FILE"; then
        log_info "Setting GPU memory to 256MB..."
        sudo cp "$CONFIG_FILE" "${CONFIG_FILE}.backup"
        echo "" | sudo tee -a "$CONFIG_FILE" > /dev/null
        echo "# Plasma Mobile GPU configuration" | sudo tee -a "$CONFIG_FILE" > /dev/null
        echo "gpu_mem=256" | sudo tee -a "$CONFIG_FILE" > /dev/null
        log_success "GPU memory configured"
    fi
fi

################################################################################
# Step 11: Install the Camera App
################################################################################
log_info "Installing the Camera app (photos and video)..."

# plasma-camera has no apt candidate on Raspberry Pi OS, so the app below uses
# picamera2 and PyQt5. VLC plays the clips. A failure here shouldn't abort the
# whole install, since the camera is optional hardware.
CAMERA_PACKAGES=(
    python3-picamera2
    python3-pyqt5
    qtwayland5
    ffmpeg
    vlc
    rpicam-apps-lite
)

if ! sudo apt-get -o Acquire::ForceIPv4=true install -y "${CAMERA_PACKAGES[@]}"; then
    log_warning "Failed to install camera packages. The Camera app may not work."
fi

sudo usermod -aG video "$(whoami)"

if [ -n "$CONFIG_FILE" ] && ! grep -q "^camera_auto_detect=1" "$CONFIG_FILE"; then
    log_warning "camera_auto_detect=1 is not set in $CONFIG_FILE, so the camera may not be detected"
fi

sudo tee /usr/local/bin/little-rascal-camera > /dev/null <<'CAMERA_APP_EOF'
#!/usr/bin/python3
# SPDX-FileCopyrightText: 2026 Philip McColl
# SPDX-License-Identifier: GPL-3.0-or-later
"""Touch camera app for the Little Rascal phone (Pi camera via picamera2)."""

import os
import queue
import subprocess
import sys
from datetime import datetime

from PyQt5.QtCore import QElapsedTimer, QRectF, QSize, Qt, QThread, QTimer, pyqtSignal
from PyQt5.QtGui import QColor, QIcon, QImage, QImageReader, QPainter, QPixmap, QTransform
from PyQt5.QtWidgets import (
    QAbstractButton,
    QApplication,
    QHBoxLayout,
    QLabel,
    QToolButton,
    QVBoxLayout,
    QWidget,
)

PHOTO_DIR = os.path.expanduser("~/Pictures/Camera")
VIDEO_DIR = os.path.expanduser("~/Videos/Camera")
THUMB_CACHE = os.path.expanduser("~/.cache/little-rascal-camera/last-video.jpg")
PREVIEW_SIZE = (640, 480)
VIDEO_SIZE = (1280, 720)
VIDEO_FPS = 30
VIDEO_BITRATE = 8_000_000
THUMB_SIZE = 64
# Clockwise degrees to turn the landscape sensor image upright: 90 or 270.
# libcamera on the Pi can only flip, so this is done in software.
ROTATION = 270


class CameraThread(QThread):
    """Owns the camera: streams preview frames, takes stills, records video."""

    frame_ready = pyqtSignal(QImage)
    mode_ready = pyqtSignal(str)
    photo_saved = pyqtSignal(str)
    recording_started = pyqtSignal()
    video_saved = pyqtSignal(str)
    failed = pyqtSignal(str)

    def __init__(self):
        super().__init__()
        self._stopping = False
        self._commands = queue.Queue()
        self._recording = None

    def take_photo(self, path):
        self._commands.put(("photo", path))

    def set_mode(self, mode):
        self._commands.put(("mode", mode))

    def start_recording(self, path):
        self._commands.put(("start_recording", path))

    def stop_recording(self):
        self._commands.put(("stop_recording", None))

    def stop(self):
        self._stopping = True
        self.wait()

    def _start_recording(self, camera, path):
        from picamera2.encoders import H264Encoder
        from picamera2.outputs import PyavOutput

        os.makedirs(VIDEO_DIR, exist_ok=True)
        unrotated = path + ".part.mp4"
        camera.start_encoder(H264Encoder(bitrate=VIDEO_BITRATE), PyavOutput(unrotated))
        self._recording = path
        self.recording_started.emit()

    def _finish_recording(self, camera):
        path, self._recording = self._recording, None
        unrotated = path + ".part.mp4"
        camera.stop_encoder()
        # The hardware encoder can't rotate, so flag the rotation in the MP4
        # for players to apply. -display_rotation is counter-clockwise.
        subprocess.run(
            ["ffmpeg", "-y", "-loglevel", "error",
             "-display_rotation", str(360 - ROTATION), "-i", unrotated,
             "-c", "copy", path],
            check=True,
        )
        os.remove(unrotated)
        self.video_saved.emit(path)

    def run(self):
        # Imported here so the window appears right away; this import is slow.
        from picamera2 import Picamera2

        camera = None
        try:
            camera = Picamera2()
            configs = {
                "photo": camera.create_preview_configuration(
                    main={"size": PREVIEW_SIZE, "format": "RGB888"}
                ),
                "video": camera.create_video_configuration(
                    main={"size": VIDEO_SIZE, "format": "RGB888"},
                    # The binned full-sensor mode; the 1080p mode is a narrow crop.
                    raw={"size": (1296, 972)},
                    controls={"FrameDurationLimits": (1000000 // VIDEO_FPS,) * 2},
                ),
            }
            still = camera.create_still_configuration()
            mode = "photo"
            camera.configure(configs[mode])
            camera.start()
            self.mode_ready.emit(mode)
            while not self._stopping:
                try:
                    command, value = self._commands.get_nowait()
                except queue.Empty:
                    command = None
                if command == "photo":
                    photo = camera.switch_mode_and_capture_image(still)
                    # PIL rotates counter-clockwise.
                    photo.rotate(-ROTATION, expand=True).save(value, quality=95)
                    self.photo_saved.emit(value)
                    continue
                if command == "mode":
                    mode = value
                    camera.stop()
                    camera.configure(configs[mode])
                    camera.start()
                    self.mode_ready.emit(mode)
                    continue
                if command == "start_recording":
                    self._start_recording(camera, value)
                elif command == "stop_recording":
                    self._finish_recording(camera)
                frame = camera.capture_array("main")
                if mode == "video":
                    # Half size is plenty for the screen and keeps rotation cheap.
                    frame = frame[::2, ::2].copy()
                height, width, _ = frame.shape
                # libcamera's RGB888 is B, G, R in memory.
                image = QImage(
                    frame.data, width, height, frame.strides[0], QImage.Format_BGR888
                )
                # transformed() makes its own copy of the camera's buffer.
                self.frame_ready.emit(image.transformed(QTransform().rotate(ROTATION)))
        except Exception as error:
            self.failed.emit(str(error))
        finally:
            if camera is not None:
                if self._recording:
                    self._finish_recording(camera)
                camera.close()


class Viewfinder(QWidget):
    """Draws the latest frame scaled to fit, keeping its aspect ratio."""

    def __init__(self):
        super().__init__()
        self._image = None

    def show_frame(self, image):
        self._image = image
        self.update()

    def paintEvent(self, event):
        painter = QPainter(self)
        painter.fillRect(self.rect(), Qt.black)
        if self._image is None:
            return
        size = self._image.size().scaled(self.size(), Qt.KeepAspectRatio)
        target = QRectF(
            (self.width() - size.width()) / 2,
            (self.height() - size.height()) / 2,
            size.width(),
            size.height(),
        )
        painter.drawImage(target, self._image)


class ShutterButton(QAbstractButton):
    video_mode = False
    recording = False

    def sizeHint(self):
        return QSize(84, 84)

    def paintEvent(self, event):
        painter = QPainter(self)
        painter.setRenderHint(QPainter.Antialiasing)
        side = min(self.width(), self.height())
        outer = QRectF(
            (self.width() - side) / 2 + 3, (self.height() - side) / 2 + 3, side - 6, side - 6
        )
        painter.setPen(QColor("white"))
        pen = painter.pen()
        pen.setWidth(4)
        painter.setPen(pen)
        painter.drawEllipse(outer)
        if not self.isEnabled():
            fill = QColor("#666666")
        elif self.video_mode:
            fill = QColor("#a01818") if self.isDown() else QColor("#e02020")
        elif self.isDown():
            fill = QColor("#bbbbbb")
        else:
            fill = QColor("white")
        painter.setPen(Qt.NoPen)
        painter.setBrush(fill)
        if self.recording:
            painter.drawRoundedRect(outer.adjusted(22, 22, -22, -22), 4, 4)
        else:
            painter.drawEllipse(outer.adjusted(8, 8, -8, -8))


class CameraWindow(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Camera")
        self.setStyleSheet("background-color: black; color: white;")
        self._last_capture = None
        self._video_mode = False
        self._recording = False
        self._elapsed = QElapsedTimer()
        self._clock = QTimer(self)
        self._clock.setInterval(500)
        self._clock.timeout.connect(self.show_elapsed)

        self.viewfinder = Viewfinder()
        self.status = QLabel("Starting camera…")
        self.status.setAlignment(Qt.AlignCenter)
        self.status.setWordWrap(True)

        self.shutter = ShutterButton()
        self.shutter.setEnabled(False)
        self.shutter.setFixedSize(self.shutter.sizeHint())
        self.shutter.clicked.connect(self.on_shutter)

        self.thumbnail = QToolButton()
        self.thumbnail.setFixedSize(THUMB_SIZE, THUMB_SIZE)
        self.thumbnail.setIconSize(QSize(THUMB_SIZE - 4, THUMB_SIZE - 4))
        self.thumbnail.setStyleSheet("border: 1px solid #555555;")
        self.thumbnail.clicked.connect(self.open_last_capture)
        self.thumbnail.setEnabled(False)

        # Same width as the thumbnail, so the shutter stays centred.
        self.mode_button = QToolButton()
        self.mode_button.setText("Video")
        self.mode_button.setFixedSize(THUMB_SIZE, THUMB_SIZE)
        self.mode_button.setStyleSheet("border: 1px solid #555555;")
        self.mode_button.setEnabled(False)
        self.mode_button.clicked.connect(self.toggle_mode)

        controls = QHBoxLayout()
        controls.setContentsMargins(20, 8, 20, 16)
        controls.addWidget(self.thumbnail)
        controls.addStretch()
        controls.addWidget(self.shutter)
        controls.addStretch()
        controls.addWidget(self.mode_button)

        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)
        layout.addWidget(self.viewfinder, 1)
        layout.addWidget(self.status)
        layout.addLayout(controls)

        self.load_latest_capture()

        self.camera = CameraThread()
        self.camera.frame_ready.connect(self.viewfinder.show_frame)
        self.camera.mode_ready.connect(self.on_mode_ready)
        self.camera.recording_started.connect(self.on_recording_started)
        self.camera.video_saved.connect(self.on_video_saved)
        self.camera.photo_saved.connect(self.on_photo_saved)
        self.camera.failed.connect(self.on_failed)
        self.camera.start()

    def on_mode_ready(self, mode):
        self._video_mode = mode == "video"
        self.shutter.video_mode = self._video_mode
        self.mode_button.setText("Photo" if self._video_mode else "Video")
        self.mode_button.setEnabled(True)
        self.shutter.setEnabled(True)
        self.status.clear()

    def toggle_mode(self):
        self.shutter.setEnabled(False)
        self.mode_button.setEnabled(False)
        self.camera.set_mode("photo" if self._video_mode else "video")

    def on_shutter(self):
        if not self._video_mode:
            self.take_photo()
        elif self._recording:
            self.stop_recording()
        else:
            self.start_recording()

    def timestamp(self):
        return datetime.now().strftime("%Y%m%d_%H%M%S_%f")[:-3]

    def take_photo(self):
        os.makedirs(PHOTO_DIR, exist_ok=True)
        self.shutter.setEnabled(False)
        self.mode_button.setEnabled(False)
        self.status.setText("Saving…")
        self.camera.take_photo(os.path.join(PHOTO_DIR, f"IMG_{self.timestamp()}.jpg"))

    def on_photo_saved(self, path):
        self.shutter.setEnabled(True)
        self.mode_button.setEnabled(True)
        self.show_saved(path)

    def start_recording(self):
        self.shutter.setEnabled(False)
        self.mode_button.setEnabled(False)
        self.camera.start_recording(os.path.join(VIDEO_DIR, f"VID_{self.timestamp()}.mp4"))

    def on_recording_started(self):
        self._recording = True
        self.shutter.recording = True
        self.shutter.setEnabled(True)
        self._elapsed.start()
        self._clock.start()
        self.show_elapsed()

    def show_elapsed(self):
        seconds = self._elapsed.elapsed() // 1000
        self.status.setText(f"● {seconds // 60:02d}:{seconds % 60:02d}")

    def stop_recording(self):
        self._clock.stop()
        self.shutter.setEnabled(False)
        self.status.setText("Saving…")
        self.camera.stop_recording()

    def on_video_saved(self, path):
        self._recording = False
        self.shutter.recording = False
        self.shutter.setEnabled(True)
        self.mode_button.setEnabled(True)
        self.show_saved(path)

    def show_saved(self, path):
        self.status.setText("Saved " + os.path.basename(path))
        QTimer.singleShot(2500, self.clear_saved_message)
        self.set_last_capture(path)

    def clear_saved_message(self):
        if self.status.text().startswith("Saved "):
            self.status.clear()

    def on_failed(self, message):
        self._clock.stop()
        self.shutter.setEnabled(False)
        self.mode_button.setEnabled(False)
        self.status.setText("Camera error: " + message)

    def load_latest_capture(self):
        captures = []
        for folder, suffix in ((PHOTO_DIR, ".jpg"), (VIDEO_DIR, ".mp4")):
            if os.path.isdir(folder):
                captures += [
                    os.path.join(folder, name)
                    for name in os.listdir(folder)
                    if name.endswith(suffix) and not name.endswith(".part.mp4")
                ]
        if captures:
            self.set_last_capture(max(captures, key=os.path.getmtime))

    def set_last_capture(self, path):
        image_path = path
        if path.endswith(".mp4"):
            os.makedirs(os.path.dirname(THUMB_CACHE), exist_ok=True)
            subprocess.run(
                ["ffmpeg", "-y", "-loglevel", "error", "-i", path,
                 "-frames:v", "1", THUMB_CACHE]
            )
            image_path = THUMB_CACHE
        reader = QImageReader(image_path)
        reader.setAutoTransform(True)
        size = reader.size().scaled(THUMB_SIZE, THUMB_SIZE, Qt.KeepAspectRatio)
        reader.setScaledSize(size)
        self.thumbnail.setIcon(QIcon(QPixmap.fromImage(reader.read())))
        self.thumbnail.setEnabled(True)
        self._last_capture = path

    def open_last_capture(self):
        if self._last_capture:
            subprocess.Popen(["xdg-open", self._last_capture])

    def closeEvent(self, event):
        # Release the camera, otherwise the next launch finds it busy.
        self.camera.stop()
        super().closeEvent(event)


def main():
    app = QApplication(sys.argv)
    app.setApplicationName("Camera")
    app.setDesktopFileName("org.littlerascal.camera")
    app.setWindowIcon(QIcon.fromTheme("camera-photo"))
    window = CameraWindow()
    window.showMaximized()
    sys.exit(app.exec_())


if __name__ == "__main__":
    main()
CAMERA_APP_EOF
sudo chmod 755 /usr/local/bin/little-rascal-camera

sudo mkdir -p /usr/local/share/applications
sudo tee /usr/local/share/applications/org.littlerascal.camera.desktop > /dev/null <<'EOF'
# SPDX-FileCopyrightText: 2026 Philip McColl
# SPDX-License-Identifier: GPL-3.0-or-later
[Desktop Entry]
Type=Application
Name=Camera
Comment=Take photos and videos with the Raspberry Pi camera
Exec=/usr/local/bin/little-rascal-camera
Icon=camera-photo
Terminal=false
Categories=Graphics;Photography;
X-KDE-FormFactor=handset;tablet;desktop;
EOF

# Confirmed live: VLC segfaults about 3s after opening any file in the Plasma
# session, because the Breeze style calls KX11Extras::compositingActive with no
# usable xcb connection. /usr/local/share comes first in the default
# XDG_DATA_DIRS, so this copy overrides the system entry.
if [ -f /usr/share/applications/vlc.desktop ]; then
    sed 's#^Exec=/usr/bin/vlc#Exec=env QT_STYLE_OVERRIDE=Fusion /usr/bin/vlc#' \
        /usr/share/applications/vlc.desktop | \
        sudo tee /usr/local/share/applications/vlc.desktop > /dev/null
fi

log_success "Camera app installed"

################################################################################
# Step 12: Set Up the Cellular Modem (Waveshare SIM7600G-H 4G HAT)
################################################################################
log_info "Installing cellular modem support..."

# The modem itself needs only stock drivers and ModemManager. Calls and SMS use
# plasma-dialer and spacebar from Step 5. Optional hardware, so never fatal.
MODEM_PACKAGES=(
    modemmanager
    network-manager
    libqmi-utils
    mobile-broadband-provider-info
)

if ! sudo apt-get -o Acquire::ForceIPv4=true install -y "${MODEM_PACKAGES[@]}"; then
    log_warning "Failed to install modem packages. Mobile data may not work."
fi

sudo systemctl enable --now ModemManager || log_warning "Could not enable ModemManager"

# Kept as a script file so it can also be run later, when the HAT or a new SIM
# is fitted after the install.
sudo tee /usr/local/bin/little-rascal-mobile-data > /dev/null <<'MOBILE_DATA_EOF'
#!/bin/bash
# SPDX-FileCopyrightText: 2026 Philip McColl
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Creates the NetworkManager connection for the cellular modem. Reads the SIM's
# operator from the modem and looks up its APN in mobile-broadband-provider-info.
#
# Usage: sudo little-rascal-mobile-data [APN]
#        little-rascal-mobile-data --dry-run [APN]

set -e

CONNECTION="Mobile Data"
DRY_RUN=0
if [ "$1" = "--dry-run" ]; then
    DRY_RUN=1
    shift
fi
APN="$1"

if [ "$DRY_RUN" -eq 0 ] && [ "$EUID" -ne 0 ]; then
    echo "Please run with sudo." >&2
    exit 1
fi

# The modem's index can change when it re-enumerates, so don't assume 0.
MODEM=$(mmcli -L 2>/dev/null | grep -oE 'Modem/[0-9]+' | head -1 | cut -d/ -f2)
if [ -z "$MODEM" ]; then
    echo "No modem found. Check the HAT's USB link and power, then try again." >&2
    exit 1
fi

if [ "$DRY_RUN" -eq 0 ] && nmcli -t -f TYPE connection show | grep -qx gsm; then
    echo "A mobile connection already exists:"
    nmcli -t -f NAME,TYPE connection show | grep ':gsm$'
    exit 0
fi

OPERATOR=$(mmcli -m "$MODEM" -K | awk -F': *' '/modem\.3gpp\.operator-code/ {print $2}')

LOOKUP=$(python3 -I - "$OPERATOR" <<'PY'
import sys
import xml.etree.ElementTree as ET

try:
    root = ET.parse("/usr/share/mobile-broadband-provider-info/serviceproviders.xml").getroot()
except (OSError, ET.ParseError):
    sys.exit(0)
for gsm in root.iter("gsm"):
    ids = [n.get("mcc", "") + n.get("mnc", "") for n in gsm.findall("network-id")]
    if sys.argv[1] not in ids:
        continue
    for apn in gsm.findall("apn"):
        if any(u.get("type") == "internet" for u in apn.findall("usage")):
            print("|".join([apn.get("value"), apn.findtext("username") or "", apn.findtext("password") or ""]))
            sys.exit(0)
PY
)
IFS='|' read -r FOUND_APN FOUND_USER FOUND_PASS <<< "$LOOKUP"

echo "Operator: ${OPERATOR:-unknown}, suggested APN: ${FOUND_APN:-none}"

if [ -z "$APN" ] && [ "$DRY_RUN" -eq 0 ]; then
    read -r -p "APN to use [${FOUND_APN}] (Ctrl+C to cancel): " APN < /dev/tty
fi
APN="${APN:-$FOUND_APN}"
if [ -z "$APN" ]; then
    echo "No APN known for this SIM. Ask your carrier, then run this again with it:" >&2
    echo "  sudo little-rascal-mobile-data <APN>" >&2
    exit 1
fi

# Metric 700 keeps Wi-Fi (metric 600) as the preferred route when it's available.
ARGS=(connection add type gsm ifname "*" con-name "$CONNECTION" apn "$APN"
      connection.autoconnect yes ipv4.route-metric 700 ipv6.method disabled)
# The database's credentials only belong to the APN it suggested.
[ "$APN" = "$FOUND_APN" ] || FOUND_USER=""
if [ -n "$FOUND_USER" ]; then
    ARGS+=(gsm.username "$FOUND_USER" gsm.password "$FOUND_PASS")
fi

if [ "$DRY_RUN" -eq 1 ]; then
    echo "Would run: nmcli connection add type gsm ifname \"*\" con-name \"$CONNECTION\" apn $APN (username: ${FOUND_USER:-none})"
    exit 0
fi

nmcli "${ARGS[@]}"
nmcli connection up "$CONNECTION"
MOBILE_DATA_EOF
sudo chmod 755 /usr/local/bin/little-rascal-mobile-data

if mmcli -L 2>/dev/null | grep -q 'Modem/'; then
    log_info "Modem detected, setting up mobile data..."
    if sudo little-rascal-mobile-data; then
        log_success "Mobile data configured"
    else
        log_warning "Mobile data not configured. Try later with: sudo little-rascal-mobile-data"
    fi
else
    log_info "No modem detected. After fitting the HAT and SIM, run: sudo little-rascal-mobile-data"
fi

log_success "Cellular modem support installed"

################################################################################
# Step 13: Verification
################################################################################
log_info "Verifying installation..."

# Check if plasma-mobile package is installed
if dpkg -l | grep -q "plasma-mobile"; then
    log_success "Plasma Mobile package verified"
else
    error_exit "Plasma Mobile package not found"
fi

# Check if SDDM is installed
if command -v sddm &> /dev/null; then
    log_success "SDDM verified"
else
    error_exit "SDDM not found"
fi

# Check that SDDM (not LightDM) owns the display manager slot
DM_TARGET="$(readlink -f /etc/systemd/system/display-manager.service)"
if [[ "$DM_TARGET" == */sddm.service ]]; then
    log_success "SDDM is the active display manager"
else
    error_exit "display-manager.service points to ${DM_TARGET:-nothing}, not SDDM"
fi

# Check if graphical target is set
if systemctl get-default | grep -q "graphical.target"; then
    log_success "Graphical target verified"
else
    error_exit "Graphical target not set correctly"
fi

# Check if lock-screen-as-login is configured
if [ -f /etc/sddm.conf.d/autologin.conf ]; then
    log_success "Plasma Mobile lock screen login verified"
else
    log_warning "Lock screen login config not found (non-fatal)"
fi

# Check if the Switch Session button was installed
if [ -f /usr/local/bin/plasma-mobile-disable-autologin-once.sh ] && \
   [ -f /usr/local/bin/plasma-mobile-restore-autologin.sh ] && \
   grep -q "Switch Session" "$LOGOUT_QML" 2>/dev/null; then
    log_success "Switch Session button verified"
else
    log_warning "Switch Session button not found (non-fatal)"
fi

# Check the Camera app and what it needs to run
if [ -x /usr/local/bin/little-rascal-camera ] && \
   [ -f /usr/local/share/applications/org.littlerascal.camera.desktop ] && \
   python3 -c "import picamera2, PyQt5.QtWidgets" 2>/dev/null; then
    log_success "Camera app verified"
else
    log_warning "Camera app or its libraries not found (non-fatal)"
fi

# Check that the VLC crash workaround is in place
if grep -q "QT_STYLE_OVERRIDE=Fusion" /usr/local/share/applications/vlc.desktop 2>/dev/null; then
    log_success "VLC launcher verified"
else
    log_warning "VLC launcher override not found, so videos may not open (non-fatal)"
fi

# Check modem support. A modem and a SIM are optional, so only report them.
if [ -x /usr/local/bin/little-rascal-mobile-data ] && systemctl is-enabled ModemManager &> /dev/null; then
    log_success "Cellular modem support verified"
else
    log_warning "Cellular modem support not found (non-fatal)"
fi

################################################################################
# Step 14: Installation Complete
################################################################################
echo ""
echo "################################################################################"
echo "#                                                                              #"
echo "#                    INSTALLATION COMPLETED SUCCESSFULLY!                      #"
echo "#                                                                              #"
echo "################################################################################"
echo ""
log_success "Plasma Mobile has been installed successfully!"
echo ""
log_info "Next steps:"
echo "  1. Reboot your Raspberry Pi: sudo reboot"
echo "  2. After reboot, you will boot straight into the Plasma Mobile lock screen"
echo "  3. Unlock with your username and password"
echo "  4. Use power menu → 'Switch Session' to reach the SDDM greeter/session picker"
echo "  5. Open the Camera app to take photos and videos"
echo "  6. Using the SIM7600G-H HAT? Fit the SIM and antennas with everything off, then see Step 8 of the guide"
echo "  7. Enjoy your mobile Linux experience!"
echo ""
log_info "Optional configurations:"
echo "  - Rotate display: in Plasma run 'kscreen-doctor -o', then e.g. 'kscreen-doctor output.HDMI-A-1.rotation.right'"
echo "  - Install more apps: sudo apt search <app-name>"
echo "  - Configure keyboard: Settings → Input Devices → Keyboard"
echo "  - Undo lock-screen-as-login: sudo rm /etc/sddm.conf.d/autologin.conf ~/.config/autostart/lock-on-login.desktop"
echo "  - Undo Switch Session button: sudo cp ${LOGOUT_QML}.backup ${LOGOUT_QML}; sudo rm /usr/local/bin/plasma-mobile-disable-autologin-once.sh /usr/local/bin/plasma-mobile-restore-autologin.sh /usr/local/bin/lock-and-restore-autologin.sh /etc/sudoers.d/plasma-mobile-switch-session"
echo "  - Undo Camera app: sudo rm /usr/local/bin/little-rascal-camera /usr/local/share/applications/org.littlerascal.camera.desktop /usr/local/share/applications/vlc.desktop"
echo "  - Undo mobile data: sudo nmcli connection delete \"Mobile Data\"; sudo rm /usr/local/bin/little-rascal-mobile-data"
echo ""
log_info "Troubleshooting:"
echo "  - If screen is black: sudo systemctl restart sddm"
echo "  - Check logs: journalctl -xe"
echo "  - SSH access: ssh $(whoami)@$(hostname -I | awk '{print $1}')"
echo ""

# Ask if user wants to reboot now
read -p "Do you want to reboot now? (y/n) " -n 1 -r < /dev/tty
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log_info "Rebooting in 5 seconds... Press Ctrl+C to cancel"
    sleep 5
    sudo reboot
else
    log_info "Please remember to reboot manually: sudo reboot"
fi

exit 0
