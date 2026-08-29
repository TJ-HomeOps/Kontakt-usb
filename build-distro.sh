#!/bin/bash
# ==============================================================================
# build-distro.sh
#
# Builds a minimal Debian (bookworm) + XFCE live ISO with:
#   - Firefox ESR (for Outlook Web App as an installed "app")
#   - Thunderbird (native client, configurable against Office 365 / Exchange)
#   - KontaktApp (local case-logging tool) pre-installed and on the desktop
#
# RUN THIS ON A DEBIAN OR UBUNTU MACHINE (not inside this chat sandbox).
# It needs sudo and ~10-20GB of free disk space to build.
#
# Usage:
#   sudo ./build-distro.sh
#
# Output:
#   ./build/live-image-amd64.hybrid.iso
# ==============================================================================
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Please run as root (sudo ./build-distro.sh)"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build"

echo "==> Installing live-build tooling..."
apt-get update
apt-get install -y live-build live-config live-boot debootstrap debian-archive-keyring gnupg curl

echo "==> Fetching current Debian bookworm signing keys..."
# The debian-archive-keyring package on an Ubuntu build host is Ubuntu's own
# (stale) build of it and is missing the current bookworm key, which makes
# debootstrap reject the Release file signature. Pull the real keys straight
# from ftp-master.debian.org and use them instead.
curl -fsSL https://ftp-master.debian.org/keys/archive-key-12.asc -o /tmp/archive-key-12.asc
curl -fsSL https://ftp-master.debian.org/keys/archive-key-12-security.asc -o /tmp/archive-key-12-security.asc
cat /tmp/archive-key-12.asc /tmp/archive-key-12-security.asc | gpg --dearmor > /usr/share/keyrings/debian-archive-keyring.gpg

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

echo "==> Configuring live-build (Debian bookworm, XFCE, persistence-ready)..."
# Explicit Debian mirrors: needed because the build host (e.g. a GitHub
# Actions Ubuntu runner) may otherwise leak its own Ubuntu mirror settings
# into the config, which fails since we're building Debian, not Ubuntu.
# (Kept as one single line on purpose - multi-line backslash continuations
# are fragile when this file gets edited through GitHub's web editor.)
lb config --distribution bookworm --archive-areas "main contrib non-free non-free-firmware" --architecture amd64 --debian-installer live --binary-images iso-hybrid --iso-application "KontaktUSB" --iso-volume "KONTAKTUSB" --mirror-bootstrap http://deb.debian.org/debian/ --mirror-chroot http://deb.debian.org/debian/ --mirror-chroot-security http://security.debian.org/debian-security/ --mirror-binary http://deb.debian.org/debian/ --mirror-binary-security http://security.debian.org/debian-security/ --keyring-packages debian-archive-keyring --linux-packages "linux-image" --linux-flavours "amd64" --initramfs live-boot

mkdir -p config/package-lists
cat > config/package-lists/desktop.list.chroot <<'EOF'
task-xfce-desktop
xfce4-terminal
firmware-iwlwifi
firmware-misc-nonfree
firmware-linux
firmware-linux-nonfree
firefox-esr
thunderbird
network-manager-gnome
python3
python3-flask
python3-pip
curl
file-roller
gnome-disk-utility
EOF

echo "==> Embedding KontaktApp and Outlook setup helpers into the image..."
mkdir -p config/includes.chroot/opt/kontaktapp
mkdir -p config/includes.chroot/etc/skel/.config/autostart
mkdir -p config/includes.chroot/etc/skel/Desktop
mkdir -p config/includes.chroot/opt/outlook-setup

cp -r "${SCRIPT_DIR}/case-app/"* config/includes.chroot/opt/kontaktapp/
chmod +x config/includes.chroot/opt/kontaktapp/run-kontaktapp.sh

cp "${SCRIPT_DIR}/case-app/kontaktapp.desktop" config/includes.chroot/etc/skel/.config/autostart/kontaktapp.desktop
cp "${SCRIPT_DIR}/case-app/kontaktapp.desktop" config/includes.chroot/etc/skel/Desktop/kontaktapp.desktop

cp -r "${SCRIPT_DIR}/outlook-setup/"* config/includes.chroot/opt/outlook-setup/

# Desktop launcher for Outlook Web App (installed properly as a Firefox
# "Web App" the first time the user runs install-owa-pwa.sh, see README).
cat > config/includes.chroot/etc/skel/Desktop/outlook-setup.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Outlook installere (kør en gang)
Comment=Installerer Outlook Web App og Thunderbird-genvej
Exec=x-terminal-emulator -e /opt/outlook-setup/install-owa-pwa.sh
Icon=mail-client
Terminal=false
Categories=Office;
EOF

chmod +x config/includes.chroot/etc/skel/Desktop/*.desktop || true
chmod +x config/includes.chroot/opt/outlook-setup/*.sh || true

# pip install flask as a fallback too, in case the .deb is unavailable
mkdir -p config/hooks/live
cat > config/hooks/live/0010-pip-flask.hook.chroot <<'EOF'
#!/bin/sh
pip3 install --break-system-packages flask || true
EOF
chmod +x config/hooks/live/0010-pip-flask.hook.chroot

echo "==> Building the image (this will take a while)..."
lb build

echo ""
echo "=============================================================="
echo " Build complete."
echo " ISO: ${BUILD_DIR}/live-image-amd64.hybrid.iso"
echo ""
echo " Next steps:"
echo "   1. Write it to the 128GB USB drive (see README.md, section"
echo "      'Writing to USB + enabling full persistence')."
echo "   2. Boot from the USB and choose 'Live (persistence)' at the"
echo "      boot menu, or type 'persistence' at the boot prompt."
echo "=============================================================="
