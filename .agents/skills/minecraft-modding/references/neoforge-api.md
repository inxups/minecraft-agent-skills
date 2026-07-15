# NeoForge 26.2 API Patterns

These patterns target Minecraft `26.2`, Java `25`, and official names. Check the
downstream project's resolved NeoForge artifact before applying a signature
unchanged. The reference artifact used for this audit is
`net.neoforged:neoforge:26.2.0.15-beta`.

## Mod Metadata

`src/main/resources/META-INF/neoforge.mods.toml`:

```toml
modLoader="javafml"
loaderVersion="[11,)"
license="MIT"

[[mods]]
modId="mymod"
version="${file.jarVersion}"
displayName="My Mod"
description='''A NeoForge 26.2 mod.'''

[[dependencies.mymod]]
modId="neoforge"
type="required"
versionRange="[26.2.0.15-beta,)"
ordering="NONE"
side="BOTH"

[[dependencies.mymod]]
modId="minecraft"
type="required"
versionRange="[26.2,26.3)"
ordering="NONE"
side="BOTH"
```

Keep the loader and NeoForge ranges aligned with the dependency metadata in
the target project. Do not copy these lower bounds into a differently pinned
project without checking its resolved loader.

## Entry Point And Event Buses

```java
@Mod(MyMod.MOD_ID)
public final class MyMod {
    public static final String MOD_ID = "mymod";

    public MyMod(IEventBus modBus, ModContainer container) {
        ModBlocks.BLOCKS.register(modBus);
        ModItems.ITEMS.register(modBus);
        ModEntities.ENTITY_TYPES.register(modBus);
        ModBlockEntities.BLOCK_ENTITY_TYPES.register(modBus);
        ModMenus.MENU_TYPES.register(modBus);

        container.registerConfig(ModConfig.Type.COMMON, ModConfigSpecHolder.SPEC);
    }
}
```

There are two event buses:

- `IModBusEvent` implementations are delivered through the mod container's
  event bus.
- Gameplay events are delivered through `NeoForge.EVENT_BUS`.

The 26.2 `@EventBusSubscriber` annotation routes handlers by event type and has
no bus field. Its methods must be static.

```java
@EventBusSubscriber(modid = MyMod.MOD_ID)
public final class Events {
    @SubscribeEvent
    public static void commonSetup(FMLCommonSetupEvent event) {
        event.enqueueWork(ModBootstrap::finishRegistration);
    }

    @SubscribeEvent
    public static void playerTick(PlayerTickEvent.Post event) {
        Player player = event.getEntity();
        ModEffects.tick(player);
    }
}

@EventBusSubscriber(modid = MyMod.MOD_ID, value = Dist.CLIENT)
public final class ClientEvents {
    @SubscribeEvent
    public static void registerRenderers(EntityRenderersEvent.RegisterRenderers event) {
        event.registerEntityRenderer(ModEntities.MY_MOB.get(), MyMobRenderer::new);
    }
}
```

## Deferred Registries

Use specialized block, item, and entity registers so IDs are installed before
constructors run.

```java
public final class ModBlocks {
    public static final DeferredRegister.Blocks BLOCKS =
        DeferredRegister.createBlocks(MyMod.MOD_ID);

    public static final DeferredBlock<Block> MACHINE =
        BLOCKS.registerBlock("machine", MachineBlock::new,
            properties -> properties.strength(3.0F).requiresCorrectToolForDrops());
}

public final class ModItems {
    public static final DeferredRegister.Items ITEMS =
        DeferredRegister.createItems(MyMod.MOD_ID);

    public static final DeferredItem<BlockItem> MACHINE =
        ITEMS.registerSimpleBlockItem(ModBlocks.MACHINE);

    public static final DeferredItem<Item> INGOT =
        ITEMS.registerSimpleItem("ingot", properties -> properties.stacksTo(64));

    public static final DeferredItem<Item> SWORD =
        ITEMS.registerItem("sword", properties ->
            new Item(properties.sword(ToolMaterial.IRON, 3.0F, -2.4F)));

    public static final DeferredItem<Item> HELMET =
        ITEMS.registerItem("helmet", properties -> new Item(
            properties.humanoidArmor(ArmorMaterials.IRON, ArmorType.HELMET)));
}

public final class ModEntities {
    public static final DeferredRegister.Entities ENTITY_TYPES =
        DeferredRegister.createEntities(MyMod.MOD_ID);

    public static final DeferredHolder<EntityType<?>, EntityType<MyMob>> MY_MOB =
        ENTITY_TYPES.registerEntityType("my_mob", MyMob::new, MobCategory.CREATURE,
            builder -> builder.sized(0.6F, 1.8F)
                .clientTrackingRange(10)
                .updateInterval(3));
}
```

If a mob creates offspring, pass an explicit reason:

```java
@Override
public MyMob getBreedOffspring(ServerLevel level, AgeableMob partner) {
    return ModEntities.MY_MOB.get().create(level, EntitySpawnReason.BREEDING);
}
```

## Food And Consume Effects

Status effects live on `Consumable`, not on `FoodProperties.Builder`.

```java
public static final DeferredItem<Item> TONIC = ITEMS.registerItem("tonic", properties -> {
    FoodProperties food = new FoodProperties.Builder()
        .nutrition(4)
        .saturationModifier(0.6F)
        .alwaysEdible()
        .build();

    Consumable consumable = Consumable.builder()
        .onConsume(new ApplyStatusEffectsConsumeEffect(
            new MobEffectInstance(MobEffects.REGENERATION, 100, 0), 1.0F))
        .build();

    return new Item(properties.food(food, consumable));
});
```

## Block Entities And Item Transfer

`BlockEntityType.Builder` is absent in 26.2. Construct the type with its
factory and valid blocks.

```java
public final class ModBlockEntities {
    public static final DeferredRegister<BlockEntityType<?>> BLOCK_ENTITY_TYPES =
        DeferredRegister.create(Registries.BLOCK_ENTITY_TYPE, MyMod.MOD_ID);

    public static final DeferredHolder<BlockEntityType<?>, BlockEntityType<MachineBlockEntity>>
        MACHINE = BLOCK_ENTITY_TYPES.register("machine", () ->
            new BlockEntityType<>(MachineBlockEntity::new, ModBlocks.MACHINE.get()));
}
```

Use NeoForge's transfer handler and the value I/O APIs for persistence.

```java
public final class MachineBlockEntity extends BlockEntity {
    private final ItemStacksResourceHandler inventory =
        new ItemStacksResourceHandler(9) {
            @Override
            protected void onContentsChanged(int index, ItemStack previousContents) {
                setChanged();
            }
        };

    public MachineBlockEntity(BlockPos pos, BlockState state) {
        super(ModBlockEntities.MACHINE.get(), pos, state);
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

Expose the handler during the mod-bus capability registration event:

```java
@SubscribeEvent
public static void registerCapabilities(RegisterCapabilitiesEvent event) {
    event.registerBlockEntity(
        Capabilities.Item.BLOCK,
        ModBlockEntities.MACHINE.get(),
        (blockEntity, side) -> blockEntity.inventory()
    );
}
```

When the available capability changes at runtime, call
`level.invalidateCapabilities(blockPos)`.

## Menus And Screens

The menu must add player slots explicitly.

```java
public final class MachineMenu extends AbstractContainerMenu {
    private final ContainerLevelAccess access;

    public MachineMenu(int containerId, Inventory playerInventory) {
        this(containerId, playerInventory, ContainerLevelAccess.NULL);
    }

    public MachineMenu(
        int containerId,
        Inventory playerInventory,
        ContainerLevelAccess access
    ) {
        super(ModMenus.MACHINE.get(), containerId);
        this.access = access;

        for (int row = 0; row < 3; row++) {
            for (int column = 0; column < 9; column++) {
                int index = column + row * 9 + 9;
                addSlot(new Slot(playerInventory, index,
                    8 + column * 18, 84 + row * 18));
            }
        }
        for (int column = 0; column < 9; column++) {
            addSlot(new Slot(playerInventory, column, 8 + column * 18, 142));
        }
    }

    @Override
    public boolean stillValid(Player player) {
        return access.evaluate((level, pos) ->
            player.distanceToSqr(Vec3.atCenterOf(pos)) <= 64.0, true);
    }
}
```

Minecraft 26.2 extracts GUI render state through `GuiGraphicsExtractor`.

```java
@OnlyIn(Dist.CLIENT)
public final class MachineScreen extends AbstractContainerScreen<MachineMenu> {
    private static final Identifier TEXTURE = Identifier.fromNamespaceAndPath(
        MyMod.MOD_ID, "textures/gui/machine.png");

    public MachineScreen(MachineMenu menu, Inventory inventory, Component title) {
        super(menu, inventory, title);
    }

    @Override
    public void extractBackground(
        GuiGraphicsExtractor graphics,
        int mouseX,
        int mouseY,
        float partialTick
    ) {
        super.extractBackground(graphics, mouseX, mouseY, partialTick);
        graphics.blit(RenderPipelines.GUI_TEXTURED, TEXTURE,
            leftPos, topPos, 0.0F, 0.0F,
            imageWidth, imageHeight, 256, 256);
    }
}

@EventBusSubscriber(modid = MyMod.MOD_ID, value = Dist.CLIENT)
public final class MenuClientEvents {
    @SubscribeEvent
    public static void registerScreens(RegisterMenuScreensEvent event) {
        event.register(ModMenus.MACHINE.get(), MachineScreen::new);
    }
}
```

## Custom Payloads

Payload IDs use `Identifier`. Play payload codecs use
`RegistryFriendlyByteBuf`.

```java
public record SetModePayload(int mode) implements CustomPacketPayload {
    public static final Type<SetModePayload> TYPE = new Type<>(
        Identifier.fromNamespaceAndPath(MyMod.MOD_ID, "set_mode"));

    public static final StreamCodec<RegistryFriendlyByteBuf, SetModePayload> CODEC =
        StreamCodec.composite(
            ByteBufCodecs.VAR_INT,
            SetModePayload::mode,
            SetModePayload::new
        );

    @Override
    public Type<? extends CustomPacketPayload> type() {
        return TYPE;
    }
}
```

Register common payload metadata on the mod bus. Handlers use the main thread
by default, so validate all client-supplied values before mutating server state.

```java
@SubscribeEvent
public static void registerPayloads(RegisterPayloadHandlersEvent event) {
    PayloadRegistrar registrar = event.registrar("1");
    registrar.playToServer(SetModePayload.TYPE, SetModePayload.CODEC,
        (payload, context) -> {
            ServerPlayer player = (ServerPlayer) context.player();
            if (payload.mode() >= 0 && payload.mode() <= 3) {
                ModModes.set(player, payload.mode());
            }
        });
}
```

Send server-bound payloads only from client code:

```java
ClientPacketDistributor.sendToServer(new SetModePayload(2));
```

For a client-bound payload, declare it without a common-side handler, then
register the handler in a client-only subscriber:

```java
@SubscribeEvent
public static void registerPayloads(RegisterPayloadHandlersEvent event) {
    event.registrar("1").playToClient(SyncModePayload.TYPE, SyncModePayload.CODEC);
}

@EventBusSubscriber(modid = MyMod.MOD_ID, value = Dist.CLIENT)
public final class ClientPayloadEvents {
    @SubscribeEvent
    public static void registerClientHandlers(RegisterClientPayloadHandlersEvent event) {
        event.register(SyncModePayload.TYPE,
            (payload, context) -> ClientModeState.set(payload.mode()));
    }
}
```

From server code:

```java
PacketDistributor.sendToPlayer(serverPlayer, new SyncModePayload(mode));
```

## Data Generation Events

Client and server generation are separate events in 26.2.

```java
@EventBusSubscriber(modid = MyMod.MOD_ID)
public final class DataEvents {
    @SubscribeEvent
    public static void gatherClient(GatherDataEvent.Client event) {
        event.createProvider(output -> new ModModelProvider(output, MyMod.MOD_ID));
    }

    @SubscribeEvent
    public static void gatherServer(GatherDataEvent.Server event) {
        event.createProvider(ModRecipeProvider.Runner::new);
        event.createProvider(ModLootTableProvider::new);
        event.createBlockAndItemTags(ModBlockTagsProvider::new, ModItemTagsProvider::new);
    }
}
```

`ModelProvider` writes block states, models, and client item definitions.
`RecipeProvider` itself is not a `DataProvider`; expose a nested subclass of
`RecipeProvider.Runner` as shown in `common-patterns.md`.

## Dedicated-Server Safety

- Never put `net.minecraft.client` imports in a common class.
- Mark client subscribers with `value = Dist.CLIENT`.
- Register client-bound payload handlers in
  `RegisterClientPayloadHandlersEvent`.
- Exercise `runServer` or `runGameTestServer` in the downstream project to
  catch classloading failures.
