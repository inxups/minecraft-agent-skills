#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";

const repoRoot = process.cwd();

const checks = [
  {
    file: "README.md",
    required: [
      /\*\*5 AI agent skills\*\*/,
      /Minecraft 26\.2/,
      /Java 25/,
    ],
    forbidden: [
      /13 AI agent skills/,
      /all 13 Minecraft skill directories/,
    ],
  },
  {
    file: ".agents/skills/README.md",
    required: [
      /Most skill content targets Minecraft `26\.2`/,
      /`minecraft-modding`/,
      /`minecraft-testing`/,
      /`minecraft-ci-release`/,
      /`minecraft-world-generation`/,
      /`minecraft-imagegen`/,
    ],
  },
  {
    file: ".agents/skills/minecraft-modding/SKILL.md",
    required: [
      /NeoForge \(26\.2\)/,
      /\| \*\*NeoForge\*\* \| 26\.2 \| Java 25 \|/,
    ],
    forbidden: [/\| \*\*NeoForge\*\* \| 1\.26\.2 \|/],
  },
  {
    file: ".agents/skills/minecraft-modding/references/neoforge-api.md",
    required: [
      /targeting Minecraft 26\.2 with Java 25/,
      /minecraft_version=26\.2/,
    ],
    forbidden: [
      /minecraft_version=1\.21\.11/,
      /versionRange="\[1\.21\.11,1\.22\)"/,
    ],
  },
  {
    file: ".agents/skills/minecraft-ci-release/SKILL.md",
    required: [
      /1\.0\.0\+26\.2/,
      /gameVersions\.addAll\("26\.2"\)/,
      /cf\.addGameVersion\("26\.2"\)/,
      /minecraft_version=26\.2/,
    ],
    forbidden: [/1\.0\.0\+1\.21\.11/],
  },
  {
    file: "plugins/minecraft-codex-skills/.codex-plugin/plugin.json",
    required: [
      /"shortDescription": "5 reusable Minecraft/,
      /NeoForge 26\.2 mod/,
    ],
    forbidden: [/13 reusable Minecraft/],
  },
  {
    file: "scripts/run-skill-validator-fixtures.sh",
    required: [
      /ci-release valid/,
      /testing neoforge valid/,
      /worldgen valid/,
      /worldgen jq fallback/,
    ],
    forbidden: [
      /minecraft-datapack/,
      /minecraft-resource-pack/,
      /minecraft-plugin-dev/,
      /minecraft-multiloader/,
    ],
  },
];

let failures = 0;

for (const check of checks) {
  const target = path.join(repoRoot, check.file);
  if (!fs.existsSync(target)) {
    console.error(`[FAIL] ${check.file} is missing`);
    failures += 1;
    continue;
  }

  const text = fs.readFileSync(target, "utf8");

  for (const pattern of check.required ?? []) {
    if (!pattern.test(text)) {
      console.error(`[FAIL] ${check.file} missing required pattern: ${pattern}`);
      failures += 1;
    }
  }

  for (const pattern of check.forbidden ?? []) {
    if (pattern.test(text)) {
      console.error(`[FAIL] ${check.file} still matches forbidden pattern: ${pattern}`);
      failures += 1;
    }
  }
}

if (failures > 0) {
  console.error(`[FAIL] version drift check failed with ${failures} issue(s)`);
  process.exit(1);
}

console.log("[PASS] version drift check passed");
