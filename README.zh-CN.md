# fmc3-skill-hub

[English](README.md) | [简体中文](README.zh-CN.md)

fmc3 团队共享的 [Claude Code](https://claude.com/claude-code) skill 仓库。

每个子目录都是一个独立的 skill(里面的 `SKILL.md` 带有 frontmatter,Claude 会在会话启动时读取)。把目录放进 `~/.claude/skills/`(用户级)或 `<项目>/.claude/skills/`(项目级),Claude 就能识别并按需调用。

## Skills 列表

| Skill | 用途 |
|---|---|
| [`add-fmc3-user/`](add-fmc3-user/SKILL.md) | 创建一个新的 fmc3-N 团队用户:系统账号、默认密码、workspace 目录、软链接、共享 `.bashrc`。 |

## 安装(用户级,全部 skill)

```bash
git clone https://github.com/<你的用户名>/fmc3-skill-hub.git ~/fmc3-skill-hub
mkdir -p ~/.claude/skills
ln -s ~/fmc3-skill-hub/add-fmc3-user ~/.claude/skills/add-fmc3-user
```

一键链接所有 skill:

```bash
for d in ~/fmc3-skill-hub/*/; do
  ln -sfn "$d" ~/.claude/skills/"$(basename "$d")"
done
```

更新:`git -C ~/fmc3-skill-hub pull`。

## 安装(项目级,单一仓库)

```bash
mkdir -p .claude/skills
ln -s /path/to/fmc3-skill-hub/add-fmc3-user .claude/skills/add-fmc3-user
```

## 新增一个 skill

1. 在仓库根目录创建 `<skill-name>/` 子目录。
2. 在里面写一个 `SKILL.md`,开头是 frontmatter:
   ```markdown
   ---
   name: <skill-name>
   description: 一句话 —— Claude 应该在什么场景下调用它?写清楚触发短语。
   ---
   ```
3. 在上方"Skills 列表"表格里加一行。
4. `git commit` + `git push`。
