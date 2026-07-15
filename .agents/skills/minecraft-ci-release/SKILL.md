---
name: minecraft-ci-release
description: "Build, test, publish, and govern Minecraft 26.2 NeoForge releases with GitHub Actions, Java 25, Modrinth, CurseForge, GitHub Releases, version checks, dependency updates, and pinned workflow actions."
---

# Minecraft CI And Release Skill

Use this skill after the downstream project can build and test locally. The
canonical NeoForge 26.2 artifact is a normal `jar` task output. Fabric Loom's
remapped artifact is platform-specific and must not be used for NeoForge.

### Routing Boundaries

- `Use when`: the task is CI, release automation, artifact publishing,
  versioning, dependency updates, branch protection, or release governance.
- `Do not use when`: the task is gameplay code or test implementation; use
  `minecraft-modding` or `minecraft-testing`.
- `Do not use when`: the task does not change build, publishing, or repository
  governance behavior.

## Version And Platform Gate

Before editing automation, inspect the actual project:

```bash
rg -n "minecraft_version|neo_version|mod_version|moddev|loom|paper" \
  gradle.properties build.gradle build.gradle.kts settings.gradle settings.gradle.kts
./gradlew tasks --all
```

For NeoForge 26.2:

- use Java 25;
- run the project's Gradle wrapper;
- build with `build`;
- run registered GameTests with `runGameTestServer`;
- publish `tasks.named("jar")` or `tasks.named<Jar>("jar")`;
- declare the platform loader as `neoforge`/`NeoForge` on publishing services.

Verify exact task names when the downstream project has custom packaging or a
multi-project layout.

## Version Convention

Use `{mod_version}+{mc_version}` as the release version:

```text
1.0.0+26.2
1.2.3+26.2
2.0.0-beta.1+26.2
```

Use the exact project version in the Git tag:

```text
v1.2.3+26.2
```

This exact match makes release validation unambiguous.

## NeoForge Pull Request CI

`.github/workflows/neoforge-ci.yml`:

```yaml
name: NeoForge CI

on:
  push:
    branches: ["main"]
  pull_request:
    branches: ["main"]

permissions:
  contents: read

jobs:
  build:
    name: NeoForge build
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5 # v4

      - name: Set up Java 25
        uses: actions/setup-java@c1e323688fd81a25caa38c78aa6df2d33d3e20d9 # v4
        with:
          distribution: temurin
          java-version: "25"

      - name: Set up Gradle
        uses: gradle/actions/setup-gradle@0b6dd653ba04f4f93bf581ec31e66cbd7dcb644d # v4
        with:
          cache-read-only: ${{ github.event_name == 'pull_request' }}

      - name: Make Gradle wrapper executable
        run: chmod +x gradlew

      - name: Build
        run: ./gradlew build --no-daemon

      - name: Upload NeoForge JARs
        uses: actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02 # v4
        with:
          if-no-files-found: error
          name: neoforge-${{ github.sha }}
          path: build/libs/*.jar

  gametest:
    name: NeoForge GameTests
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5 # v4

      - name: Set up Java 25
        uses: actions/setup-java@c1e323688fd81a25caa38c78aa6df2d33d3e20d9 # v4
        with:
          distribution: temurin
          java-version: "25"

      - name: Set up Gradle
        uses: gradle/actions/setup-gradle@0b6dd653ba04f4f93bf581ec31e66cbd7dcb644d # v4
        with:
          cache-read-only: ${{ github.event_name == 'pull_request' }}

      - name: Make Gradle wrapper executable
        run: chmod +x gradlew

      - name: Run headless GameTests
        run: ./gradlew runGameTestServer --no-daemon
```

If GameTests are intentionally absent, remove the job and do not configure a
required check that can never pass.

## NeoForge Release Workflow

This workflow validates the tag before building or publishing.

`.github/workflows/release.yml`:

```yaml
name: Release

on:
  push:
    tags:
      - "v*"

permissions:
  contents: write

jobs:
  release:
    name: NeoForge release
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5 # v4

      - name: Set up Java 25
        uses: actions/setup-java@c1e323688fd81a25caa38c78aa6df2d33d3e20d9 # v4
        with:
          distribution: temurin
          java-version: "25"

      - name: Set up Gradle
        uses: gradle/actions/setup-gradle@0b6dd653ba04f4f93bf581ec31e66cbd7dcb644d # v4

      - name: Make Gradle wrapper executable
        run: chmod +x gradlew

      - name: Validate release tag
        shell: bash
        run: |
          set -euo pipefail
          project_version="$(awk -F= '$1 == "mod_version" { print substr($0, index($0, "=") + 1); exit }' gradle.properties)"
          if [[ -z "$project_version" ]]; then
            echo "mod_version is missing from gradle.properties" >&2
            exit 1
          fi
          expected_tag="v${project_version}"
          if [[ "$GITHUB_REF_NAME" != "$expected_tag" ]]; then
            echo "tag $GITHUB_REF_NAME does not match $expected_tag" >&2
            exit 1
          fi

      - name: Build and test
        run: ./gradlew build runGameTestServer --no-daemon

      - name: Publish to Modrinth and CurseForge
        run: ./gradlew modrinth curseforge --no-daemon
        env:
          CURSEFORGE_TOKEN: ${{ secrets.CURSEFORGE_TOKEN }}
          MODRINTH_TOKEN: ${{ secrets.MODRINTH_TOKEN }}

      - name: Create GitHub release
        uses: softprops/action-gh-release@3bb12739c298aeb8a4eeaf626c5b8d85266b0e65 # v2
        with:
          draft: false
          files: build/libs/*.jar
          generate_release_notes: true
          prerelease: ${{ contains(github.ref_name, '-alpha') || contains(github.ref_name, '-beta') || contains(github.ref_name, '-rc') }}
```

For a multi-project repository, qualify Gradle tasks and artifact paths with
the NeoForge subproject, then keep those exact paths consistent in every step.

## NeoForge Modrinth Publishing

`build.gradle.kts`:

```kotlin
import org.gradle.jvm.tasks.Jar

plugins {
    id("com.modrinth.minotaur") version "2.8.7"
}

modrinth {
    token.set(System.getenv("MODRINTH_TOKEN") ?: "")
    projectId.set(providers.gradleProperty("modrinth_project_id"))
    versionNumber.set(project.version.toString())
    versionType.set("release")
    uploadFile.set(tasks.named<Jar>("jar"))
    gameVersions.add("26.2")
    loaders.add("neoforge")
    changelog.set(file("CHANGELOG.md").readText())
}
```

If the project produces sources or API JARs, add them intentionally as
additional files. Do not upload every file in `build/libs` without classifying
it.

## NeoForge CurseForge Publishing

`build.gradle.kts`:

```kotlin
import net.darkhax.curseforgegradle.TaskPublishCurseForge
import org.gradle.jvm.tasks.Jar

plugins {
    id("net.darkhax.curseforgegradle") version "1.1.25"
}

tasks.register<TaskPublishCurseForge>("curseforge") {
    apiToken = System.getenv("CURSEFORGE_TOKEN") ?: ""

    val mainFile = upload(
        providers.gradleProperty("curseforge_project_id").get().toInt(),
        tasks.named<Jar>("jar")
    )
    mainFile.changelogType = "markdown"
    mainFile.changelog = file("CHANGELOG.md").readText()
    mainFile.releaseType = "release"
    mainFile.addGameVersion("26.2")
    mainFile.addModLoader("NeoForge")
}
```

Plugin DSLs evolve independently of Minecraft. Confirm the configured plugin
version and task types in the downstream Gradle model before changing a
working publishing block.

## Fabric Is A Separate Artifact Path

Only a Fabric Loom subproject should publish its remapped output:

```kotlin
// fabric/build.gradle.kts
modrinth {
    uploadFile.set(tasks.named("remapJar"))
    gameVersions.add("26.2")
    loaders.add("fabric")
}
```

Do not copy this task into a NeoForge project. In a multiloader build, configure
separate Modrinth and CurseForge tasks per loader and give each upload a unique
version/file identity.

## Secrets

Configure these as repository or environment secrets, never in committed
Gradle properties:

- `MODRINTH_TOKEN`
- `CURSEFORGE_TOKEN`

Commit only public project IDs:

```properties
mod_version=1.0.0+26.2
minecraft_version=26.2
modrinth_project_id=A1B2C3D4
curseforge_project_id=123456
```

Use a protected GitHub environment with required reviewers when releases need
manual approval.

## Portable Release Script

This script updates `mod_version` without relying on GNU-specific in-place
editing. It creates a local commit and tag but does not push them.

```bash
#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:?Usage: release.sh <version+mc-version>}"
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?\+26\.2$ ]]; then
  echo "invalid 26.2 release version: $VERSION" >&2
  exit 2
fi

temporary_file="$(mktemp)"
trap 'rm -f "$temporary_file"' EXIT

awk -v version="$VERSION" '
  BEGIN { updated = 0 }
  /^mod_version=/ {
    print "mod_version=" version
    updated = 1
    next
  }
  { print }
  END { if (!updated) exit 3 }
' gradle.properties > "$temporary_file"

mv "$temporary_file" gradle.properties
trap - EXIT

git add gradle.properties
git commit -m "chore: release v${VERSION}"
git tag "v${VERSION}"

echo "created v${VERSION}; review the commit before pushing"
```

## Branch Protection

For the workflow above, require these exact check names on `main`:

- `NeoForge build`
- `NeoForge GameTests`

GitHub displays the job's `name`, not the YAML job key. Update branch
protection whenever a job name changes. Also require review and prevent direct
force-pushes to the release branch.

## Gradle Cache Guidance

`gradle/actions/setup-gradle` already manages Gradle user-home caching. A
NeoForge-only workflow does not need a Loom cache path.

```yaml
- name: Set up Gradle
  uses: gradle/actions/setup-gradle@0b6dd653ba04f4f93bf581ec31e66cbd7dcb644d # v4
  with:
    cache-read-only: ${{ github.event_name == 'pull_request' }}
```

Do not combine `actions/cache` over the same Gradle directories unless there is
a measured gap that `setup-gradle` cannot cover.

## Dependabot

`.github/dependabot.yml`:

```yaml
version: 2
updates:
  - package-ecosystem: gradle
    directory: "/"
    schedule:
      interval: weekly
    groups:
      gradle-plugins:
        patterns:
          - "net.neoforged.moddev"
          - "com.modrinth.minotaur"
          - "net.darkhax.curseforgegradle"

  - package-ecosystem: github-actions
    directory: "/"
    schedule:
      interval: weekly
```

Review NeoForge and ModDevGradle updates together with their Minecraft and Java
requirements. Dependency automation should open a pull request, not publish a
release.

## Paper Plugin Boundary

Paper is not NeoForge. For a Paper project, confirm its own Minecraft and Java
baseline, use its `shadowJar`/`test` tasks, and publish the shaded plugin rather
than a NeoForge mod JAR. Do not share loader declarations or GameTest tasks
between these platforms.

## Workflow Snippet Validator

Run the bundled, self-contained validator from the installed skill directory:

```bash
./scripts/validate-workflow-snippets.sh --root .
./scripts/validate-workflow-snippets.sh --root . --strict
```

It validates YAML syntax, workflow top-level keys, full action commit pins,
container digests, placeholders, globs, and documented secret usage.

## Release Checklist

- `mod_version` exactly matches the tag without its leading `v`.
- Minecraft is `26.2`, Java is `25`, and the resolved NeoForge version is
  intentional.
- Unit tests, `build`, and `runGameTestServer` pass.
- The changelog contains the release version.
- NeoForge publishing uses `jar` and loader `neoforge`/`NeoForge`.
- Tokens are scoped secrets and logs do not print them.
- GitHub artifacts and release files point to the same built JAR family.
- Required branch checks match job display names.

## References

- GitHub Actions: https://docs.github.com/en/actions
- Gradle Actions: https://github.com/gradle/actions
- Modrinth Minotaur: https://github.com/modrinth/minotaur
- CurseForgeGradle: https://github.com/Darkhax-Minecraft/CurseForgeGradle
- GitHub release action: https://github.com/softprops/action-gh-release
