#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";

const ROOT = process.cwd();
const CANONICAL = path.join(ROOT, ".agents", "skills");
const REQUIRED_SKILLS_INDEX = "README.md";
const MIRRORS = [
  { dir: path.join(ROOT, ".codex", "skills"), label: ".codex/skills" },
  { dir: path.join(ROOT, ".claude", "skills"), label: ".claude/skills" },
  { dir: path.join(ROOT, "plugins", "minecraft-codex-skills", "skills"), label: "plugins/minecraft-codex-skills/skills" },
];
const FORBIDDEN_REPO_ROOT_SKILL_FILES = [
  path.join(ROOT, "SKILL.md"),
  path.join(ROOT, "references", "asset-recipes.md"),
  path.join(ROOT, "references", "prompt-patterns.md"),
  path.join(ROOT, "scripts", "scaffold-asset-brief.sh"),
];

const errors = [];

function addError(file, message) {
  errors.push(`${file}: ${message}`);
}

function readText(file) {
  return fs.readFileSync(file, "utf8").replace(/^\uFEFF/, "").replace(/\r\n/g, "\n");
}

function walkFiles(dir) {
  const out = [];
  if (!fs.existsSync(dir)) return out;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) out.push(...walkFiles(full));
    else out.push(full);
  }
  return out;
}

function rel(p) {
  return path.relative(ROOT, p).replaceAll(path.sep, "/");
}

function hashFile(file) {
  return crypto.createHash("sha256").update(fs.readFileSync(file)).digest("hex");
}

function parseFrontmatter(text, file) {
  const match = text.match(/^---\n([\s\S]*?)\n---\n/);
  if (!match) {
    addError(file, "missing YAML frontmatter");
    return null;
  }
  const raw = match[1];
  const unquote = (value) => {
    const trimmed = value?.trim() ?? "";
    const quote = trimmed[0];
    if ((quote === '"' || quote === "'") && trimmed.at(-1) === quote) {
      return trimmed.slice(1, -1).trim();
    }
    return trimmed;
  };
  const name = unquote(raw.match(/^name:\s*(.+)$/m)?.[1]);
  const descriptionRaw = raw.match(/^description:\s*(.*)$/m)?.[1]?.trim() ?? "";
  const description = unquote(descriptionRaw);
  const hasDescription = descriptionRaw === ">" || descriptionRaw === "|" || Boolean(description);
  if (!name) addError(file, "frontmatter missing `name`");
  if (!hasDescription) addError(file, "frontmatter missing `description`");
  return { name };
}

function skillDirectoryNames(dir) {
  if (!fs.existsSync(dir)) return [];
  return fs.readdirSync(dir, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name)
    .sort();
}

function catalogSkillNames(text, file) {
  const marker = "## Skill Catalog\n";
  const start = text.indexOf(marker);
  const remainder = start >= 0 ? text.slice(start + marker.length) : "";
  const nextHeading = remainder.search(/^## /m);
  const section = nextHeading >= 0 ? remainder.slice(0, nextHeading) : remainder;
  const names = [...section.matchAll(/^\|\s*`(minecraft-[a-z0-9-]+)`\s*\|/gm)].map((match) => match[1]);
  if (names.length === 0) addError(file, "Skill Catalog contains no skill rows");

  const duplicates = names.filter((name, index) => names.indexOf(name) !== index);
  for (const name of new Set(duplicates)) addError(file, `Skill Catalog lists \`${name}\` more than once`);
  return [...new Set(names)].sort();
}

function compareNameSets(actual, documented, file) {
  for (const name of actual.filter((entry) => !documented.includes(entry))) {
    addError(file, `Skill Catalog is missing directory \`${name}\``);
  }
  for (const name of documented.filter((entry) => !actual.includes(entry))) {
    addError(file, `Skill Catalog references missing directory \`${name}\``);
  }
}

function checkRunnableBlocks(file, text) {
  const runnableLangs = new Set(["bash", "sh", "mcfunction", "java", "json", "yaml", "yml", "toml", "properties"]);
  const fenceRe = /(```|~~~)([^\n]*)\n([\s\S]*?)\1/g;
  let match;

  while ((match = fenceRe.exec(text)) !== null) {
    const lang = match[2].trim().split(/\s+/, 1)[0].toLowerCase();
    const code = match[3];
    if (!runnableLangs.has(lang)) continue;

    if (/\{player\}/.test(code)) {
      addError(file, "runnable code block contains placeholder `{player}`");
    }
    if (/\brun\s+\.\.\./.test(code)) {
      addError(file, "runnable code block contains unresolved `run ...` placeholder");
    }
    if (/^\s*\.\.\.\s*$/m.test(code)) {
      addError(file, "runnable code block contains unresolved ellipsis line");
    }
  }
}

function checkPathConventions(file, text) {
  const relativeFile = rel(file);
  const legacyForge1201PathNeedles = [
    ["loot_tables", "use `loot_table` for 26.2 conventions"],
    ["tags/blocks", "use `tags/block` for 26.2 conventions"],
    ["tags/items", "use `tags/item` for 26.2 conventions"],
  ];
  const banned = [
    ["biome_modifiers", "use `biome_modifier` for NeoForge biome modifier path"],
    ["max-player-count", "use `max-players` (server.properties key)"],
    ["<mc_version>-<mod_version>", "use `{mod_version}+{mc_version}` for mod version examples"],
    ["1.21.1-2.0.0", "use `{mod_version}+{mc_version}` for mod version examples"],
  ];

  const moddingSkill = relativeFile.endsWith("minecraft-modding/SKILL.md");

  for (const [needle, msg] of banned) {
    if (text.includes(needle)) addError(file, msg);
  }

  if (/\.agents\/skills\/[^/\s]+\/scripts\/[^\s`]+/.test(text)) {
    addError(file, "hardcoded `.agents/skills/.../scripts/...` path in docs; use mirror-safe `./scripts/...` guidance or document all mirrors explicitly");
  }
}

function checkRoutingBoundaries(file, text) {
  const hasSection = /^### Routing Boundaries$/m.test(text);
  if (!hasSection) {
    addError(file, "missing `### Routing Boundaries` section");
    return;
  }

  const hasUseWhen = /- `Use when`:/m.test(text);
  const hasDoNotUseWhen = /- `Do not use when`:/m.test(text);
  if (!hasUseWhen) addError(file, "routing section missing `- `Use when`:` criterion");
  if (!hasDoNotUseWhen) addError(file, "routing section missing `- `Do not use when`:` criterion");
}

function checkSpecialSkillRequirements(skillName, file, text) {
  if (skillName !== "minecraft-imagegen") return;

  if (!text.includes("current host does not expose built-in image generation")) {
    addError(file, "minecraft-imagegen must explicitly guard hosts that do not expose image generation");
  }

  if (!text.includes("this skill is unavailable on that host")) {
    addError(file, "minecraft-imagegen must tell unsupported hosts to stop at planning/briefing instead of promising image generation");
  }
}

for (const file of FORBIDDEN_REPO_ROOT_SKILL_FILES) {
  if (fs.existsSync(file)) {
    addError(file, "unexpected repo-root minecraft-imagegen copy; keep image skill files only under .agents/skills and synced mirrors");
  }
}

if (!fs.existsSync(CANONICAL)) {
  addError(".agents/skills", "canonical skills directory is missing");
} else {
  const canonicalIndex = path.join(CANONICAL, REQUIRED_SKILLS_INDEX);
  if (!fs.existsSync(canonicalIndex)) {
    addError(rel(canonicalIndex), "required canonical skills index is missing");
  }

  const canonicalSkillNames = skillDirectoryNames(CANONICAL);
  if (fs.existsSync(canonicalIndex)) {
    compareNameSets(canonicalSkillNames, catalogSkillNames(readText(canonicalIndex), rel(canonicalIndex)), rel(canonicalIndex));
  }

  const skillDirs = fs.readdirSync(CANONICAL, { withFileTypes: true }).filter((d) => d.isDirectory());
  for (const dirent of skillDirs) {
    const skillName = dirent.name;
    const skillFile = path.join(CANONICAL, skillName, "SKILL.md");
    const skillRel = rel(skillFile);

    if (!fs.existsSync(skillFile)) {
      addError(path.join(".agents/skills", skillName), "missing SKILL.md");
      continue;
    }

    const text = readText(skillFile);
    const fm = parseFrontmatter(text, skillRel);
    if (fm?.name && fm.name !== skillName) {
      addError(skillRel, `frontmatter name \`${fm.name}\` does not match directory \`${skillName}\``);
    }

    checkRoutingBoundaries(skillRel, text);
    checkRunnableBlocks(skillRel, text);
    checkPathConventions(skillRel, text);
    checkSpecialSkillRequirements(skillName, skillRel, text);
  }

  const canonicalFiles = walkFiles(CANONICAL);
  for (const file of canonicalFiles) {
    if (!file.endsWith(".md") && !file.endsWith(".sh")) continue;
    if (file.endsWith(`${path.sep}SKILL.md`)) continue;
    const txt = readText(file);
    if (file.endsWith(".md")) {
      checkRunnableBlocks(rel(file), txt);
      checkPathConventions(rel(file), txt);
    }
  }
}

for (const { dir: MIRROR, label: mirrorLabel } of MIRRORS) {
  if (!fs.existsSync(MIRROR)) {
    addError(mirrorLabel, "mirror skills directory is missing");
  } else if (fs.existsSync(CANONICAL)) {
    const mirrorIndex = path.join(MIRROR, REQUIRED_SKILLS_INDEX);
    if (!fs.existsSync(mirrorIndex)) {
      addError(rel(mirrorIndex), "required mirrored skills index is missing");
    }

    const canonicalFiles = walkFiles(CANONICAL).map((p) => path.relative(CANONICAL, p)).sort();
    const mirrorFiles = walkFiles(MIRROR).map((p) => path.relative(MIRROR, p)).sort();

    const onlyCanonical = canonicalFiles.filter((f) => !mirrorFiles.includes(f));
    const onlyMirror = mirrorFiles.filter((f) => !canonicalFiles.includes(f));

    for (const f of onlyCanonical) addError(`.agents/skills/${f}`, `missing from mirror ${mirrorLabel}`);
    for (const f of onlyMirror) addError(`${mirrorLabel}/${f}`, "missing from canonical .agents/skills");

    for (const f of canonicalFiles) {
      if (!mirrorFiles.includes(f)) continue;
      const cf = path.join(CANONICAL, f);
      const mf = path.join(MIRROR, f);
      if (hashFile(cf) !== hashFile(mf)) {
        addError(`${mirrorLabel}/${f}`, "content drift from canonical .agents/skills");
      }
    }
  }
}

if (errors.length > 0) {
  console.error("Skill audit failed:\n");
  for (const err of errors) console.error(`- ${err}`);
  process.exit(1);
}

console.log("Skill audit passed");
