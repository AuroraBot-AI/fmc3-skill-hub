---
name: upload2hf
description: Use when uploading a local directory to Hugging Face Hub, including LeRobot datasets, model checkpoints, ACT policies, README-prepared model repos, organization uploads, personal-account uploads, private repos, or large folders that should use hf upload-large-folder.
---

# Upload2hf

## Overview

Use the bundled `scripts/upload2hf.sh` wrapper for Hugging Face uploads. It creates or reuses a Hub repo, detects `dataset` vs `model` when not specified, handles local token login, and uploads with `hf upload-large-folder`.

Prefer a project-local newer script when a repository provides `scripts/upload2hf/upload2hf.sh`; otherwise use this skill's bundled `scripts/upload2hf.sh`.

## Before Uploading

1. Confirm the local directory exists and is the directory that should become the repo contents.
2. If the user asks for a model upload and README/model card work, write or update `README.md` inside the model directory before uploading.
3. Check `hf --help` is available. If no local token exists, the script will prompt for a Hugging Face token unless `HF_INPUT_TOKEN` is provided.
4. Choose target namespace:
   - default organization: `FMC3-Robotic`
   - personal account: set `HF_ORGANIZATION=""`
   - other organization: set `HF_ORGANIZATION=<org>`

## Commands

Set the script path first:

```bash
UPLOAD2HF="$PWD/scripts/upload2hf/upload2hf.sh"
test -x "$UPLOAD2HF" || UPLOAD2HF="$HOME/.claude/skills/upload2hf/scripts/upload2hf.sh"
```

Upload to the default organization, using the folder name as repo name:

```bash
bash "$UPLOAD2HF" /path/to/local_dir
```

Upload to the user's personal namespace:

```bash
HF_ORGANIZATION="" bash "$UPLOAD2HF" /path/to/local_dir
```

Upload to another organization or set a custom repo name:

```bash
HF_ORGANIZATION=FMC3-Robotic bash "$UPLOAD2HF" /path/to/local_dir repo-name
bash "$UPLOAD2HF" /path/to/local_dir namespace/repo-name
```

Force repo type or visibility:

```bash
HF_REPO_TYPE=model bash "$UPLOAD2HF" /path/to/model_dir repo-name
HF_REPO_TYPE=dataset HF_REPO_VISIBILITY=private bash "$UPLOAD2HF" /path/to/dataset_dir repo-name
```

Large uploads can enable Xet high-performance mode:

```bash
HF_XET_HIGH_PERFORMANCE=1 bash "$UPLOAD2HF" /path/to/local_dir repo-name
```

## Important Behavior

- `HF_REPO_TYPE` accepts only `dataset` or `model`. When unset, the script treats directories containing files such as `config.json`, `tokenizer.json`, `*.safetensors`, `*.bin`, or `*.gguf` as model repos; otherwise it uploads as a dataset repo.
- `HF_ORGANIZATION=""` is intentional shell syntax for personal-account uploads.
- If `REPO_NAME` already contains `namespace/name`, the script does not prepend `HF_ORGANIZATION`.
- The script sanitizes repo names, excluding characters Hugging Face does not allow.
- The upload excludes `.cache/huggingface/**`.
- Do not print tokens. Prefer existing local login or `HF_INPUT_TOKEN` only when the user explicitly provides one.

## Verification

Read the command exit code and final output. A successful upload prints `上传完成!` and a repo URL.

For an extra check, run one of:

```bash
hf repo files namespace/repo-name --repo-type dataset | sed -n '1,40p'
hf repo files namespace/repo-name --repo-type model | sed -n '1,40p'
```

Report the final repo URL, repo type, visibility if specified, and local source path.
