---
name: pack-conda-envs
description: Use when packaging the current or selected conda environment into a reusable tar.gz archive, backing up virtual environments under /home/phl/workspace, avoiding duplicate conda-pack outputs, restoring packed environments on another machine, or checking existing conda environment archives.
---

# Pack Conda Envs

## Overview

Use `scripts/pack_conda_env.py` to package a conda environment into `/home/phl/workspace/conda-env-packs` with duplicate detection. The script records a manifest for each archive and skips a new package when the same environment fingerprint already exists.

## Runtime Environment

Run from a normal shell. No project conda environment is required, but `conda` and `conda-pack` must be available:

```bash
conda activate base
conda install -c conda-forge conda-pack
```

## Quick Start

Package the currently active conda environment:

```bash
cd /home/phl/workspace/fmc3-skill-hub/pack-conda-envs
python scripts/pack_conda_env.py
```

Preview without running `conda pack`:

```bash
python scripts/pack_conda_env.py --dry-run
```

Package a named environment:

```bash
python scripts/pack_conda_env.py --env-name arm-hand-teleop
python scripts/pack_conda_env.py --env-name arm-hand-teleop-pi0 --ignore-editable-packages
```

Package by full prefix:

```bash
python scripts/pack_conda_env.py --env-prefix /home/phl/miniconda3/envs/teleop
```

## Output

Default output directory:

```bash
/home/phl/workspace/conda-env-packs
```

Each package creates:

```text
<env-name>-<fingerprint>.tar.gz
<env-name>-<fingerprint>.manifest.json
<env-name>-<fingerprint>.sha256
```

The fingerprint includes the environment name, prefix, Python version, `conda list --explicit`, `pip freeze`, and selected pack options. If an existing manifest and archive match the same fingerprint, the script prints `skip: matching archive already exists` and does not create a duplicate.

## Useful Options

```bash
--env-name NAME              package this conda environment
--env-prefix PATH            package this conda environment path
--output-root PATH           archive directory; default /home/phl/workspace/conda-env-packs
--ignore-editable-packages   pass through to conda pack for pip install -e environments
--ignore-missing-files       pass through to conda pack for conda/pip file conflicts
--force                      rebuild even when the same fingerprint already exists
--dry-run                    compute output plan without packaging
--list-existing              list existing manifests under output-root
```

Use `--ignore-editable-packages` for environments with editable source installs. Use `--ignore-missing-files` only when `conda pack` reports files managed by conda were overwritten or deleted by pip.

## Restore On Another Machine

```bash
mkdir -p ~/miniconda3/envs/<env-name>
tar -xzf <env-name>-<fingerprint>.tar.gz -C ~/miniconda3/envs/<env-name>
conda activate <env-name>
conda-unpack
```

After restore, check:

```bash
conda env list
python --version
```
