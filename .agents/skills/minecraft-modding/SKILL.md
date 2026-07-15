---
name: minecraft-modding
description: "Full-stack Minecraft mod development skill for NeoForge (26.2). Scaffolds new mods, adds custom blocks, items, entities, recipes, commands, GUIs, dimensions, and data generation. Knows NeoForge DeferredRegister + event-bus pattern. Use when the user asks to create a Minecraft mod, add a feature to an existing mod, fix a mod bug, generate JSON assets/data"
---

# Minecraft Modding Skill

## Overview

This skill guides Codex through developing open-source Minecraft mods.
Target platforms:

| Platform | MC Version | Java | Build System |
|---|---|---|---|
| **NeoForge** | 26.2 | Java 25 | Gradle + ModDevGradle |

Always confirm the platform and Minecraft version from `gradle.properties` or `build.gradle`
before writing any mod-specific code.

### Routing Boundaries
- `Use when`: the task is Java/Kotlin mod code, registry/event work, networking, datagen wiring, and loader APIs.
- `Do not use when`: the task is exclusively worldgen data (`minecraft-world-generation`) or automated testing (`minecraft-testing`).
- `Do not use when`: the task is release automation (`minecraft-ci-release`) or bitmap asset generation (`minecraft-imagegen`).

---

## 1. Identifying the Platform

Neoforge + Minecraft 26.2

---

## 2. Build & Test Commands

```bash
# Build the mod jar
./gradlew build

# Run the Minecraft client to test
./gradlew runClient

# Run a dedicated server to test
./gradlew runServer

# Run game tests (NeoForge JUnit-style game tests)
./gradlew runGameTestServer

# Run data generation (generates JSON assets automatically)
./gradlew runData

# Clean build cache
./gradlew clean

# Check for dependency updates (optional)
./gradlew dependencyUpdates
```

After `./gradlew build`, the mod jar is at:
`build/libs/<mod_id>-<version>.jar`

---

## 3. Project Layout

```
src/
  main/
    java/<groupId>/<modid>/
      MyMod.java               ← @Mod entry point
      block/
        ModBlocks.java         ← DeferredRegister<Block>
        MyCustomBlock.java
      item/
        ModItems.java          ← DeferredRegister<Item>
      entity/
        ModEntities.java       ← DeferredRegister<EntityType<?>>
      menu/                    ← custom GUI containers
      recipe/
      worldgen/
      datagen/
        ModDataGen.java        ← GatherDataEvent handler
        providers/
    resources/
      META-INF/
        neoforge.mods.toml     <- NeoForge mod metadata
      assets/<modid>/
        blockstates/           ← JSON blockstate definitions
        models/
          block/               ← block model JSON
          item/                ← item model JSON
        textures/
          block/               ← 16×16 PNG textures
          item/
        lang/
          en_us.json           ← translation strings
      data/<modid>/
        recipe/                <- crafting recipe JSON
        loot_table/
          blocks/              ← per-block loot table JSON
        tags/
          block/
          item/
```

---

## 4. Core Concepts Cheatsheet

### Sides
- **Physical client** – the game client JAR (has rendering code)
- **Physical server** – the dedicated server JAR (no rendering)
- **Logical client** – the client thread (handles rendering, input)
- **Logical server** – the server thread (handles world simulation)
- Keep rendering, screens, and input handlers in client-only event subscribers;
  client classes must never load on a dedicated server.

### Registries
Everything in Minecraft lives in a registry. Always register objects; never
construct them at field initializer time outside a registry call. Use the
current NeoForge registry constants:

| Type | Registry |
|------|----------|
| Blocks | `BuiltInRegistries.BLOCK` |
| Items | `BuiltInRegistries.ITEM` |
| Entity types | `BuiltInRegistries.ENTITY_TYPE` |
| Block entity types | `BuiltInRegistries.BLOCK_ENTITY_TYPE` |
| Menu types | `BuiltInRegistries.MENU` |
| Sound events | `BuiltInRegistries.SOUND_EVENT` |
| Biomes | `Registries.BIOME` registry keys |

Do not copy older `Registry.BLOCK` / `Registry.ITEM` constants into 26.2 code;
those names are stale for the examples in this skill.

### ResourceLocation / Identifier
Every registry entry needs a namespaced ID:
```java
// NeoForge / vanilla Java
ResourceLocation id = ResourceLocation.fromNamespaceAndPath("mymod", "my_block");
```

---

## 5. Quick Patterns

See full patterns in `references/neoforge-api.md`.

```java
// Main mod class
@Mod(MyMod.MOD_ID)
public class MyMod {
    public static final String MOD_ID = "mymod";

    public MyMod(IEventBus modEventBus) {
        ModBlocks.BLOCKS.register(modEventBus);
        ModItems.ITEMS.register(modEventBus);
        modEventBus.addListener(this::commonSetup);
    }

    private void commonSetup(FMLCommonSetupEvent event) {
        // runs after all mods are registered
    }
}
```

```java
// Block registration
public class ModBlocks {
    public static final DeferredRegister<Block> BLOCKS =
        DeferredRegister.create(BuiltInRegistries.BLOCK, MyMod.MOD_ID);

    public static final DeferredBlock<Block> MY_BLOCK =
        BLOCKS.registerSimpleBlock("my_block",
            BlockBehaviour.Properties.of()
                .mapColor(MapColor.STONE)
                .strength(1.5f, 6.0f)
                .sound(SoundType.STONE)
                .requiresCorrectToolForDrops());
}
```

---

## 6. JSON Asset Templates

Always provide matching JSON assets for every registered block/item.
Codex should generate or update these files alongside Java code.

See `references/common-patterns.md` for full JSON templates for:
- Blockstate JSON
- Block model JSON (cube, slab, stairs, fence, door, trapdoor, etc.)
- Item model JSON
- Loot table JSON
- Recipe JSON (crafting_shaped, crafting_shapeless, smelting, blasting, stonecutting)
- Language file (`en_us.json`) entries
- Tag JSON

---

## 7. Data Generation

Prefer data generation over hand-authored JSON for maintainability.

```java
// NeoForge – register data gen providers in GatherDataEvent
@SubscribeEvent
public static void gatherData(GatherDataEvent event) {
    DataGenerator gen = event.getGenerator();
    PackOutput output = gen.getPackOutput();
    ExistingFileHelper helper = event.getExistingFileHelper();
    CompletableFuture<HolderLookup.Provider> lookupProvider = event.getLookupProvider();

    gen.addProvider(event.includeClient(), new ModBlockStateProvider(output, helper));
    gen.addProvider(event.includeClient(), new ModItemModelProvider(output, helper));
    gen.addProvider(event.includeServer(), new ModRecipeProvider(output, lookupProvider));
    gen.addProvider(event.includeServer(), new ModLootTableProvider(output, lookupProvider));
    gen.addProvider(event.includeServer(), new ModBlockTagsProvider(output, lookupProvider, helper));
}
```

Run data generation with `./gradlew runData`, then commit the generated files.

---

## 8. Common Tasks Checklist

When adding a **new block**:
- [ ] `Block` subclass (or use vanilla Block with properties)
- [ ] Register in `ModBlocks.BLOCKS`
- [ ] Register `BlockItem` in `ModItems.ITEMS`
- [ ] Blockstate JSON -> `assets/<modid>/blockstates/<name>.json`
- [ ] Block model JSON -> `assets/<modid>/models/block/<name>.json`
- [ ] Item model JSON -> `assets/<modid>/models/item/<name>.json` (or inherits from block)
- [ ] Texture PNG -> `assets/<modid>/textures/block/<name>.png`
- [ ] Loot table JSON -> `data/<modid>/loot_table/blocks/<name>.json`
- [ ] Tags -> `data/<modid>/tags/block/` and `tags/item/`
- [ ] Language entry in `en_us.json`
- [ ] Mine-with-correct-tool tag if hardness > 0

When adding a **new item**:
- [ ] `Item` subclass (or use `new Item(properties)`)
- [ ] Register in `ModItems`
- [ ] Item model JSON
- [ ] Texture PNG
- [ ] Language entry
- [ ] Creative tab registration with `BuildCreativeModeTabContentsEvent`
- [ ] Recipe JSON if craftable

When adding a **new entity**:
- [ ] Entity class (extends appropriate base: `Mob`, `Animal`, `TamableAnimal`, etc.)
- [ ] `EntityType` registration
- [ ] Client-only renderer class
- [ ] Client-only model class
- [ ] Register renderer in `EntityRenderersEvent.RegisterRenderers`
- [ ] Spawn egg item (optional)
- [ ] Spawn rules / biome modifier

---

## 9. Open-Source Conventions

- **License**: MIT - include a `LICENSE` file and an `SPDX-License-Identifier` header
- **Versioning**: semantic mod version plus the Minecraft target where useful (for example, `1.0.0+26.2`)
- **Changelog**: Keep `CHANGELOG.md` up to date with semver notes
- **Publishing**: Use `gradle-modrinth` or `curseforgegradle` plugins for CurseForge / Modrinth
- **CI**: GitHub Actions with `./gradlew build` and `./gradlew runGameTestServer`
- **PR conventions**: Keep PRs scoped to a single feature; include asset files with Java changes

---

## 10. References

- NeoForge API patterns and event system: `./references/neoforge-api.md`
- Blocks, items, recipes, commands, GUIs, datagen: `./references/common-patterns.md`
- NeoForge official docs: https://docs.neoforged.net/
- Minecraft Wiki (data formats): https://minecraft.wiki/w/Java_Edition_data_values
