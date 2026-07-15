# Minecraft Testing Layouts

Use these layouts as the default shape for testable projects.


## 1. GameTest Layout

```text
src/
  main/
    java/com/example/mymod/
      MyMod.java
      MyGameTests.java
    resources/
      META-INF/neoforge.mods.toml
      data/mymod/structure/
        empty.nbt
  test/
    java/com/example/mymod/
      CooldownManagerTest.java
```

Checklist:

- Keep pure unit tests in `src/test/java`
- Keep GameTest structure fixtures under committed `data/<modid>/structure/`
- Make the test namespace match the `@GameTest(template = "<namespace>:...")` usage
- Register each GameTest class on the NeoForge mod event bus
- Keep `src/main/resources/META-INF/neoforge.mods.toml` present in the mod layout

## 2. Validator Usage

```bash
./scripts/validate-test-layout.sh --root .
./scripts/validate-test-layout.sh --root . --strict
```

What it checks:

- build file exists
- test source roots exist
- JUnit Platform is enabled
- GameTests have committed structure fixtures that match referenced templates
- NeoForge GameTests include the metadata and entrypoints they need to run
