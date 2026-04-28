# fmc3-skill-hub

Shared [Claude Code](https://claude.com/claude-code) skills for the fmc3 team.

Each subdirectory is a self-contained skill (a `SKILL.md` file with frontmatter Claude reads on session start). Drop the directory into `~/.claude/skills/` (user-level) or `<project>/.claude/skills/` (project-level) and Claude will pick it up.

## Skills

| Skill | Purpose |
|---|---|
| [`add-fmc3-user/`](add-fmc3-user/SKILL.md) | Provision a new fmc3-N team member: system account, password, workspace dir, symlinks, shared `.bashrc`. |

## Install (user-level, all skills)

```bash
git clone https://github.com/<your-username>/fmc3-skill-hub.git ~/fmc3-skill-hub
mkdir -p ~/.claude/skills
ln -s ~/fmc3-skill-hub/add-fmc3-user ~/.claude/skills/add-fmc3-user
```

To install every skill in one shot:

```bash
for d in ~/fmc3-skill-hub/*/; do
  ln -sfn "$d" ~/.claude/skills/"$(basename "$d")"
done
```

Pull updates with `git -C ~/fmc3-skill-hub pull`.

## Install (project-level, single repo)

```bash
mkdir -p .claude/skills
ln -s /path/to/fmc3-skill-hub/add-fmc3-user .claude/skills/add-fmc3-user
```

## Adding a new skill

1. Create a directory at the repo root: `<skill-name>/`.
2. Inside it, write a `SKILL.md` starting with frontmatter:
   ```markdown
   ---
   name: <skill-name>
   description: One sentence — when should Claude invoke this? Include trigger phrases.
   ---
   ```
3. Add the skill row to the table above.
4. Commit and push.
