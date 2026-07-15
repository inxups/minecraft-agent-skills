# Common NeoForge 26.2 Patterns

Use these patterns with Minecraft `26.2`, Java `25`, and official names. Verify
the exact NeoForge artifact in the downstream build before changing code.

## Complete Simple Block

Registry declarations:

```java
public final class ModBlocks {
    public static final DeferredRegister.Blocks BLOCKS =
        DeferredRegister.createBlocks(MyMod.MOD_ID);

    public static final DeferredBlock<Block> POLISHED_SLATE =
        BLOCKS.registerSimpleBlock("polished_slate", properties -> properties
            .mapColor(MapColor.COLOR_GRAY)
            .strength(2.0F, 6.0F)
            .sound(SoundType.DEEPSLATE)
            .requiresCorrectToolForDrops());
}

public final class ModItems {
    public static final DeferredRegister.Items ITEMS =
        DeferredRegister.createItems(MyMod.MOD_ID);

    public static final DeferredItem<BlockItem> POLISHED_SLATE =
        ITEMS.registerSimpleBlockItem(ModBlocks.POLISHED_SLATE);
}
```

Required resource set:

```text
assets/mymod/blockstates/polished_slate.json
assets/mymod/items/polished_slate.json
assets/mymod/models/block/polished_slate.json
assets/mymod/models/item/polished_slate.json
assets/mymod/textures/block/polished_slate.png
assets/mymod/lang/en_us.json
data/mymod/loot_table/blocks/polished_slate.json
data/mymod/recipe/polished_slate.json
data/minecraft/tags/block/mineable/pickaxe.json
data/minecraft/tags/block/needs_stone_tool.json
```

`assets/mymod/blockstates/polished_slate.json`:

```json
{
  "variants": {
    "": {
      "model": "mymod:block/polished_slate"
    }
  }
}
```

`assets/mymod/models/block/polished_slate.json`:

```json
{
  "parent": "minecraft:block/cube_all",
  "textures": {
    "all": "mymod:block/polished_slate"
  }
}
```

`assets/mymod/items/polished_slate.json`:

```json
{
  "model": {
    "model": "mymod:item/polished_slate",
    "type": "minecraft:model"
  }
}
```

`assets/mymod/models/item/polished_slate.json`:

```json
{
  "parent": "mymod:block/polished_slate"
}
```

`data/mymod/loot_table/blocks/polished_slate.json`:

```json
{
  "type": "minecraft:block",
  "pools": [
    {
      "conditions": [
        {
          "condition": "minecraft:survives_explosion"
        }
      ],
      "entries": [
        {
          "type": "minecraft:item",
          "name": "mymod:polished_slate"
        }
      ],
      "rolls": 1.0
    }
  ],
  "random_sequence": "mymod:blocks/polished_slate"
}
```

`data/mymod/recipe/polished_slate.json`:

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
    "id": "mymod:polished_slate"
  },
  "type": "minecraft:crafting_shaped"
}
```

Tags targeting vanilla registries belong under the `minecraft` namespace.

`data/minecraft/tags/block/mineable/pickaxe.json`:

```json
{
  "replace": false,
  "values": [
    "mymod:polished_slate"
  ]
}
```

`data/minecraft/tags/block/needs_stone_tool.json`:

```json
{
  "replace": false,
  "values": [
    "mymod:polished_slate"
  ]
}
```

`assets/mymod/lang/en_us.json`:

```json
{
  "block.mymod.polished_slate": "Polished Slate"
}
```

## Items, Tools, Armor, And Food

Simple and custom items receive an ID-bearing `Item.Properties` from the
specialized register.

```java
public static final DeferredItem<Item> RAW_SHARD =
    ITEMS.registerSimpleItem("raw_shard", properties -> properties.stacksTo(64));

public static final DeferredItem<MagicWandItem> MAGIC_WAND =
    ITEMS.registerItem("magic_wand", MagicWandItem::new,
        properties -> properties.stacksTo(1).durability(256));

public static final DeferredItem<Item> IRON_HAMMER =
    ITEMS.registerItem("iron_hammer", properties ->
        new Item(properties.pickaxe(ToolMaterial.IRON, 5.0F, -3.2F)));

public static final DeferredItem<Item> IRON_CHESTPLATE =
    ITEMS.registerItem("iron_chestplate", properties -> new Item(
        properties.humanoidArmor(ArmorMaterials.IRON, ArmorType.CHESTPLATE)));
```

A food with an effect uses separate food and consumable components:

```java
public static final DeferredItem<Item> GLOW_BERRY_TART =
    ITEMS.registerItem("glow_berry_tart", properties -> {
        FoodProperties food = new FoodProperties.Builder()
            .nutrition(6)
            .saturationModifier(0.8F)
            .build();
        Consumable consumable = Consumable.builder()
            .onConsume(new ApplyStatusEffectsConsumeEffect(
                new MobEffectInstance(MobEffects.NIGHT_VISION, 600, 0)))
            .build();
        return new Item(properties.food(food, consumable));
    });
```

Each item needs a client item definition and model. For a generated texture:

```json
{
  "model": {
    "model": "mymod:item/raw_shard",
    "type": "minecraft:model"
  }
}
```

```json
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "mymod:item/raw_shard"
  }
}
```

## Creative Tab Contents

```java
@EventBusSubscriber(modid = MyMod.MOD_ID)
public final class CreativeTabEvents {
    @SubscribeEvent
    public static void addCreativeTabItems(BuildCreativeModeTabContentsEvent event) {
        if (event.getTabKey() == CreativeModeTabs.INGREDIENTS) {
            event.accept(ModItems.RAW_SHARD);
        }
    }
}
```

## Entity Registration And Attributes

```java
public final class ModEntities {
    public static final DeferredRegister.Entities ENTITY_TYPES =
        DeferredRegister.createEntities(MyMod.MOD_ID);

    public static final DeferredHolder<EntityType<?>, EntityType<SlateGolem>>
        SLATE_GOLEM = ENTITY_TYPES.registerEntityType(
            "slate_golem",
            SlateGolem::new,
            MobCategory.CREATURE,
            builder -> builder.sized(1.2F, 2.7F)
                .clientTrackingRange(10)
                .updateInterval(3)
        );
}

@EventBusSubscriber(modid = MyMod.MOD_ID)
public final class EntityEvents {
    @SubscribeEvent
    public static void createAttributes(EntityAttributeCreationEvent event) {
        event.put(ModEntities.SLATE_GOLEM.get(), SlateGolem.createAttributes().build());
    }
}

@EventBusSubscriber(modid = MyMod.MOD_ID, value = Dist.CLIENT)
public final class EntityClientEvents {
    @SubscribeEvent
    public static void registerRenderers(EntityRenderersEvent.RegisterRenderers event) {
        event.registerEntityRenderer(ModEntities.SLATE_GOLEM.get(), SlateGolemRenderer::new);
    }
}
```

Use an explicit spawn reason when creating an entity outside the constructor:

```java
SlateGolem golem = ModEntities.SLATE_GOLEM.get().create(
    serverLevel,
    EntitySpawnReason.COMMAND
);
```

## Commands

Permission predicates use named permission levels.

```java
@EventBusSubscriber(modid = MyMod.MOD_ID)
public final class CommandEvents {
    @SubscribeEvent
    public static void registerCommands(RegisterCommandsEvent event) {
        event.getDispatcher().register(Commands.literal("mymod")
            .then(Commands.literal("reload")
                .requires(Commands.hasPermission(Commands.LEVEL_GAMEMASTERS))
                .executes(context -> {
                    context.getSource().sendSuccess(
                        () -> Component.literal("My Mod reloaded"), true);
                    return Command.SINGLE_SUCCESS;
                })));
    }
}
```

## Block Entity Persistence And Capability

```java
public final class StorageBlockEntity extends BlockEntity {
    private final ItemStacksResourceHandler inventory =
        new ItemStacksResourceHandler(9) {
            @Override
            protected void onContentsChanged(int index, ItemStack previousContents) {
                setChanged();
            }
        };

    public StorageBlockEntity(BlockPos pos, BlockState state) {
        super(ModBlockEntities.STORAGE.get(), pos, state);
    }

    public ResourceHandler<ItemResource> inventory() {
        return inventory;
    }

    @Override
    protected void saveAdditional(ValueOutput output) {
        super.saveAdditional(output);
        inventory.serialize(output.child("inventory"));
    }

    @Override
    protected void loadAdditional(ValueInput input) {
        super.loadAdditional(input);
        inventory.deserialize(input.childOrEmpty("inventory"));
    }
}
```

```java
public static final DeferredHolder<BlockEntityType<?>, BlockEntityType<StorageBlockEntity>>
    STORAGE = BLOCK_ENTITY_TYPES.register("storage", () ->
        new BlockEntityType<>(StorageBlockEntity::new, ModBlocks.STORAGE.get()));
```

```java
@SubscribeEvent
public static void registerCapabilities(RegisterCapabilitiesEvent event) {
    event.registerBlockEntity(
        Capabilities.Item.BLOCK,
        ModBlockEntities.STORAGE.get(),
        (blockEntity, side) -> blockEntity.inventory()
    );
}
```

## Model Data Generation

The 26.2 vanilla `ModelProvider` creates blockstate JSON, model JSON, and
`assets/<namespace>/items` definitions together.

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
        blockModels.createTrivialCube(ModBlocks.POLISHED_SLATE.get());
        itemModels.generateFlatItem(ModItems.RAW_SHARD.get(), ModelTemplates.FLAT_ITEM);
    }
}
```

Register it only in the client data event:

```java
@SubscribeEvent
public static void gatherClientData(GatherDataEvent.Client event) {
    event.createProvider(output -> new ModModelProvider(output, MyMod.MOD_ID));
}
```

## Recipe Data Generation

In 26.2, a concrete provider extends `RecipeProvider`, and a nested runner
adapts it to `DataProvider`.

```java
public final class ModRecipeProvider extends RecipeProvider {
    private ModRecipeProvider(HolderLookup.Provider registries, RecipeOutput output) {
        super(registries, output);
    }

    @Override
    protected void buildRecipes() {
        shaped(RecipeCategory.BUILDING_BLOCKS, ModBlocks.POLISHED_SLATE.get(), 4)
            .define('S', Blocks.STONE)
            .pattern("SS")
            .pattern("SS")
            .unlockedBy("has_stone", has(Blocks.STONE))
            .save(output);
    }

    public static final class Runner extends RecipeProvider.Runner {
        public Runner(
            PackOutput output,
            CompletableFuture<HolderLookup.Provider> registries
        ) {
            super(output, registries);
        }

        @Override
        protected RecipeProvider createRecipeProvider(
            HolderLookup.Provider registries,
            RecipeOutput output
        ) {
            return new ModRecipeProvider(registries, output);
        }

        @Override
        public String getName() {
            return "My Mod recipes";
        }
    }
}
```

Register it only in the server data event:

```java
@SubscribeEvent
public static void gatherServerData(GatherDataEvent.Server event) {
    event.createProvider(ModRecipeProvider.Runner::new);
}
```

## Recipe Ingredient Forms

Minecraft 26.2 accepts item IDs, tag IDs, or lists directly. Do not wrap a
basic ingredient in an `item` object.

Single item:

```json
"minecraft:iron_ingot"
```

Tag:

```json
"#minecraft:planks"
```

Alternatives:

```json
[
  "minecraft:coal",
  "minecraft:charcoal"
]
```

## Resource Review Checklist

- Every registered item has `assets/<modid>/items/<id>.json`.
- Every item definition points to an existing item model.
- Every referenced model texture exists under `textures/`.
- Every non-air block has a blockstate and expected loot table.
- Recipe ingredients use the 26.2 scalar/list form.
- Tags use singular registry directories such as `tags/block` and `tags/item`.
- JSON is valid and formatted with two spaces.
- Datagen output is reviewed and committed rather than accepted blindly.
