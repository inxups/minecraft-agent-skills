# Contributing

Thanks for contributing to `minecraft-agent-skills`.

## Scope

- Treat `.agents/skills/` as the canonical source of truth.
- Do not edit `.codex/skills/`, `.claude/skills/`, or `plugins/minecraft-codex-skills/skills/` by hand. Sync them from canonical changes.
- Keep examples accurate for Minecraft `1.21.x` and Java `21`.
- Prefer small, reviewable pull requests that change one skill, validator, or repo policy area at a time.

## Before You Start

Repo development tooling requires Node `20+`. Install pinned local dependencies
before running repo checks:

```bash
npm ci
```

On Windows, prefer the npm script entrypoints below. Use Git Bash or WSL only
when running the lower-level shell scripts directly.

## Local Workflow

1. Edit the canonical source under `.agents/skills/` or the relevant repo-level docs/scripts.
2. Sync mirrored skill trees:
   `npm run sync:skills`
3. Run the full repo gate:
   `npm run check`
4. Update `CHANGELOG.md` for user-facing skill changes, validation changes, or repo workflow changes.

## Expectations For Skill Changes

- Include clear routing boundaries in every `SKILL.md`.
- Prefer complete, runnable examples over pseudo-code.
- Keep validator commands mirror-safe by using `./scripts/...` paths.
- When a skill ships helper scripts, keep them self-contained inside that skill directory.
- Avoid creating cross-skill dependencies. Skills should remain independently usable.

## Pull Requests

- Summarize the change and the user-facing impact.
- Include verification notes, especially when changing validators or mirrors.
- Mention any external docs or upstream references used to justify the change.
- If a change touches plugin packaging or release flow, verify both raw-skill and plugin-bundle paths still make sense.
