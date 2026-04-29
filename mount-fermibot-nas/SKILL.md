---
name: mount-fermibot-nas
description: Use when configuring, repairing, or verifying stable FermiBot NAS access on fmc3 Ubuntu workstations, especially when users mention NAS mount dropping, FermiBotNas, CIFS/SMB, systemd automount, fstab, or sharing fmc3 team files.
---

# Mount FermiBot NAS

## Overview

Configure the FermiBot NAS as a system-level CIFS mount with systemd automount. This is more stable than desktop GVFS paths like `/run/user/.../gvfs/smb-share:*` and survives reboot/network reconnects.

Use the bundled `scripts/setup_fermibot_nas_automount.sh` script unless the repository has a newer copy.

## Defaults

- NAS host: `192.168.1.123`
- Share: `FermiBot`
- NAS user: `fermi_team`
- Mount point: `$HOME/FermiBotNas`
- Credentials file: `/etc/samba/credentials/fermibot`
- fstab backup pattern: `/etc/fstab.bak-fmc3-nas-YYYYmmdd-HHMMSS`

## Run

From the skill directory:

```bash
sudo bash scripts/setup_fermibot_nas_automount.sh
```

The first password prompt is the workstation user's sudo password. The script's `NAS password for fermi_team:` prompt is the NAS account password, not the workstation password.

For a non-interactive run, pass the NAS password through `NAS_PASS`; avoid this when shell history matters. Never commit real NAS passwords to the skill hub:

```bash
sudo NAS_PASS='<nas-password>' bash scripts/setup_fermibot_nas_automount.sh
```

Override defaults only when needed:

```bash
sudo NAS_HOST=192.168.1.123 SHARE_NAME=FermiBot NAS_USER=fermi_team \
  MOUNT_POINT=/home/phl/FermiBotNas \
  bash scripts/setup_fermibot_nas_automount.sh
```

## Verify

Run all checks after configuration:

```bash
findmnt /home/phl/FermiBotNas
systemctl status home-phl-FermiBotNas.automount --no-pager
systemctl status home-phl-FermiBotNas.mount --no-pager
ls /home/phl/FermiBotNas
```

Expected `findmnt` output has both layers:

- `systemd-1 autofs`
- `//192.168.1.123/FermiBot cifs`

Test write access:

```bash
test_file="/home/phl/FermiBotNas/.mount_test_$$"
printf 'ok\n' > "$test_file" && cat "$test_file" && rm -f "$test_file"
```

## Troubleshooting

- `mount error(13): Permission denied`: NAS credentials are wrong. Re-run the script and enter the NAS password for `fermi_team`.
- `mount.cifs not found`: install `cifs-utils`, then re-run.
- `No such device` after touching the mount point: inspect `systemctl status home-phl-FermiBotNas.mount` and `journalctl -u home-phl-FermiBotNas.mount -n 80 --no-pager`.
- GVFS paths under `/run/user/.../gvfs/` are acceptable for desktop browsing but not for automation, rsync, or long-lived mounts.

## After Mounting

Use `/home/phl/FermiBotNas` as the stable path. For sharing skills, the current convention is:

```bash
/home/phl/FermiBotNas/fmc3-skill-hub
```
