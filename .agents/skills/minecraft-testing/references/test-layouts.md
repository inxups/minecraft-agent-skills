# Minecraft 26.2 Testing Layouts

## JUnit And GameTest Layout

```text
src/
  main/
    java/com/example/mymod/
      MyMod.java
      gametest/
        JavaGameTestInstance.java
        ModGameTestTypes.java
        MyGameTests.java
    resources/
      META-INF/neoforge.mods.toml
      data/mymod/
        structure/
          empty.nbt
        test_environment/
          default.json
        test_instance/
          layout_smoke.json
  test/
    java/com/example/mymod/
      CooldownManagerTest.java
```

Checklist:

- Keep pure unit tests in `src/test/java` or `src/test/kotlin`.
- Enable JUnit Platform in the Gradle test task.
- Keep GameTest instances under `data/<namespace>/test_instance/`.
- Keep optional environments under `data/<namespace>/test_environment/`.
- Commit binary structure templates under `data/<namespace>/structure/`.
- Register Java-backed tests through `RegisterGameTestsEvent`.
- Register any custom `GameTestInstance` codec in
  `Registries.TEST_INSTANCE_TYPE` before dynamic test registries load.
- Keep `src/main/resources/META-INF/neoforge.mods.toml` in a NeoForge mod.

## Resource Reference Rules

For this instance:

```json
{
  "environment": "mymod:default",
  "function": "minecraft:always_pass",
  "max_ticks": 1,
  "required": false,
  "structure": "mymod:rooms/empty",
  "type": "minecraft:function"
}
```

the validator expects:

```text
data/mymod/test_environment/default.json
data/mymod/structure/rooms/empty.nbt
```

References in the `minecraft` namespace or another dependency namespace are
treated as external. Confirm them against the downstream runtime.

## Migration From Annotation-Based Tests

Remove all of the following from a 26.2 project:

- the old `GameTest` method annotation import;
- GameTest holder or template-prefix annotations;
- `modBus.register(MyGameTests.class)` used only for annotation scanning;
- template arguments embedded in annotations.

Replace them with `test_instance` JSON or a `RegisterGameTestsEvent` handler.
The old annotation types are not a compatibility layer for 26.2.

## Validator Usage

```bash
./scripts/validate-test-layout.sh --root .
./scripts/validate-test-layout.sh --root . --strict
```

The validator checks:

- build file and test source roots;
- JUnit Platform configuration;
- JSON syntax for test instances and environments;
- local structure and environment references;
- NeoForge metadata;
- Java-backed GameTest registration through `RegisterGameTestsEvent`;
- removed annotation-based API usage.

It cannot prove that a programmatically constructed `Identifier` points to an
existing structure. Runtime verification with `runGameTestServer` remains
required.
