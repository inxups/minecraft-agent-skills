---
name: minecraft-modding
description: "Develop NeoForge mods for Minecraft 26.2 with Java 25, including project scaffolding, registries, events, networking, menus, resources, and data generation."
---

# Minecraft Modding Skill

## Overview

Use this skill for NeoForge `26.2` projects running Java `25`. The concrete
NeoForge artifact changes independently of this skill, so read the downstream
project's `gradle.properties`, `build.gradle`, and lockfiles before changing a
version-specific API or dependency.

### Routing Boundaries

- `Use when`: the task is NeoForge Java/Kotlin code, registries, events,
  networking, menus, capabilities, resources, or datagen wiring.
- `Do not use when`: the task is exclusively worldgen registry data; use
  `minecraft-world-generation`.
- `Do not use when`: the task is exclusively tests, release automation, or
  bitmap generation; use the corresponding focused skill.

## Baseline Checks

Before editing a downstream project, confirm all of these values:

```bash
rg -n "minecraft_version|neo_version|moddev|JavaLanguageVersion|VERSION_" \
  gradle.properties build.gradle build.gradle.kts settings.gradle settings.gradle.kts
./gradlew javaToolchains
```

For the reference baseline used by this skill:

| Surface | Baseline |
|---|---|
| Minecraft | `26.2` |
| Java | `25` |
| NeoForge | a `26.2.x` artifact verified in the target project |
| Build plugin | ModDevGradle `2.0.141` or the target project's verified update |
| Mappings | official names supplied by NeoForm/ModDevGradle |

Do not infer a loader artifact from the Minecraft number alone. Prefer the
version already resolved by the downstream project.

## Minimal ModDevGradle Project

`build.gradle`:

```groovy
plugins {
    id 'java'
    id 'net.neoforged.moddev' version '2.0.141'
}

group = mod_group_id
version = mod_version

base {
    archivesName = mod_id
}

java.toolchain.languageVersion = JavaLanguageVersion.of(25)

sourceSets.main.resources {
    srcDir 'src/generated/resources'
}

neoForge {
    version = project.neo_version
    validateAccessTransformers = true

    runs {
        client {
            client()
            systemProperty 'neoforge.enabledGameTestNamespaces', project.mod_id
        }
        server {
            server()
            programArgument '--nogui'
            systemProperty 'neoforge.enabledGameTestNamespaces', project.mod_id
        }
        gameTestServer {
            type = 'gameTestServer'
            systemProperty 'neoforge.enabledGameTestNamespaces', project.mod_id
        }
        data {
            data()
            programArguments.addAll '--mod', project.mod_id, '--all',
                '--output', file('src/generated/resources').absolutePath,
                '--existing', file('src/main/resources').absolutePath
        }
    }

    mods {
        mymod {
            sourceSet sourceSets.main
        }
    }
}

tasks.withType(JavaCompile).configureEach {
    options.encoding = 'UTF-8'
    options.release = 25
}
```

`gradle.properties`:

```properties
org.gradle.jvmargs=-Xmx2G
org.gradle.caching=true
org.gradle.configuration-cache=true

mod_id=mymod
mod_group_id=com.example.mymod
mod_version=1.0.0+26.2
minecraft_version=26.2
neo_version=26.2.0.15-beta
```

The `neo_version` above is the verified reference artifact at the time this
skill was audited. Recheck NeoForge Maven metadata before creating a new
project and do not silently overwrite a downstream project's pin.

## Project Layout

```text
src/
  main/
    java/com/example/mymod/
      MyMod.java
      registry/
      event/
      client/
      datagen/
    resources/
      META-INF/neoforge.mods.toml
      assets/mymod/
        blockstates/
        items/
        models/block/
        models/item/
        textures/block/
        textures/item/
        lang/en_us.json
      data/mymod/
        loot_table/blocks/
        recipe/
        tags/block/
        tags/item/
  generated/resources/
```

Minecraft 26.2 item rendering uses both
`assets/<namespace>/items/<id>.json` and the model in
`assets/<namespace>/models/item/<id>.json`. Generate or author both.

## Mod Entry Point And Registries

```java
@Mod(MyMod.MOD_ID)
public final class MyMod {
    public static final String MOD_ID = "mymod";

    public MyMod(IEventBus modBus) {
        ModBlocks.BLOCKS.register(modBus);
        ModItems.ITEMS.register(modBus);
        ModEntities.ENTITY_TYPES.register(modBus);
    }
}
```

Use the specialized helpers. They assign each block/item/entity's
`ResourceKey` to its properties or builder before construction.

```java
public final class ModBlocks {
    public static final DeferredRegister.Blocks BLOCKS =
        DeferredRegister.createBlocks(MyMod.MOD_ID);

    public static final DeferredBlock<Block> MY_BLOCK =
        BLOCKS.registerSimpleBlock("my_block", properties -> properties
            .mapColor(MapColor.STONE)
            .strength(1.5F, 6.0F)
            .sound(SoundType.STONE)
            .requiresCorrectToolForDrops());
}

public final class ModItems {
    public static final DeferredRegister.Items ITEMS =
        DeferredRegister.createItems(MyMod.MOD_ID);

    public static final DeferredItem<BlockItem> MY_BLOCK =
        ITEMS.registerSimpleBlockItem(ModBlocks.MY_BLOCK);

    public static final DeferredItem<Item> MY_ITEM =
        ITEMS.registerSimpleItem("my_item", properties -> properties.stacksTo(16));

    public static final DeferredItem<Item> MY_SWORD =
        ITEMS.registerItem("my_sword", properties ->
            new Item(properties.sword(ToolMaterial.IRON, 3.0F, -2.4F)));
}

public final class ModEntities {
    public static final DeferredRegister.Entities ENTITY_TYPES =
        DeferredRegister.createEntities(MyMod.MOD_ID);

    public static final DeferredHolder<EntityType<?>, EntityType<MyMob>> MY_MOB =
        ENTITY_TYPES.registerEntityType("my_mob", MyMob::new, MobCategory.CREATURE,
            builder -> builder.sized(0.6F, 1.8F));
}
```

Use `net.minecraft.resources.Identifier` for namespaced identifiers:

```java
Identifier id = Identifier.fromNamespaceAndPath(MyMod.MOD_ID, "my_block");
```

## Event Routing

`@EventBusSubscriber` has no bus selector in the 26.2 loader. Static handlers
for `IModBusEvent` types route to the mod bus; other event types route to
`NeoForge.EVENT_BUS`. Use `value = Dist.CLIENT` to prevent client classes from
loading on a dedicated server.

```java
@EventBusSubscriber(modid = MyMod.MOD_ID)
public final class ModEvents {
    @SubscribeEvent
    public static void registerCapabilities(RegisterCapabilitiesEvent event) {
        event.registerBlockEntity(
            Capabilities.Item.BLOCK,
            ModBlockEntities.MY_BLOCK_ENTITY.get(),
            (blockEntity, side) -> blockEntity.inventory()
        );
    }

    @SubscribeEvent
    public static void registerCommands(RegisterCommandsEvent event) {
        event.getDispatcher().register(Commands.literal("mymod")
            .requires(Commands.hasPermission(Commands.LEVEL_GAMEMASTERS))
            .executes(context -> 1));
    }
}

@EventBusSubscriber(modid = MyMod.MOD_ID, value = Dist.CLIENT)
public final class ClientEvents {
    @SubscribeEvent
    public static void registerScreens(RegisterMenuScreensEvent event) {
        event.register(ModMenus.MY_MENU.get(), MyScreen::new);
    }
}
```

## Data Generation

`GatherDataEvent` is abstract in 26.2. Subscribe separately to its `Client` and
`Server` variants. Providers are always included in the corresponding event.

```java
@EventBusSubscriber(modid = MyMod.MOD_ID)
public final class ModDataGenerators {
    @SubscribeEvent
    public static void gatherClientData(GatherDataEvent.Client event) {
        event.createProvider(output -> new ModModelProvider(output, MyMod.MOD_ID));
    }

    @SubscribeEvent
    public static void gatherServerData(GatherDataEvent.Server event) {
        event.createProvider(ModRecipeProvider.Runner::new);
        event.createProvider(ModLootTableProvider::new);
        event.createBlockAndItemTags(ModBlockTagsProvider::new, ModItemTagsProvider::new);
    }
}
```

Use vanilla `ModelProvider` for block states, block models, item models, and the
new client item definition files:

```java
public final class ModModelProvider extends ModelProvider {
    public ModModelProvider(PackOutput output, String modId) {
        super(output, modId);
    }

    @Override
    protected void registerModels(
        BlockModelGenerators blockModels,
        ItemModelGenerators itemModels
    ) {
        blockModels.createTrivialCube(ModBlocks.MY_BLOCK.get());
        itemModels.generateFlatItem(ModItems.MY_ITEM.get(), ModelTemplates.FLAT_ITEM);
    }
}
```

Run datagen in the downstream mod, inspect the diff, and commit generated
resources:

```bash
./gradlew runData
git diff -- src/generated/resources src/main/resources
```

## Minimal Resource Pair

`assets/mymod/items/my_item.json`:

```json
{
  "model": {
    "model": "mymod:item/my_item",
    "type": "minecraft:model"
  }
}
```

`assets/mymod/models/item/my_item.json`:

```json
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "mymod:item/my_item"
  }
}
```

Recipe ingredients are identifier strings, tag strings, or lists in 26.2.

```json
{
  "category": "building",
  "key": {
    "S": "minecraft:stone"
  },
  "pattern": [
    "SS",
    "SS"
  ],
  "result": {
    "count": 4,
    "id": "mymod:my_block"
  },
  "type": "minecraft:crafting_shaped"
}
```

## Implementation Checklist

- Register through a deferred register and attach it to the injected mod bus.
- Keep client imports under client-only entrypoints or subscribers.
- Add every required item definition, model, texture, language entry, loot table,
  recipe, and tag together with its Java registration.
- Use `ValueInput` and `ValueOutput` for block entity persistence.
- Use `ItemStacksResourceHandler` and `RegisterCapabilitiesEvent` for item
  transfer capabilities.
- Use `EntitySpawnReason` with entity creation helpers that require a reason.
- Prefer datagen, then review generated JSON against the resolved 26.2 runtime.

## Verification

Run these in the downstream mod project, never in this skills repository:

```bash
./gradlew compileJava
./gradlew runData
./gradlew build
./gradlew runGameTestServer
```

Inspect `latest.log` for missing registry keys, codecs, models, textures, and
dedicated-server classloading failures.

## References

- Detailed NeoForge APIs: `./references/neoforge-api.md`
- Complete common patterns and resources: `./references/common-patterns.md`
- NeoForge documentation: https://docs.neoforged.net/
- NeoForge Maven: https://maven.neoforged.net/releases/net/neoforged/neoforge/
