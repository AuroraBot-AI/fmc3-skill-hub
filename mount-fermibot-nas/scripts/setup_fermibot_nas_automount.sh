#!/usr/bin/env bash
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
    echo "Please run with sudo: sudo bash $0" >&2
    exit 1
fi

REAL_USER="${SUDO_USER:-${REAL_USER:-phl}}"
REAL_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"
REAL_UID="$(id -u "$REAL_USER")"
REAL_GID="$(id -g "$REAL_USER")"

NAS_HOST="${NAS_HOST:-192.168.1.123}"
SHARE_NAME="${SHARE_NAME:-FermiBot}"
NAS_USER="${NAS_USER:-fermi_team}"
MOUNT_POINT="${MOUNT_POINT:-$REAL_HOME/FermiBotNas}"
CRED_DIR="/etc/samba/credentials"
CRED_FILE="$CRED_DIR/fermibot"
SHARE="//$NAS_HOST/$SHARE_NAME"

if [[ -z "${NAS_PASS:-}" ]]; then
    read -r -s -p "NAS password for $NAS_USER: " NAS_PASS
    echo
fi
[[ -n "$NAS_PASS" ]] || { echo "NAS password is empty" >&2; exit 1; }

command -v mount.cifs >/dev/null 2>&1 || {
    echo "mount.cifs not found. Install cifs-utils first." >&2
    exit 1
}

ts="$(date +%Y%m%d-%H%M%S)"
fstab_backup="/etc/fstab.bak-fmc3-nas-$ts"
cp -a /etc/fstab "$fstab_backup"

install -d -m 700 -o root -g root "$CRED_DIR"
tmp_cred="$(mktemp)"
printf 'username=%s\npassword=%s\n' "$NAS_USER" "$NAS_PASS" > "$tmp_cred"
install -m 600 -o root -g root "$tmp_cred" "$CRED_FILE"
rm -f "$tmp_cred"

mkdir -p "$MOUNT_POINT"
chown "$REAL_UID:$REAL_GID" "$MOUNT_POINT"

entry="${SHARE} ${MOUNT_POINT} cifs credentials=${CRED_FILE},uid=${REAL_UID},gid=${REAL_GID},file_mode=0755,dir_mode=0755,iocharset=utf8,vers=3.1.1,cache=strict,actimeo=30,noserverino,hard,_netdev,nofail,noauto,x-systemd.automount,x-systemd.idle-timeout=600,x-systemd.requires=network-online.target,x-systemd.after=network-online.target,x-systemd.device-timeout=10s,x-systemd.mount-timeout=30s 0 0"

tmp_fstab="$(mktemp)"
awk -v share="$SHARE" -v mp="$MOUNT_POINT" '
    $0 == "# FermiBot NAS stable CIFS systemd automount" {next}
    ($1 == share || $2 == mp) {next}
    {print}
' /etc/fstab > "$tmp_fstab"
printf '\n# FermiBot NAS stable CIFS systemd automount\n%s\n' "$entry" >> "$tmp_fstab"
install -m 644 -o root -g root "$tmp_fstab" /etc/fstab
rm -f "$tmp_fstab"

systemctl enable NetworkManager-wait-online.service >/dev/null 2>&1 || true
systemctl reset-failed NetworkManager-wait-online.service >/dev/null 2>&1 || true

if mountpoint -q "$MOUNT_POINT"; then
    umount "$MOUNT_POINT" || umount -l "$MOUNT_POINT"
fi

systemctl daemon-reload
unit="$(systemd-escape -p --suffix=automount "$MOUNT_POINT")"
systemctl restart "$unit"

echo "fstab backup: $fstab_backup"
echo "credentials:  $CRED_FILE"
echo "automount:    $unit"
echo "mount point:  $MOUNT_POINT"

ls "$MOUNT_POINT" >/dev/null
findmnt "$MOUNT_POINT"
