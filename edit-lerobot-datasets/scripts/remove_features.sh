#!/usr/bin/env bash
set -euo pipefail

# 要操作的数据集根目录。
DATASET_ROOT="/home/phl/workspace/dataset/Robot/agi_arm_bot"

# 原始数据集名称。
REPO_ID="pick_up_the_blue_camera_from_the_yellow_paper_into_black_box_20260415_merged"

# 删除特征后输出的新数据集名称。
NEW_REPO_ID="pick_up_the_blue_camera_from_the_yellow_paper_into_black_box_20260415_merged_remove_feature"

# 要删除的特征列表。
FEATURE_NAMES="['observation.images.top']"

conda run --no-capture-output -n lerobot-pi0 \
  lerobot-edit-dataset \
  --root "${DATASET_ROOT}" \
  --repo_id "${REPO_ID}" \
  --new_repo_id "${NEW_REPO_ID}" \
  --operation.type remove_feature \
  --operation.feature_names "${FEATURE_NAMES}"
