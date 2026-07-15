---
name: minecraft-testing
description: "Write automated tests for Minecraft 26.2 NeoForge mods. Covers JUnit 5 unit tests for non-Minecraft logic, NeoForge GameTests with GameTestHelper assertions, committed structure templates, event-bus registration, layout validation, and headless test execution. Use when Codex needs to design tests, add JUnit or NeoForge GameTests, validate test project structure, or diagnose missing GameTest templates and registration."
---

# Minecraft Testing Skill

Use plain JUnit for isolated logic and NeoForge GameTests when behavior requires
registries, blocks, entities, or a running game test environment.

| Approach | Best for | Starts Minecraft |
|---|---|---|
| JUnit 5 | Parsing, state machines, cooldowns, serialization | No |
| NeoForge GameTests | Block, entity, registry, and world interaction | Yes |

### Routing Boundaries
- `Use when`: the task is designing, implementing, or validating automated tests for a NeoForge mod.
- `Do not use when`: the task is implementing gameplay behavior rather than testing it (`minecraft-modding`).
- `Do not use when`: the task is release publishing or general CI governance (`minecraft-ci-release`).

## Bundled Resources

- Read `references/test-layouts.md` when choosing source and resource paths.
- Run `./scripts/validate-test-layout.sh --root <project>` before copying a test
  layout into a downstream project.
- Use `--strict` when warnings must fail a CI job.

The validator checks build/test roots, JUnit Platform configuration, literal
GameTest template paths, NeoForge metadata, and GameTest class registration. It
does not compile the downstream project or replace `runGameTestServer`.

## JUnit 5

Keep logic that does not require Minecraft classes in ordinary unit-testable
types. Inject time, randomness, and filesystem access instead of sleeping or
mutating global state.

### Gradle configuration

```kotlin
dependencies {
    testImplementation("org.junit.jupiter:junit-jupiter:5.11.0")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
}

tasks.test {
    useJUnitPlatform()
    testLogging {
        events("passed", "skipped", "failed")
    }
}
```

### Unit-test pattern

```java
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import org.junit.jupiter.api.Test;

class CooldownManagerTest {
    @Test
    void expiresAtConfiguredDeadline() {
        Clock clock = Clock.fixed(Instant.parse("2026-07-15T00:00:00Z"), ZoneOffset.UTC);
        CooldownManager manager = new CooldownManager(Duration.ofSeconds(5), clock);

        manager.start("player-id");

        assertTrue(manager.isActive("player-id"));
        assertFalse(manager.isActive("missing-player"));
    }
}
```

## NeoForge GameTests

GameTests place a committed structure template, execute server-side test code,
and finish only when `GameTestHelper.succeed()` is called or an assertion fails.

### Register the test class

```java
@Mod(MyMod.MOD_ID)
public final class MyMod {
    public static final String MOD_ID = "mymod";

    public MyMod(IEventBus modEventBus) {
        modEventBus.register(MyGameTests.class);
    }
}
```

### Define a GameTest

```java
import net.minecraft.core.BlockPos;
import net.minecraft.gametest.framework.GameTest;
import net.minecraft.gametest.framework.GameTestHelper;
import net.minecraft.world.level.block.Blocks;
import net.neoforged.neoforge.gametest.GameTestHolder;
import net.neoforged.neoforge.gametest.PrefixGameTestTemplate;

@GameTestHolder("mymod")
@PrefixGameTestTemplate(false)
public final class MyGameTests {
    @GameTest(template = "mymod:empty", timeoutTicks = 100)
    public static void placesExpectedBlock(GameTestHelper helper) {
        BlockPos position = new BlockPos(1, 1, 1);
        helper.setBlock(position, Blocks.GOLD_BLOCK);
        helper.assertBlockPresent(Blocks.GOLD_BLOCK, position);
        helper.succeed();
    }
}
```

For Minecraft 26.2 resources, place the template at:

`src/main/resources/data/mymod/structure/empty.nbt`

Keep literal `@GameTest(template = "namespace:path")` values aligned with
`data/<modid>/structure/<path>.nbt`. The validator checks literal values exactly.
When a test uses a constant or computed template name, the validator reports a
warning because static path matching is not reliable; verify that case with the
runtime GameTest server.

## Assertions And Control Flow

```java
helper.assertBlockPresent(Blocks.GOLD_BLOCK, position);
helper.assertBlockNotPresent(Blocks.TNT, position);
helper.assertEntityPresent(EntityType.ZOMBIE, position, 1.0);
helper.assertEntityNotPresent(EntityType.CREEPER);
helper.assertContainerContains(position, Items.DIAMOND);

helper.runAfterDelay(5, () -> {
    helper.assertBlockPresent(Blocks.GOLD_BLOCK, position);
    helper.succeed();
});
```

Every success path must call `helper.succeed()`. Prefer a short timeout and a
single behavior per test so failures remain diagnosable.

## Workflow

1. Put pure logic in `src/test/java` or `src/test/kotlin` and enable JUnit Platform.
2. Put NeoForge GameTest classes in a scanned Java/Kotlin source root.
3. Commit templates under `data/<modid>/structure/`.
4. Register each GameTest class on the mod event bus.
5. Run the layout validator:

   ```bash
   ./scripts/validate-test-layout.sh --root . --strict
   ```

6. Run downstream tests from the Minecraft project, not from this skills repository:

   ```bash
   ./gradlew test
   ./gradlew runGameTestServer
   ```

7. Treat a validator pass as structural preflight only; the Gradle test tasks are
   the authority for compilation and runtime behavior.

## References

- NeoForge GameTest documentation: https://docs.neoforged.net/docs/misc/gametest/
- JUnit 5 user guide: https://junit.org/junit5/docs/current/user-guide/
