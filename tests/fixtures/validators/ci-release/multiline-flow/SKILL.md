---
name: minecraft-ci-release
description: >
  Fixture with valid multiline flow collections in workflow YAML.
---

# Multiline Flow Fixture

## Required Secrets

- `MODRINTH_TOKEN`

```yaml
name: Matrix Build
on:
  push:
    branches: ["main"]
jobs:
  build:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        include: [
          { platform: fabric, dir: fabric },
          { platform: neoforge, dir: neoforge }
        ]
    steps:
      - uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5 # v4
      - env:
          MODRINTH_TOKEN: ${{ secrets.MODRINTH_TOKEN }}
        run: ./gradlew :${{ matrix.dir }}:build --no-daemon
```
