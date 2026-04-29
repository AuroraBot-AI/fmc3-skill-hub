---
name: sync-folder-to-nas
description: Use when scanning a local folder and the FermiBot NAS to synchronize files without duplicates, back up a specified directory to NAS, compare local/NAS contents by hash, skip already-present files, or avoid overwriting same-path files with different content.
---

# Sync Folder To NAS

## Overview

Use `scripts/sync_folder_to_nas.py` to copy files from a specified local folder into the FermiBot NAS while avoiding duplicates. The script scans both sides, hashes files, skips content already present on the NAS, and avoids overwriting same-path files with different content.

## Runtime Environment

No conda environment is required. Use system Python 3. The NAS should be mounted at:

```bash
/home/phl/FermiBotNas
```

If that path is not mounted, use `$mount-fermibot-nas` first.

## Quick Start

Always dry-run first:

```bash
python scripts/sync_folder_to_nas.py /path/to/local_folder --dest-root /home/phl/FermiBotNas/backups
```

Execute after reviewing the plan:

```bash
python scripts/sync_folder_to_nas.py /path/to/local_folder --dest-root /home/phl/FermiBotNas/backups --execute
```

By default, the destination folder is:

```bash
<dest-root>/<local-folder-name>
```

Use `--dest-name` to choose a dedicated NAS folder name:

```bash
python scripts/sync_folder_to_nas.py /path/to/local_folder \
  --dest-root /home/phl/FermiBotNas \
  --dest-name my_synced_folder \
  --execute
```

## Behavior

- Scans all files under the source folder.
- Scans all files already under the destination root, not just the destination subfolder, so duplicates elsewhere on NAS are skipped.
- Hashes files with SHA-256 to detect duplicate content.
- Skips files whose content already exists on NAS.
- Copies missing files into the destination folder while preserving relative paths.
- If the target relative path exists with different content, writes a renamed conflict copy instead of overwriting.
- Writes a JSON report. Dry-run defaults to `/tmp`; `--execute` defaults to the destination folder. Use `--report` to choose a path.
- Does not delete files from NAS.

## Useful Options

```bash
--execute                 actually copy files; omitted means dry-run
--dest-root PATH          NAS root to scan and write under
--dest-name NAME          destination subfolder name
--report PATH             write JSON report to this path
--exclude PATTERN         skip paths matching a glob; can be repeated
--include-hidden          include hidden files and folders
```

Default excludes include `.git/**`, `__pycache__/**`, and `.cache/**`.

## Verification

After `--execute`, check:

```bash
find /home/phl/FermiBotNas/backups/<folder-name> -maxdepth 2 -type f | sort | sed -n '1,80p'
python scripts/sync_folder_to_nas.py /path/to/local_folder --dest-root /home/phl/FermiBotNas/backups
```

The second command should report already-present content as skipped in dry-run mode.
