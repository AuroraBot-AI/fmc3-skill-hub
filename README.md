# fmc3-skill-hub

[English](README.md) | [简体中文](README.zh-CN.md)

Shared skills for the fmc3 team. These skills can be used by both [Claude Code](https://claude.com/claude-code) and Codex.

Each subdirectory is a self-contained skill (a `SKILL.md` file with frontmatter that compatible coding agents read on session start). Install the directory into `~/.claude/skills/` for Claude Code or `~/.codex/skills/` for Codex.

## Skills

| Skill | Purpose |
|---|---|
| [`add-fmc3-user/`](add-fmc3-user/SKILL.md) | Provision a new fmc3-N team member: system account, password, workspace dir, symlinks, shared `.bashrc`. |
| [`mount-fermibot-nas/`](mount-fermibot-nas/SKILL.md) | Configure stable systemd automount access to the FermiBot NAS. |
| [`upload2hf/`](upload2hf/SKILL.md) | Upload local datasets or model directories to Hugging Face Hub with the fmc3 upload wrapper. |

## Runtime environments

Installing or linking skills does not require a conda environment. Activate the environment below only when running commands from a skill.

| Skill | Runtime environment |
|---|---|
| `add-fmc3-user` | No conda environment. Run in a normal shell with root/sudo privileges on the target host. |
| `mount-fermibot-nas` | No conda environment. Run in a normal shell with root/sudo privileges on the target host. Requires `cifs-utils` and network access to `192.168.1.123`. |
| `upload2hf` | Use the base conda environment on fmc3 hosts: `conda activate base`, or make sure `/home/phl/miniconda3/bin/hf` is on `PATH`. Requires the Hugging Face CLI command `hf`. |

Run the NAS mount setup after installing the skill:

```bash
cd ~/fmc3-skill-hub/mount-fermibot-nas
sudo bash scripts/setup_fermibot_nas_automount.sh
```

## Install (user-level, all skills)

Claude Code:

```bash
git clone https://github.com/AuroraBot-AI/fmc3-skill-hub.git ~/fmc3-skill-hub
mkdir -p ~/.claude/skills
ln -s ~/fmc3-skill-hub/add-fmc3-user ~/.claude/skills/add-fmc3-user
ln -s ~/fmc3-skill-hub/mount-fermibot-nas ~/.claude/skills/mount-fermibot-nas
ln -s ~/fmc3-skill-hub/upload2hf ~/.claude/skills/upload2hf
```

Codex:

```bash
git clone https://github.com/AuroraBot-AI/fmc3-skill-hub.git ~/fmc3-skill-hub
mkdir -p ~/.codex/skills
ln -s ~/fmc3-skill-hub/add-fmc3-user ~/.codex/skills/add-fmc3-user
ln -s ~/fmc3-skill-hub/mount-fermibot-nas ~/.codex/skills/mount-fermibot-nas
ln -s ~/fmc3-skill-hub/upload2hf ~/.codex/skills/upload2hf
```

To install every skill in one shot, choose the target directory for your agent:

```bash
SKILLS_DIR=~/.claude/skills   # Claude Code
# SKILLS_DIR=~/.codex/skills  # Codex
mkdir -p "$SKILLS_DIR"
for d in ~/fmc3-skill-hub/*/; do
  ln -sfn "$d" "$SKILLS_DIR/$(basename "$d")"
done
```

Pull updates with `git -C ~/fmc3-skill-hub pull`.

## Install (project-level, single repo)

Claude Code:

```bash
mkdir -p .claude/skills
ln -s /path/to/fmc3-skill-hub/add-fmc3-user .claude/skills/add-fmc3-user
ln -s /path/to/fmc3-skill-hub/mount-fermibot-nas .claude/skills/mount-fermibot-nas
ln -s /path/to/fmc3-skill-hub/upload2hf .claude/skills/upload2hf
```

Codex:

```bash
mkdir -p .codex/skills
ln -s /path/to/fmc3-skill-hub/add-fmc3-user .codex/skills/add-fmc3-user
ln -s /path/to/fmc3-skill-hub/mount-fermibot-nas .codex/skills/mount-fermibot-nas
ln -s /path/to/fmc3-skill-hub/upload2hf .codex/skills/upload2hf
```

## Adding a new skill

1. Create a directory at the repo root: `<skill-name>/`.
2. Inside it, write a `SKILL.md` starting with frontmatter:
   ```markdown
   ---
   name: <skill-name>
   description: One sentence — when should Claude Code or Codex invoke this? Include trigger phrases.
   ---
   ```
3. Add the skill row to the table above.
4. Commit and push.
