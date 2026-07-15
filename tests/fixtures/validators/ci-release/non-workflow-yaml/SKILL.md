# CI Release Fixture

## Required Secrets

- `MODRINTH_TOKEN`

```yaml
# In all workflow jobs:
- name: Setup Gradle
  uses: gradle/actions/setup-gradle@0b6dd653ba04f4f93bf581ec31e66cbd7dcb644d # v4
  with:
    cache-read-only: ${{ github.event_name == 'pull_request' }}
```

```yaml
name: Build
on:
  push:
    branches: ["main"]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - run: echo ok
      - env:
          MODRINTH_TOKEN: ${{ secrets.MODRINTH_TOKEN }}
        run: echo release
```
