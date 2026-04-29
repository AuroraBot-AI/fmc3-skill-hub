#!/usr/bin/env bash
set -euo pipefail

# 要操作的数据集根目录。
DATASET_ROOT="/home/phl/workspace/dataset/Robot/agi_arm_bot"

# 原始数据集名称。
REPO_ID="pick_up_the_blue_camera_from_the_yellow_paper_into_black_box_20260415_merged"

# 删除后输出的新数据集名称。
NEW_REPO_ID="pick_up_the_blue_camera_from_the_yellow_paper_into_black_box_20260415_merged_del"

# 要删除的 episode 列表。
EPISODE_INDICES="[106]"

conda run --no-capture-output -n lerobot-pi0 \
  lerobot-edit-dataset \
  --root "${DATASET_ROOT}" \
  --repo_id "${REPO_ID}" \
  --new_repo_id "${NEW_REPO_ID}" \
  --operation.type delete_episodes \
  --operation.episode_indices "${EPISODE_INDICES}"
