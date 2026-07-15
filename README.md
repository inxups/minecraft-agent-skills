# minecraft-agent-skills

[![Skills Audit](https://github.com/Jahrome907/minecraft-agent-skills/actions/workflows/skills-audit.yml/badge.svg)](https://github.com/Jahrome907/minecraft-agent-skills/actions/workflows/skills-audit.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![GitHub release](https://img.shields.io/github/v/release/Jahrome907/minecraft-agent-skills)](https://github.com/Jahrome907/minecraft-agent-skills/releases/latest)
[![Minecraft](https://img.shields.io/badge/Minecraft-26.2-brightgreen)](https://www.minecraft.net/)

A public bundle of **5 AI agent skills** for Minecraft 26.2 modding, automated
testing, CI/release work, world generation, and image generation. Java examples
target Java 25 and NeoForge unless a section explicitly says otherwise.

Use the repository as raw skill folders for Codex or Claude Code, or load the
dual-target plugin under `plugins/minecraft-codex-skills/`. The
`minecraft-imagegen` skill requires a host that exposes image generation; Codex
supports that directly, while other hosts must treat the skill as conditional.

This is an independent, community-maintained project. It is not affiliated with
or endorsed by Mojang Studios, Microsoft, or the official Minecraft project.

## Skills

| Skill | What it covers |
|---|---|
| `minecraft-modding` | NeoForge 26.2 blocks, items, entities, events, networking, and datagen |
| `minecraft-testing` | JUnit 5 and NeoForge GameTest layouts and validation |
| `minecraft-ci-release` | GitHub Actions, Modrinth/CurseForge publishing, and release governance |
| `minecraft-world-generation` | Biomes, dimensions, configured/placed features, structures, and biome modifiers |
| `minecraft-imagegen` | Pack icons, promo art, concept textures, thumbnails, and UI mockups |

Each skill is self-contained. `SKILL.md` supplies routing and workflow guidance;
some skills also include focused `references/` and deterministic `scripts/`
helpers.

## Source And Mirrors

`.agents/skills/` is the canonical source of truth. The repository sync command
replaces these generated mirrors with exact copies:

- `.codex/skills/`
- `.claude/skills/`
- `plugins/minecraft-codex-skills/skills/`

Do not hand-edit a mirror. Make canonical changes first, then run
`npm run sync:skills`.

## Installation

### Raw Skills For Codex

```bash
git clone https://github.com/inxups/minecraft-agent-skills /tmp/minecraft-agent-skills
cp -R /tmp/minecraft-agent-skills/.agents .
```

### Raw Skills For Claude Code

```bash
git clone https://github.com/inxups/minecraft-agent-skills /tmp/minecraft-agent-skills
cp -R /tmp/minecraft-agent-skills/.claude .
```

### Plugin Bundle

The plugin bundle contains both Codex and Claude Code manifests:

```text
plugins/minecraft-codex-skills/
├── .codex-plugin/plugin.json
├── .claude-plugin/plugin.json
└── skills/
```

For a Codex local marketplace install, keep `.agents/plugins/marketplace.json`
and `plugins/minecraft-codex-skills/` under the same repository root, open
`/plugins`, and install `minecraft-codex-skills` from the discovered marketplace.

For Claude Code local testing:

```bash
claude --plugin-dir ./plugins/minecraft-codex-skills
```

### Agent-Assisted Install

From a target project, an agent can download the repository archive and merge
the appropriate raw-skill tree. It should replace only this bundle's five skill
directories and the bundled skills index, preserving unrelated local skills.

After installation, verify these directories:

```text
minecraft-modding
minecraft-testing
minecraft-ci-release
minecraft-world-generation
minecraft-imagegen
```

The installer must not run Minecraft, Gradle, Paper, or a server from this
repository; this repository contains reusable skill content, not a game project.

## Project Structure

```text
.agents/
├── plugins/
│   └── marketplace.json
└── skills/
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
    │   └── scripts/validate-workflow-snippets.sh
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

.codex/skills/                         # generated mirror
.claude/skills/                        # generated mirror
plugins/minecraft-codex-skills/skills/ # generated plugin mirror
```

## Development

Repository tooling requires Node 20+, npm, Bash, and `jq`. `rsync` is optional;
the mirror command uses a Node fallback when it is unavailable.

```bash
# Install/check local support tools.
bash ./scripts/setup-dev-tools.sh

# Install pinned Node dependencies.
npm ci

# Edit canonical files, regenerate mirrors, and verify everything.
npm run sync:skills
npm run check
```

The full check performs:

- canonical/mirror equality checks, including executable modes where supported;
- plugin manifest and marketplace validation;
- skill frontmatter, routing, path, and catalog auditing;
- Minecraft version consistency checks;
- Markdown JSON/YAML snippet validation;
- skill validator fixture tests;
- workflow action pin and community-file policy checks;
- Markdown linting.

Useful individual commands:

```bash
npm run check:sync
npm run check:plugin-bundle
npm run audit:skills
npm run check:version-drift
npm run test:docs
npm run test:validators
npm run test:repo-policy
npm run check:workflow-pins
npm run check:community
```

## Usage Examples

```bash
# NeoForge 26.2 mod implementation
codex "Use minecraft-modding to add a custom block and its datagen providers."

# Automated validation
codex "Use minecraft-testing to add JUnit and NeoForge GameTests for this mod."

# World generation
codex "Use minecraft-world-generation to add an ore feature and biome modifier."

# Release automation
codex "Use minecraft-ci-release to add pinned CI and release workflows."

# Bitmap asset generation
codex "Use minecraft-imagegen to create two square pack icon concepts."
```

## Supported Baseline

| Surface | Baseline |
|---|---|
| Minecraft | 26.2 |
| NeoForge examples | Verify the exact loader build from the target project |
| Java examples | 25 |
| Node repository tooling | 20+ |

Minecraft and loader APIs are versioned independently. Confirm the target
project's `gradle.properties`, build script, mappings, and loader metadata before
copying API examples into production code.

## Repository Policy

- Edit `.agents/skills/` only, then sync generated mirrors.
- Keep JSON examples valid and formatted with two-space indentation.
- Keep Java examples aligned with their stated Minecraft, Java, and loader versions.
- Add a `CHANGELOG.md` entry for user-facing skill, validator, packaging, or workflow changes.
- Do not add features that are not stable in the stated target version.

## License

MIT. See [LICENSE](LICENSE).
