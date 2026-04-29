# fmc3-skill-hub

[English](README.md) | [简体中文](README.zh-CN.md)

fmc3 团队共享的 skill 仓库,这些 skill 可以同时给 [Claude Code](https://claude.com/claude-code) 和 Codex 使用。

每个子目录都是一个独立的 skill(里面的 `SKILL.md` 带有 frontmatter,兼容的 coding agent 会在会话启动时读取)。Claude Code 安装到 `~/.claude/skills/`,Codex 安装到 `~/.codex/skills/`。

## Skills 列表

| Skill | 用途 |
|---|---|
| [`add-fmc3-user/`](add-fmc3-user/SKILL.md) | 创建一个新的 fmc3-N 团队用户:系统账号、默认密码、workspace 目录、软链接、共享 `.bashrc`。 |
| [`edit-lerobot-datasets/`](edit-lerobot-datasets/SKILL.md) | 合并、裁剪、删除本地 LeRobot 数据集里的特征。 |
| [`mount-fermibot-nas/`](mount-fermibot-nas/SKILL.md) | 配置稳定的 systemd automount,用于访问 FermiBot NAS。 |
| [`upload2hf/`](upload2hf/SKILL.md) | 使用 fmc3 上传封装把本地数据集或模型目录上传到 Hugging Face Hub。 |

## 运行环境

安装或软链接 skill 不需要 conda 环境。只有执行 skill 里的命令时,按下表选择运行环境。

| Skill | 运行环境 |
|---|---|
| `add-fmc3-user` | 不需要 conda 环境。请在目标机器的普通 shell 里用 root/sudo 权限执行。 |
| `edit-lerobot-datasets` | 使用 `lerobot-pi0` conda 环境,通过 `conda run --no-capture-output -n lerobot-pi0` 执行。需要 `lerobot-edit-dataset`。 |
| `mount-fermibot-nas` | 不需要 conda 环境。请在目标机器的普通 shell 里用 root/sudo 权限执行。需要 `cifs-utils`,并能访问 `192.168.1.123`。 |
| `upload2hf` | 在 fmc3 机器上使用 base conda 环境:`conda activate base`,或确保 `/home/phl/miniconda3/bin/hf` 在 `PATH` 里。需要 Hugging Face CLI 命令 `hf`。 |

安装 skill 后,运行 NAS 挂载配置:

```bash
cd ~/fmc3-skill-hub/mount-fermibot-nas
sudo bash scripts/setup_fermibot_nas_automount.sh
```

## 安装(用户级,全部 skill)

Claude Code:

```bash
git clone https://github.com/AuroraBot-AI/fmc3-skill-hub.git ~/fmc3-skill-hub
mkdir -p ~/.claude/skills
ln -s ~/fmc3-skill-hub/add-fmc3-user ~/.claude/skills/add-fmc3-user
ln -s ~/fmc3-skill-hub/edit-lerobot-datasets ~/.claude/skills/edit-lerobot-datasets
ln -s ~/fmc3-skill-hub/mount-fermibot-nas ~/.claude/skills/mount-fermibot-nas
ln -s ~/fmc3-skill-hub/upload2hf ~/.claude/skills/upload2hf
```

Codex:

```bash
git clone https://github.com/AuroraBot-AI/fmc3-skill-hub.git ~/fmc3-skill-hub
mkdir -p ~/.codex/skills
ln -s ~/fmc3-skill-hub/add-fmc3-user ~/.codex/skills/add-fmc3-user
ln -s ~/fmc3-skill-hub/edit-lerobot-datasets ~/.codex/skills/edit-lerobot-datasets
ln -s ~/fmc3-skill-hub/mount-fermibot-nas ~/.codex/skills/mount-fermibot-nas
ln -s ~/fmc3-skill-hub/upload2hf ~/.codex/skills/upload2hf
```

一键链接所有 skill 时,按使用的 agent 选择目标目录:

```bash
SKILLS_DIR=~/.claude/skills   # Claude Code
# SKILLS_DIR=~/.codex/skills  # Codex
mkdir -p "$SKILLS_DIR"
for d in ~/fmc3-skill-hub/*/; do
  ln -sfn "$d" "$SKILLS_DIR/$(basename "$d")"
done
```

更新:`git -C ~/fmc3-skill-hub pull`。

## 安装(项目级,单一仓库)

Claude Code:

```bash
mkdir -p .claude/skills
ln -s /path/to/fmc3-skill-hub/add-fmc3-user .claude/skills/add-fmc3-user
ln -s /path/to/fmc3-skill-hub/edit-lerobot-datasets .claude/skills/edit-lerobot-datasets
ln -s /path/to/fmc3-skill-hub/mount-fermibot-nas .claude/skills/mount-fermibot-nas
ln -s /path/to/fmc3-skill-hub/upload2hf .claude/skills/upload2hf
```

Codex:

```bash
mkdir -p .codex/skills
ln -s /path/to/fmc3-skill-hub/add-fmc3-user .codex/skills/add-fmc3-user
ln -s /path/to/fmc3-skill-hub/edit-lerobot-datasets .codex/skills/edit-lerobot-datasets
ln -s /path/to/fmc3-skill-hub/mount-fermibot-nas .codex/skills/mount-fermibot-nas
ln -s /path/to/fmc3-skill-hub/upload2hf .codex/skills/upload2hf
```

## 新增一个 skill

1. 在仓库根目录创建 `<skill-name>/` 子目录。
2. 在里面写一个 `SKILL.md`,开头是 frontmatter:
   ```markdown
   ---
   name: <skill-name>
   description: 一句话 —— Claude Code 或 Codex 应该在什么场景下调用它?写清楚触发短语。
   ---
   ```
3. 在上方"Skills 列表"表格里加一行。
4. `git commit` + `git push`。
