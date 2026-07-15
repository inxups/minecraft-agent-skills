# Minecraft Skills Index

This index lists all Minecraft skills in this repository.
Canonical source files live under `.agents/skills/`, and this README is mirrored
to compatibility trees.
Most skill content targets Minecraft `26.2`.
Minecraft 26.2 changed Java, and several vanilla data surfaces; 
treat 26.2 work as a porting task that requires fresh upstream
verification before applying these examples unchanged.

Use this index as a quick router before opening individual `SKILL.md` files.
Some skills also include local `references/` and `scripts/` support assets; the
table below is a router, not an exhaustive layout listing.

## Skill Catalog

| Skill | Primary use cases | Choose this instead when |
|---|---|---|
| `minecraft-modding` | Build NeoForge mod (blocks, items, entities, GUIs, datagen) |
| `minecraft-datapack` | Vanilla datapacks: functions, advancements, recipes, loot tables | 
| `minecraft-world-generation` | Worldgen JSON/code: biomes, dimensions, structures, features | You need building operations with WorldEdit (`minecraft-worldedit-ops`) |
| `minecraft-resource-pack` | Textures, models, sounds, fonts, shaders, pack metadata | You need gameplay logic or server operations (pick a development/admin skill) |
| `minecraft-imagegen` | Generate pack icons, promo art, thumbnails, concept textures, and UI mockups | You need deterministic pack structure, model JSON, sounds, or shader files (`minecraft-resource-pack`) |
| `minecraft-testing` | JUnit, MockBukkit, NeoForge/Fabric GameTests, CI test wiring | You need release pipelines and publishing (`minecraft-ci-release`) |
| `minecraft-ci-release` | GitHub Actions, release automation, Modrinth/CurseForge publishing | You need local implementation details of mod/plugin features (pick a dev skill) |

## Overlap Boundaries


- Use `minecraft-imagegen` for raster art, thumbnails, pack icons, and concept textures; use `minecraft-resource-pack` when the task is final pack structure plus JSON/audio/shader implementation.
- `minecraft-imagegen` also requires a host that exposes image generation; treat it as Codex-first unless the current agent explicitly supports an equivalent image tool.

## Sync Model

Edit only this canonical tree:

- `.agents/skills/`

Then mirror to compatibility trees:

- `.codex/skills/`
- `.claude/skills/`
- `plugins/minecraft-codex-skills/skills/`

Commands:

```bash
bash ./scripts/sync-skills-layout.sh sync
npm run audit:skills
```
