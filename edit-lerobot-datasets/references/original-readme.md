# LeRobot Dataset Edit Tools

这组脚本用于常见的 LeRobot 数据集编辑操作，写法尽量保持直白：

- 顶部改几个变量
- 下面直接执行一条清晰的 `lerobot-edit-dataset` 命令

当前提供：

- `merge_datasets.sh`: 合并多个数据集
- `delete_episodes.sh`: 删除指定 episodes
- `remove_features.sh`: 删除指定特征

默认使用环境：

```bash
conda run --no-capture-output -n lerobot-pi0
```

使用方式：

1. 打开脚本
2. 修改顶部变量
3. 直接运行

示例：

```bash
bash /home/phl/workspace/dataset/scripts/lerobot_edit_tools/delete_episodes.sh
```
