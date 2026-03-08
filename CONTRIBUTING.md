# Contributing

Thanks for contributing to `minecraft-codex-skills`.

## Repository Model

- Canonical skills live in `.agents/skills/`.
- `.codex/skills/` is a compatibility mirror and must stay in sync.

## Development Workflow

1. Edit canonical files in `.agents/skills/`.
2. Ensure local tooling:
   - `./scripts/setup-dev-tools.sh`
3. Sync mirror:
   - `./scripts/sync-skills-layout.sh sync`
4. Run validation:
   - `./scripts/sync-skills-layout.sh check`
   - `node ./scripts/audit-skills.mjs`
   - `./scripts/run-skill-validator-fixtures.sh`
   - `npx -y markdownlint-cli2 "**/*.md"`
5. Update `CHANGELOG.md`.

## Content Standards

- Keep examples accurate for Minecraft `1.21.x`.
- Keep Java examples compatible with Java `21`.
- Use explicit routing boundaries in every `SKILL.md`:
  - `Use when`
  - `Do not use when`
- Keep platform boundaries clear (NeoForge/Fabric/Paper/Vanilla).
- Never commit real credentials, tokens, or private keys.

## Pull Requests

- Keep PRs focused and reviewable.
- Include rationale for behavior/structure changes.
- Ensure CI passes before requesting review.
