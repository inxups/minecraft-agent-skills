# CI Release Fixture

## Required Secrets

- `MODRINTH_TOKEN`
- `CURSEFORGE_TOKEN`

```yaml
name: Build
on:
  push:
    branches: ["main"]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5 # v4
      - run: echo ok
      - env:
          MODRINTH_TOKEN: ${{ secrets.MODRINTH_TOKEN }}
          CURSEFORGE_TOKEN: ${{ secrets.CURSEFORGE_TOKEN }}
        run: echo release
```
