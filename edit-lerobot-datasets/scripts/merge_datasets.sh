#!/usr/bin/env bash
set -euo pipefail

# 要操作的数据集根目录。
DATASET_ROOT="/home/phl/workspace/dataset/Robot/agi_arm_bot"

# 合并后的新数据集名称。
REPO_ID="right_hand_picks_up_the_camera_left_hand_picks_up_the_pen_then_left_hand_uses_the_pen_to_touch_20260427_merged"

# 要合并的数据集名称列表。
SOURCE_REPO_IDS="['right_hand_picks_up_the_camera_left_hand_picks_up_the_pen_then_left_hand_uses_the_pen_to_touch_20260427', 'right_hand_picks_up_the_camera_left_hand_picks_up_the_pen_then_left_hand_uses_the_pen_to_touch_20260427_2']"

conda run --no-capture-output -n lerobot-pi0 \
  lerobot-edit-dataset \
  --root "${DATASET_ROOT}" \
  --repo_id "${REPO_ID}" \
  --operation.type merge \
  --operation.repo_ids "${SOURCE_REPO_IDS}"
