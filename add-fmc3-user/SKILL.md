---
name: add-fmc3-user
description: Provision a new fmc3 team member on this workspace host — creates the system user, sets default password, builds /workspace/users/fmc3-N-workspace with the standard symlinks, and applies the shared .bashrc. Use when the user says things like "新来一个同事/加个新用户/再开一个 fmc3 账号/onboard a new colleague".
---

# add-fmc3-user

Provisions one new fmc3-N team member end-to-end. Run from root (or with sudo). The script is idempotent on the index pick — it always uses the next free `fmc3-N`.

## Inputs to confirm with the user before running

Use AskUserQuestion only if the user did not already specify these:

1. **Username** — default = next free `fmc3-N` (highest existing N + 1; UID 1000 + N). Confirm or override.
2. **Password** — default = `521521` (team standard). Confirm or override.

If the user invoked the skill with a clear "just do it for the next one" intent, skip the confirmation and proceed with defaults — only ask when ambiguous.

## Pre-flight checks

```bash
# Must be root
[ "$(id -u)" -eq 0 ] || { echo "must run as root"; exit 1; }

# Pick next N
LAST_N=$(getent passwd | awk -F: '/^fmc3-[0-9]+:/ {split($1,a,"-"); print a[2]}' | sort -n | tail -1)
N=$((LAST_N + 1))
USER="fmc3-$N"
UID_NUM=$((1000 + N))

# Sanity: user must not exist, workspace must not exist
id "$USER" 2>/dev/null && { echo "$USER already exists"; exit 1; }
[ -e "/workspace/users/$USER-workspace" ] && { echo "workspace already exists"; exit 1; }
```

## Provisioning steps

Run these sequentially (each depends on the previous):

```bash
# 1. System account
useradd -m -u "$UID_NUM" -s /bin/bash "$USER"

# 2. Password (default 521521 — chpasswd warns but writes it)
echo "$USER:521521" | chpasswd

# 3. Workspace directory
mkdir "/workspace/users/$USER-workspace"
chown "$USER:$USER" "/workspace/users/$USER-workspace"
chmod 700 "/workspace/users/$USER-workspace"

# 4. Symlinks inside workspace — dataset/models owned by user, shared by root
sudo -u "$USER" ln -s /workspace/dataset "/workspace/users/$USER-workspace/dataset"
sudo -u "$USER" ln -s /workspace/models  "/workspace/users/$USER-workspace/models"
ln -s /workspace/shared "/workspace/users/$USER-workspace/shared"

# 5. Shared .bashrc (conda + ROS humble init) — fmc3-1 is the canonical source
cp /home/fmc3-1/.bashrc "/home/$USER/.bashrc"
chown "$USER:$USER" "/home/$USER/.bashrc"

# 6. Home → workspace symlink
sudo -u "$USER" ln -s "/workspace/users/$USER-workspace" "/home/$USER/workspace"
```

## Verify

```bash
id "$USER"
ls -la "/workspace/users/$USER-workspace/"
ls -la "/home/$USER/workspace"
sudo -u "$USER" bash -lc 'echo conda=$(command -v conda); echo ros=$ROS_DISTRO'
```

Expect: three symlinks in the workspace dir (`dataset`, `models`, `shared`), `~/workspace` symlink in home, conda resolvable, `ROS_DISTRO=humble`.

## What this skill does NOT do

- Does not seed `.ssh/authorized_keys`, `.gitconfig`, `.netrc`, IDE configs, etc. Those are per-user and grow on first login.
- Does not add the user to extra groups (e.g. `docker`, `sudo`). Add manually if a particular hire needs them.
- Does not change the default password policy. If the team standard ever moves off `521521`, update this skill.

## Reference: established conventions (do not deviate without asking)

- **UID = 1000 + N**, sequential, no gaps.
- **Workspace dir** = `/workspace/users/fmc3-N-workspace`, mode `700`, owned by the user.
- **Symlinks**: `dataset` → `/workspace/dataset`, `models` → `/workspace/models` (owned by user); `shared` → `/workspace/shared` (owned by root). This matches every existing fmc3-0..5 workspace.
- **Home `.bashrc`** matches `/home/fmc3-1/.bashrc` (md5 `6ff0d2f542bac13ad2df2714bcf45857` as of 2026-04). It adds `conda init` for `/opt/miniconda3` and `source /opt/ros/humble/setup.bash`.
- **Home `workspace` symlink** → `/workspace/users/fmc3-N-workspace`, owned by the user.
