# CI Release Fixture

## Required Secrets

- `MODRINTH_TOKEN`

```yaml
name: Broken Build
on:
  push:
    branches: ["main"]
steps:
  - uses: actions/checkout@v4
  - run: echo path/to/workflows
  - env:
      CURSEFORGE_TOKEN: ${{ secrets.CURSEFORGE_TOKEN }}
    run: echo release
```
