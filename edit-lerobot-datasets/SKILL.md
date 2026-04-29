---
name: edit-lerobot-datasets
description: Use when editing local LeRobot datasets with lerobot-edit-dataset, including merging datasets with the same task/prompt, deleting bad episodes, removing observation/action features, repairing derived dataset variants, or preparing cleaned datasets under /home/phl/workspace/dataset/Robot.
---

# Edit LeRobot Datasets

## Overview

Use the bundled shell wrappers for common `lerobot-edit-dataset` operations. They run in the `lerobot-pi0` conda environment and keep the command explicit so the operator can inspect or edit variables before execution.

For the original tool notes, read `references/original-readme.md` when needed.

## Tools

- `scripts/merge_datasets.sh`: merge multiple source datasets into one output dataset.
- `scripts/delete_episodes.sh`: copy a dataset while deleting selected episode indices.
- `scripts/remove_features.sh`: copy a dataset while removing selected feature names.

## Workflow

1. Confirm the dataset root, usually `/home/phl/workspace/dataset/Robot/agi_arm_bot`.
2. Inspect dataset names under the root before editing:

   ```bash
   find /home/phl/workspace/dataset/Robot/agi_arm_bot -maxdepth 1 -mindepth 1 -type d -printf '%f\n' | sort
   ```

3. Copy or edit the relevant bundled script. Set the variables at the top:
   - `DATASET_ROOT`
   - `REPO_ID` or output repo id
   - `NEW_REPO_ID` when the operation creates a derived copy
   - `SOURCE_REPO_IDS`, `EPISODE_INDICES`, or `FEATURE_NAMES`
4. Run from the skill directory or with an absolute path:

   ```bash
   bash scripts/merge_datasets.sh
   bash scripts/delete_episodes.sh
   bash scripts/remove_features.sh
   ```

## Command Patterns

Merge datasets:

```bash
conda run --no-capture-output -n lerobot-pi0 \
  lerobot-edit-dataset \
  --root "$DATASET_ROOT" \
  --repo_id "$OUTPUT_REPO_ID" \
  --operation.type merge \
  --operation.repo_ids "['source_a', 'source_b']"
```

Delete bad episodes:

```bash
conda run --no-capture-output -n lerobot-pi0 \
  lerobot-edit-dataset \
  --root "$DATASET_ROOT" \
  --repo_id "$REPO_ID" \
  --new_repo_id "$NEW_REPO_ID" \
  --operation.type delete_episodes \
  --operation.episode_indices "[106]"
```

Remove a feature:

```bash
conda run --no-capture-output -n lerobot-pi0 \
  lerobot-edit-dataset \
  --root "$DATASET_ROOT" \
  --repo_id "$REPO_ID" \
  --new_repo_id "$NEW_REPO_ID" \
  --operation.type remove_feature \
  --operation.feature_names "['observation.images.top']"
```

## Verification

After editing, verify the output dataset directory exists and has expected LeRobot metadata:

```bash
test -d "$DATASET_ROOT/$OUTPUT_REPO_ID"
find "$DATASET_ROOT/$OUTPUT_REPO_ID" -maxdepth 2 -type f | sort | sed -n '1,80p'
test -f "$DATASET_ROOT/$OUTPUT_REPO_ID/meta/info.json"
test -f "$DATASET_ROOT/$OUTPUT_REPO_ID/meta/stats.json"
```

For merge outputs, check episodes and task metadata before upload or training. If a dataset is damaged by an incomplete conversion, fix the underlying dataset first, then rerun the edit into a fresh output repo id.

## Notes

- Do not overwrite a source dataset in place. Use a new output repo id for destructive edits.
- Use Python/list syntax strings exactly as shown, for example `"[106]"` and `"['feature.name']"`.
- If the user asks to merge "same prompt" datasets, group directories by task/prompt name, skip already merged outputs, and create a `_merged` dataset name.
