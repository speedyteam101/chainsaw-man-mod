#!/usr/bin/env bash
# Turns a Debian 12 (bookworm) or 13 (trixie) system into BlockOS.
#
#   sudo ./install.sh                 # set up BlockOS for the user who ran sudo
#   sudo ./install.sh --user alex     # ...or for a specific user
#
# Options:
#   --user NAME       the account that logs in to BlockOS automatically
#   --no-autologin    keep the login screen (choose the "BlockOS" session there)
#   --chroot          building an image (used by the ISO build): skip steps that
#                     need a running system and don't require the user to exist yet
set -euo pipefail

BLOCKOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_USER=""
AUTOLOGIN=1
CHROOT=0

while [ $# -gt 0 ]; do
  case "$1" in
    --user) TARGET_USER="${2:?--user needs a name}"; shift 2 ;;
    --no-autologin) AUTOLOGIN=0; shift ;;
    --chroot) CHROOT=1; shift ;;
    -h|--help) sed -n '2,13p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1 (try --help)" >&2; exit 1 ;;
  esac
done

say() { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "run this as root, e.g. sudo $0"
[ -r /etc/debian_version ] || die "this doesn't look like Debian (/etc/debian_version is missing)"
[ -f "$BLOCKOS_DIR/shell/index.html" ] || die "can't find the BlockOS shell next to this script ($BLOCKOS_DIR/shell)"

# Work out who gets auto-logged in.
if [ "$AUTOLOGIN" -eq 1 ] && [ -z "$TARGET_USER" ]; then
  if [ -n "${SUDO_USER:-}" ] && [ "${SUDO_USER}" != root ]; then
    TARGET_USER="$SUDO_USER"
  else
    # Exactly one normal account (UID 1000-59999)? Use it.
    mapfile -t humans < <(awk -F: '$3 >= 1000 && $3 < 60000 { print $1 }' /etc/passwd)
    if [ "${#humans[@]}" -eq 1 ]; then
      TARGET_USER="${humans[0]}"
    else
      die "couldn't tell which user should log in to BlockOS; pass --user NAME (or --no-autologin)"
    fi
  fi
fi
if [ -n "$TARGET_USER" ] && [ "$CHROOT" -eq 0 ]; then
  id "$TARGET_USER" >/dev/null 2>&1 || die "user '$TARGET_USER' doesn't exist"
fi

# ------------------------------------------------------------------ packages

PACKAGES=(
  # graphics, window manager, login manager
  xserver-xorg xinit x11-xserver-utils openbox lightdm lightdm-gtk-greeter
  # the desktop itself runs in Chromium and is served by a small Python server
  chromium python3
  # apps you can open from BlockOS
  xfce4-terminal pcmanfm mousepad
  # sessions, power buttons, sound, fonts
  dbus-user-session polkitd pipewire-audio fonts-noto-core fonts-dejavu-core xdg-utils
)
# Nice to have; skipped quietly if a Debian release doesn't have them.
OPTIONAL=(xfce4-taskmanager galculator spice-vdagent qemu-guest-agent)

export DEBIAN_FRONTEND=noninteractive
# If another login manager (e.g. GNOME's gdm3) is installed, LightDM still takes over.
echo "lightdm shared/default-x-display-manager select lightdm" | debconf-set-selections
say "Updating package lists"
apt-get update

say "Installing BlockOS packages (this can take a while)"
apt-get install -y --no-install-recommends "${PACKAGES[@]}"
for pkg in "${OPTIONAL[@]}"; do
  apt-get install -y --no-install-recommends "$pkg" || warn "skipped optional package $pkg"
done

# ------------------------------------------------------------------ files

say "Copying the BlockOS desktop to /opt/blockos"
rm -rf /opt/blockos/shell
install -d /opt/blockos /etc/blockos
cp -r "$BLOCKOS_DIR/shell" /opt/blockos/shell
find /opt/blockos/shell -type d -exec chmod 755 {} +
find /opt/blockos/shell -type f -exec chmod 644 {} +
install -m 755 "$BLOCKOS_DIR/system/blockos-session" /usr/local/bin/blockos-session
install -D -m 644 "$BLOCKOS_DIR/system/blockos.desktop" /usr/share/xsessions/blockos.desktop
[ -f /etc/blockos/browser-flags ] || : > /etc/blockos/browser-flags

# ------------------------------------------------------------------ login

install -d /etc/X11
echo /usr/sbin/lightdm > /etc/X11/default-display-manager

say "Configuring LightDM"
install -d /etc/lightdm/lightdm.conf.d
{
  echo "[Seat:*]"
  echo "user-session=blockos"
  if [ "$AUTOLOGIN" -eq 1 ]; then
    echo "autologin-user=$TARGET_USER"
    echo "autologin-user-timeout=0"
    echo "autologin-session=blockos"
  fi
} > /etc/lightdm/lightdm.conf.d/50-blockos.conf

if [ "$AUTOLOGIN" -eq 1 ]; then
  # Some LightDM setups only auto-login members of the "autologin" group.
  getent group autologin >/dev/null || groupadd -r autologin
  if id "$TARGET_USER" >/dev/null 2>&1; then
    usermod -aG autologin "$TARGET_USER"
  fi
fi

# ------------------------------------------------------------------ branding

say "Adding BlockOS branding"
cat > /etc/issue <<'ISSUE'
BlockOS (built on Debian) \n \l

ISSUE
install -d /usr/share/blockos
install -m 644 "$BLOCKOS_DIR/system/grub-background.png" /usr/share/blockos/grub-background.png
install -d /etc/default/grub.d
cat > /etc/default/grub.d/50-blockos.cfg <<'GRUB'
GRUB_DISTRIBUTOR="BlockOS"
GRUB_TIMEOUT=3
GRUB_BACKGROUND="/usr/share/blockos/grub-background.png"
GRUB_GFXMODE=1280x800,auto
GRUB_CMDLINE_LINUX_DEFAULT="quiet"
GRUB
if [ "$CHROOT" -eq 0 ] && command -v update-grub >/dev/null 2>&1; then
  update-grub || warn "update-grub failed; the boot menu keeps its old look"
fi

# ------------------------------------------------------------------ services

if command -v systemctl >/dev/null 2>&1; then
  systemctl set-default graphical.target || warn "couldn't set the graphical target"
  systemctl enable --force lightdm || warn "couldn't enable lightdm"
fi

say "BlockOS is installed."
if [ "$CHROOT" -eq 0 ]; then
  echo "Restart to start playing:  sudo reboot"
fi
