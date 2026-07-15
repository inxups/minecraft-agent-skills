# Minecraft Skills Index

This index lists every Minecraft skill in this repository. Canonical source
files live under `.agents/skills/`; compatibility trees and the plugin bundle
are generated from this directory.

Most skill content targets Minecraft `26.2` and Java `25`. Treat exact loader,
game, and data-format APIs as versioned surfaces and verify them against the
target project's dependency metadata before applying examples unchanged.

## Skill Catalog

| Skill | Primary use cases | Out of scope |
|---|---|---|
| `minecraft-modding` | NeoForge mod code, registries, events, networking, and datagen | Vanilla-only content and server plugin development |
| `minecraft-testing` | JUnit and NeoForge GameTest layouts and validation | Gameplay implementation and release publishing |
| `minecraft-ci-release` | GitHub Actions, release automation, Modrinth/CurseForge publishing | Local gameplay implementation |
| `minecraft-world-generation` | Biomes, dimensions, features, structures, and NeoForge biome modifiers | General recipes, advancements, and command orchestration |
| `minecraft-imagegen` | Pack icons, promo art, thumbnails, concept textures, and UI mockups | Deterministic pack JSON, audio, and shader implementation |

## Overlap Boundaries

- Use `minecraft-modding` for Java/Kotlin implementation and `minecraft-testing`
  for its automated verification.
- Use `minecraft-world-generation` for registry-backed worldgen data and
  `minecraft-modding` for the surrounding NeoForge integration.
- Use `minecraft-ci-release` after local build and test behavior is established.
- Use `minecraft-imagegen` for bitmap ideation and generation; complete final
  pack wiring in the target project using its actual resource-pack layout.

## Sync Model

Edit only `.agents/skills/`, then run:

```bash
npm run sync:skills
npm run audit:skills
```

The sync command refreshes `.codex/skills/`, `.claude/skills/`, and
`plugins/minecraft-codex-skills/skills/` from this canonical tree.
