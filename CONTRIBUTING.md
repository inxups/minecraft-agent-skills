# Contributing

Thanks for helping improve `minecraft-agent-skills`. This is a small skills and plugin-bundle repo, so keep contributions focused and easy to review.

## Workflow

- Edit canonical skill content in `.agents/skills/` first.
- Do not hand-edit `.codex/skills/`, `.claude/skills/`, or `plugins/minecraft-codex-skills/skills/`; run `npm run sync:skills` after canonical skill edits.
- Run `npm run check` before opening a pull request.
- Update `CHANGELOG.md` for user-facing skill, validator, packaging, or workflow changes.

## Standards

- Keep examples accurate for the Minecraft and Java versions named in the skill.
- Keep routing boundaries clear so skills only trigger for the right work.
- Prefer complete, copyable examples over pseudo-code.
- Keep helper scripts self-contained in their skill directory.
- Keep PRs small and include the verification you ran.
