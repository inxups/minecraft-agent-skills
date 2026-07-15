---
name: minecraft-world-generation
description: "Create world generation content for Minecraft 26.2 NeoForge mods and datapack resources, including configured and placed features, biomes, dimensions, structures, structure sets, template pools, tags, and NeoForge biome modifiers. Use when Codex needs to design registry-backed worldgen data, preserve 26.2 runtime schemas, diagnose missing local references, or wire worldgen datagen into a NeoForge project."
---

# Minecraft World Generation Skill

Use this skill for registry-backed worldgen data. Use `minecraft-modding` for
unrelated gameplay systems and Java integration outside worldgen.

### Routing Boundaries

- `Use when`: the task is registry-backed biomes, dimensions, configured or
  placed features, structures, timelines, world clocks, tags, or NeoForge
  biome modifiers.
- `Do not use when`: the task is general mod code, resources, or networking;
  use `minecraft-modding`.
- `Do not use when`: the task is automated tests, publishing, or bitmap assets;
  use the corresponding focused skill.

## Version Gate

Minecraft 26.2 changed several data-driven surfaces. Do not copy older biome,
dimension type, noise-settings, environment, or timeline JSON into a
26.2 project.

Before editing those registries:

1. Read the target project's Minecraft and NeoForge versions.
2. Export or inspect the exact 26.2 vanilla registry entry used as the baseline.
3. Preserve fields and referenced registries that are not part of the requested
   change.
4. Validate locally, then test in a fresh world.

At the repository's 2026-07-15 baseline, the newest published NeoForge 26.2
artifact is `26.2.0.15-beta`. Recheck the project's configured version instead
of silently upgrading it or assuming a stable release exists.

## Resource Layout

~~~text
src/main/resources/
  data/<namespace>/
    worldgen/
      biome/
      configured_feature/
      placed_feature/
      noise_settings/
      structure/
      structure_set/
      processor_list/
      template_pool/
    dimension/
    dimension_type/
    timeline/
    world_clock/
    structure/
    tags/timeline/
    tags/worldgen/<registry>/
    neoforge/biome_modifier/
~~~

Use singular registry directory names. Structure templates belong under
`data/<namespace>/structure/<path>.nbt`.

## Reference Model

Keep these relationships intact:

~~~text
dimension -> dimension_type
dimension noise generator -> worldgen/noise_settings
dimension_type default_clock -> world_clock
dimension_type timelines -> timeline or timeline tag
timeline clock -> world_clock
placed_feature -> configured_feature
biome feature entry -> placed_feature
NeoForge add_features modifier -> placed_feature
structure_set entry -> structure or structure tag
jigsaw structure -> template_pool
single_pool_element -> structure template + processor_list
~~~

Unqualified references inherit the source namespace. A reference to another
namespace can only be checked locally when that namespace's registry directory
is present. Vanilla and dependency-provided references may be external.

## Configured And Placed Features

Use the configured feature for what is generated and the placed feature for
where and how often it is attempted.

`data/mymod/worldgen/configured_feature/my_ore.json`:

~~~json
{
  "type": "minecraft:ore",
  "config": {
    "targets": [
      {
        "target": {
          "predicate_type": "minecraft:tag_match",
          "tag": "minecraft:stone_ore_replaceables"
        },
        "state": {
          "Name": "mymod:my_ore"
        }
      }
    ],
    "size": 6,
    "discard_chance_on_air_exposure": 0.0
  }
}
~~~

`data/mymod/worldgen/placed_feature/my_ore.json`:

~~~json
{
  "feature": "mymod:my_ore",
  "placement": [
    {
      "type": "minecraft:count",
      "count": 8
    },
    {
      "type": "minecraft:in_square"
    },
    {
      "type": "minecraft:biome"
    }
  ]
}
~~~

Do not guess a height-provider schema. Copy the exact 26.2 vanilla placement
modifier that matches the desired distribution, then change only its bounds.

## NeoForge Biome Modifier

Use the singular path
`data/<namespace>/neoforge/biome_modifier/<name>.json`.

~~~json
{
  "type": "neoforge:add_features",
  "biomes": "#minecraft:is_overworld",
  "features": [
    "mymod:my_ore"
  ],
  "step": "underground_ores"
}
~~~

The `features` and `structures` fields may be a single registry reference or
an array. Structure tags use the `#namespace:path` form and live under
`tags/worldgen/structure/`.

## Dimension Time Resources

Minecraft 26.2 separates clocks from timelines. A dimension type can select a
default clock and a direct timeline, a timeline list, or a timeline tag.

`data/mymod/world_clock/overworld.json`:

~~~json
{}
~~~

`data/mymod/timeline/day.json`:

~~~json
{
  "clock": "mymod:overworld",
  "period_ticks": 24000,
  "time_markers": {},
  "tracks": {}
}
~~~

`data/mymod/tags/timeline/in_overworld.json`:

~~~json
{
  "values": [
    "mymod:day"
  ]
}
~~~

The corresponding fields in
`data/mymod/dimension_type/overworld_like.json` are:

~~~json
{
  "ambient_light": 0.0,
  "coordinate_scale": 1.0,
  "default_clock": "mymod:overworld",
  "has_ceiling": false,
  "has_ender_dragon_fight": false,
  "has_skylight": true,
  "height": 384,
  "infiniburn": "#minecraft:infiniburn_overworld",
  "logical_height": 384,
  "min_y": -64,
  "monster_spawn_block_light_limit": 0,
  "monster_spawn_light_level": {
    "max_inclusive": 7,
    "min_inclusive": 0,
    "type": "minecraft:uniform"
  },
  "timelines": "#mymod:in_overworld"
}
~~~

Do not reintroduce pre-26.2 dimension flags such as direct bed, raid, natural,
or fixed visual-effect fields. Dimension behavior and visuals now use the
current dimension fields, attributes, clocks, and timelines.

## Jigsaw Structures

A jigsaw structure needs all of the following:

- a `worldgen/structure` entry whose `start_pool` resolves;
- a `worldgen/template_pool` entry;
- each single pool element's `location` NBT under `structure/`;
- each element's `processors` entry, or the known vanilla
  `minecraft:empty` processor list;
- a `worldgen/structure_set` or another placement mechanism.

Nested paths are part of the registry ID. For example,
`worldgen/template_pool/village/start.json` is
`namespace:village/start`.

## Validation

Run the bundled structural validator against the directory that contains
`data/`:

~~~bash
./scripts/validate-worldgen-json.sh --root src/main/resources
./scripts/validate-worldgen-json.sh --root src/main/resources --strict
~~~

The validator checks:

- JSON syntax in supported worldgen, dimension, timeline, world-clock, tag,
  and biome-modifier paths;
- singular NeoForge biome-modifier and worldgen-tag directory conventions;
- local dimension, feature, structure, template-pool, processor-list, template,
  and structure-tag references;
- local dimension-type-to-clock/timeline and timeline-to-clock references;
- scalar and array biome-modifier feature and structure fields.

It intentionally does not claim that arbitrary JSON matches the current 26.2
codec. A successful run is structural preflight, not runtime proof.

## Runtime Verification

1. Run the target project's data generation when providers own the files.
2. Start a disposable 26.2 test world from the downstream project.
3. Inspect `latest.log` for codec and registry errors.
4. Locate or place the content with the target runtime's available commands.
5. Generate new chunks; `/reload` does not regenerate existing terrain.
6. Run NeoForge GameTests for deterministic block or structure behavior where
   practical.

Do not run Minecraft or Gradle from this skills repository.

## References

- NeoForge worldgen documentation: https://docs.neoforged.net/docs/worldgen/
- NeoForge biome modifiers: https://docs.neoforged.net/docs/worldgen/biomemodifier/
- Minecraft Wiki world generation: https://minecraft.wiki/w/Custom_world_generation
