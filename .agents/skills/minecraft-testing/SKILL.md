---
name: minecraft-testing
description: "Test Minecraft 26.2 NeoForge mods with JUnit 5 and registry-based GameTests, including structure fixtures, test instances, environments, Java handlers, layout validation, and headless execution."
---

# Minecraft Testing Skill

Use JUnit for isolated logic and NeoForge GameTests for behavior that needs a
loaded registry, server level, block, entity, capability, or structure.

| Approach | Best for | Starts Minecraft |
|---|---|---|
| JUnit 5 | Parsers, state machines, cooldowns, deterministic services | No |
| NeoForge GameTests | World interaction and registry-backed behavior | Yes |

### Routing Boundaries

- `Use when`: the task is designing, implementing, diagnosing, or validating
  tests for a NeoForge 26.2 mod.
- `Do not use when`: the task is gameplay implementation rather than its tests;
  use `minecraft-modding`.
- `Do not use when`: the task is release publishing or CI governance; use
  `minecraft-ci-release` after test commands are known.

## 26.2 Compatibility Rule

Minecraft 26.2 does not use annotation-scanned GameTest methods. GameTests are
entries in `Registries.TEST_INSTANCE`; environments are entries in
`Registries.TEST_ENVIRONMENT`. NeoForge exposes `RegisterGameTestsEvent` on the
mod bus for programmatic registration.

Reject examples that import old GameTest annotations or register a test class
for annotation scanning. They target an earlier API generation.

## Bundled Resources

- Read `references/test-layouts.md` for complete source/resource layouts.
- Run `./scripts/validate-test-layout.sh --root <project>` for structural
  preflight.
- Add `--strict` when warnings must fail CI.

The validator parses `test_instance` JSON, resolves local structure templates,
checks NeoForge metadata and Java event registration, and rejects removed API
surfaces. It does not compile or launch the downstream project.

## JUnit 5

Keep logic that does not require Minecraft classes in ordinary Java types.
Inject clocks, randomness, storage, and external services.

`build.gradle.kts`:

```kotlin
dependencies {
    testImplementation("org.junit.jupiter:junit-jupiter:5.11.4")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
}

tasks.test {
    useJUnitPlatform()
    testLogging {
        events("passed", "skipped", "failed")
    }
}
```

```java
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import org.junit.jupiter.api.Test;

final class CooldownManagerTest {
    @Test
    void expiresAtConfiguredDeadline() {
        Clock clock = Clock.fixed(
            Instant.parse("2026-07-15T00:00:00Z"),
            ZoneOffset.UTC
        );
        CooldownManager manager = new CooldownManager(Duration.ofSeconds(5), clock);

        manager.start("player-id");

        assertTrue(manager.isActive("player-id"));
        assertFalse(manager.isActive("missing-player"));
    }
}
```

## Data-Driven GameTest

The smallest 26.2 GameTest uses a committed structure and a test instance
resource. This example validates the GameTest layout itself with Minecraft's
built-in always-pass function.

`src/main/resources/data/mymod/test_instance/layout_smoke.json`:

```json
{
  "environment": "minecraft:default",
  "function": "minecraft:always_pass",
  "max_ticks": 1,
  "required": false,
  "setup_ticks": 1,
  "structure": "mymod:empty",
  "type": "minecraft:function"
}
```

Commit the binary template at:

```text
src/main/resources/data/mymod/structure/empty.nbt
```

An optional custom environment lives at
`data/mymod/test_environment/default.json`:

```json
{
  "definitions": [],
  "type": "minecraft:all_of"
}
```

Then change the instance's environment to `mymod:default`.

## Java-Backed GameTest

For direct Java assertions, register a serializable instance type once, then
register each test through `RegisterGameTestsEvent`.

The mod entry point attaches the custom instance codec registry:

```java
@Mod(MyMod.MOD_ID)
public final class MyMod {
    public static final String MOD_ID = "mymod";

    public MyMod(IEventBus modBus) {
        ModGameTestTypes.TEST_INSTANCE_TYPES.register(modBus);
    }
}
```

The instance codec stores common test data plus a handler ID:

```java
public final class JavaGameTestInstance extends GameTestInstance {
    public static final MapCodec<JavaGameTestInstance> CODEC =
        RecordCodecBuilder.mapCodec(instance -> instance.group(
            TestData.CODEC.forGetter(JavaGameTestInstance::testData),
            Identifier.CODEC.fieldOf("test").forGetter(JavaGameTestInstance::testId)
        ).apply(instance, JavaGameTestInstance::new));

    private final Identifier testId;

    public JavaGameTestInstance(
        TestData<Holder<TestEnvironmentDefinition<?>>> data,
        Identifier testId
    ) {
        super(data);
        this.testId = testId;
    }

    private TestData<Holder<TestEnvironmentDefinition<?>>> testData() {
        return info();
    }

    private Identifier testId() {
        return testId;
    }

    @Override
    public void run(GameTestHelper helper) {
        MyGameTests.run(testId, helper);
    }

    @Override
    public MapCodec<JavaGameTestInstance> codec() {
        return CODEC;
    }

    @Override
    protected MutableComponent typeDescription() {
        return Component.literal("mymod:java");
    }
}
```

Register that codec in the built-in instance-type registry:

```java
public final class ModGameTestTypes {
    public static final DeferredRegister<MapCodec<? extends GameTestInstance>>
        TEST_INSTANCE_TYPES = DeferredRegister.create(
            Registries.TEST_INSTANCE_TYPE,
            MyMod.MOD_ID
        );

    public static final DeferredHolder<
        MapCodec<? extends GameTestInstance>,
        MapCodec<JavaGameTestInstance>
    > JAVA = TEST_INSTANCE_TYPES.register("java", () -> JavaGameTestInstance.CODEC);
}
```

Register and implement the test:

```java
@EventBusSubscriber(modid = MyMod.MOD_ID)
public final class MyGameTests {
    private static final Identifier TEST_ID = Identifier.fromNamespaceAndPath(
        MyMod.MOD_ID, "places_expected_block");
    private static final Identifier ENVIRONMENT_ID = Identifier.fromNamespaceAndPath(
        MyMod.MOD_ID, "default");
    private static final Identifier STRUCTURE_ID = Identifier.fromNamespaceAndPath(
        MyMod.MOD_ID, "empty");

    @SubscribeEvent
    public static void registerTests(RegisterGameTestsEvent event) {
        Holder<TestEnvironmentDefinition<?>> environment =
            event.registerEnvironment(ENVIRONMENT_ID);
        TestData<Holder<TestEnvironmentDefinition<?>>> data =
            new TestData<>(environment, STRUCTURE_ID, 100, 0, true);
        event.registerTest(TEST_ID, new JavaGameTestInstance(data, TEST_ID));
    }

    public static void run(Identifier id, GameTestHelper helper) {
        if (!id.equals(TEST_ID)) {
            helper.fail("Unknown Java GameTest: " + id);
        }

        BlockPos position = new BlockPos(1, 1, 1);
        helper.setBlock(position, Blocks.GOLD_BLOCK);
        helper.assertBlockPresent(Blocks.GOLD_BLOCK, position);
        helper.succeed();
    }
}
```

Keep `data/mymod/structure/empty.nbt` committed. The event only fires while
GameTests are enabled, including the `gameTestServer` run configured by
ModDevGradle.

## Assertions And Timing

```java
helper.assertBlockPresent(Blocks.GOLD_BLOCK, position);
helper.assertBlockNotPresent(Blocks.TNT, position);
helper.assertEntityPresent(EntityTypes.ZOMBIE, position, 1.0);
helper.assertEntityNotPresent(EntityTypes.CREEPER);

helper.runAfterDelay(5, () -> {
    helper.assertBlockPresent(Blocks.GOLD_BLOCK, position);
    helper.succeed();
});
```

Every successful path must call `helper.succeed()`. Use short timeouts and test
one behavior per instance.

## Workflow

1. Put pure logic under `src/test/java` or `src/test/kotlin`.
2. Enable JUnit Platform.
3. Put GameTest resources under `src/main/resources/data/<modid>/`.
4. Commit every referenced `structure/*.nbt` template.
5. Register Java-backed tests with `RegisterGameTestsEvent`.
6. Run structural validation from the downstream project:

   ```bash
   ./scripts/validate-test-layout.sh --root . --strict
   ```

7. Run the authoritative test tasks in the downstream mod project:

   ```bash
   ./gradlew test
   ./gradlew runGameTestServer
   ```

Do not run Minecraft or Gradle from this skills repository.

## References

- Layouts and migration rules: `./references/test-layouts.md`
- NeoForge GameTest event source: https://github.com/neoforged/NeoForge
- JUnit 5 guide: https://junit.org/junit5/docs/current/user-guide/
