# AGENTS.md - minecraft-agent-skills Repository

This repository contains five Minecraft AI agent skills and a dual-target plugin
bundle for Codex and Claude Code. It is not a Minecraft game project: skill files
and support assets are copied into downstream mod or content projects.

## Repository Layout

`.agents/skills/` is the canonical source of truth:

```text
.agents/skills/
├── README.md
├── minecraft-modding/
│   ├── SKILL.md
│   └── references/
│       ├── common-patterns.md
│       └── neoforge-api.md
├── minecraft-testing/
│   ├── SKILL.md
│   ├── references/test-layouts.md
│   └── scripts/validate-test-layout.sh
├── minecraft-ci-release/
│   ├── SKILL.md
│   └── scripts/
│       ├── validate-workflow-snippets.sh
│       └── vendor/
├── minecraft-world-generation/
│   ├── SKILL.md
│   └── scripts/
│       ├── jq-shim.mjs
│       └── validate-worldgen-json.sh
└── minecraft-imagegen/
    ├── SKILL.md
    ├── references/
    │   ├── asset-recipes.md
    │   └── prompt-patterns.md
    └── scripts/scaffold-asset-brief.sh
```

Generated mirrors are replaced by the sync command:

```text
.codex/skills/
.claude/skills/
plugins/minecraft-codex-skills/skills/
```

The plugin manifests live under `plugins/minecraft-codex-skills/`; its repo-local
marketplace entry lives at `.agents/plugins/marketplace.json`.

## Skill Selection

| Task | Skill |
|---|---|
| NeoForge mod code, registries, events, networking, datagen | `minecraft-modding` |
| JUnit or NeoForge GameTests | `minecraft-testing` |
| GitHub Actions, releases, Modrinth/CurseForge publishing | `minecraft-ci-release` |
| Biomes, dimensions, configured/placed features, structures | `minecraft-world-generation` |
| Pack art, icons, thumbnails, concept textures, UI mockups | `minecraft-imagegen` |

Skills are independent. Do not introduce a dependency on a skill that is not in
the canonical catalog.

## Working Rules

- Do not run Minecraft, Gradle, Paper, or a server in this repository.
- Edit `.agents/skills/` only; run `npm run sync:skills` after canonical changes.
- Treat `plugins/minecraft-codex-skills/skills/`, `.codex/skills/`, and
  `.claude/skills/` as generated output.
- Keep Minecraft examples accurate for 26.2 and Java examples accurate for Java 25.
- Verify exact NeoForge loader and API versions against the downstream project's
  dependency metadata before changing version-specific examples.
- Keep JSON valid and formatted with two-space indentation.
- Mark platform-specific patterns clearly.
- Prefer complete runnable examples over pseudocode.
- Keep helper scripts self-contained in their skill directory.
- Add a `CHANGELOG.md` entry for repository content changes.

## Version Updates

When the Minecraft baseline changes, review these canonical files:

1. `minecraft-modding/SKILL.md`
2. `minecraft-modding/references/neoforge-api.md`
3. `minecraft-modding/references/common-patterns.md`
4. `minecraft-testing/SKILL.md`
5. `minecraft-testing/references/test-layouts.md`
6. `minecraft-testing/scripts/validate-test-layout.sh`
7. `minecraft-ci-release/SKILL.md`
8. `minecraft-ci-release/scripts/validate-workflow-snippets.sh`
9. `minecraft-world-generation/SKILL.md`
10. `minecraft-world-generation/scripts/validate-worldgen-json.sh`
11. `.agents/skills/README.md`
12. `README.md` and plugin manifests
13. `scripts/check-version-drift.mjs`

## Verification

After edits:

```bash
npm run sync:skills
npm run check
```

The full check must validate mirror equality, plugin metadata, skill routing and
catalog integrity, version consistency, documentation snippets, skill fixtures,
workflow pins, community files, and Markdown formatting.
