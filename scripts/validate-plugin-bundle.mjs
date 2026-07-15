#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { URL } from "node:url";

const ROOT = process.cwd();
const PLUGIN_NAME = "minecraft-codex-skills";
const PACKAGE_JSON = path.join(ROOT, "package.json");
const PACKAGE_LOCK = path.join(ROOT, "package-lock.json");
const CANONICAL_SKILLS = path.join(ROOT, ".agents", "skills");
const PLUGIN_ROOT = path.join(ROOT, "plugins", PLUGIN_NAME);
const CODEX_MANIFEST = path.join(PLUGIN_ROOT, ".codex-plugin", "plugin.json");
const CLAUDE_MANIFEST = path.join(PLUGIN_ROOT, ".claude-plugin", "plugin.json");
const PLUGIN_README = path.join(PLUGIN_ROOT, "README.md");
const PLUGIN_SKILLS = path.join(PLUGIN_ROOT, "skills");
const MARKETPLACE = path.join(ROOT, ".agents", "plugins", "marketplace.json");
const REPOSITORY_METADATA = path.join(ROOT, ".github", "repository.json");

const errors = [];

function relative(file) {
  return path.relative(ROOT, file).replaceAll(path.sep, "/");
}

function addError(file, message) {
  errors.push(`${relative(file)}: ${message}`);
}

function readJson(file) {
  if (!fs.existsSync(file)) {
    addError(file, "missing required JSON file");
    return null;
  }

  try {
    return JSON.parse(fs.readFileSync(file, "utf8"));
  } catch (error) {
    addError(file, `invalid JSON: ${error.message}`);
    return null;
  }
}

function readText(file) {
  if (!fs.existsSync(file)) {
    addError(file, "missing required text file");
    return null;
  }
  return fs.readFileSync(file, "utf8");
}

function isHttpsUrl(value) {
  if (typeof value !== "string" || value.trim() === "") return false;
  try {
    return new URL(value).protocol === "https:";
  } catch {
    return false;
  }
}

function directoryNames(dir) {
  if (!fs.existsSync(dir)) return [];
  return fs.readdirSync(dir, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name)
    .sort();
}

function requireString(object, field, file, prefix = "") {
  const value = object?.[field];
  if (typeof value !== "string" || value.trim() === "") {
    addError(file, `expected ${prefix}${field} to be a non-empty string`);
    return null;
  }
  return value;
}

function compareSkillNames(canonicalNames, pluginNames) {
  for (const name of canonicalNames.filter((entry) => !pluginNames.includes(entry))) {
    addError(PLUGIN_SKILLS, `missing canonical skill directory: ${name}`);
  }
  for (const name of pluginNames.filter((entry) => !canonicalNames.includes(entry))) {
    addError(PLUGIN_SKILLS, `unexpected non-canonical skill directory: ${name}`);
  }
}

const pkg = readJson(PACKAGE_JSON);
const packageLock = readJson(PACKAGE_LOCK);
const codexManifest = readJson(CODEX_MANIFEST);
const claudeManifest = readJson(CLAUDE_MANIFEST);
const marketplace = readJson(MARKETPLACE);
const repositoryMetadata = readJson(REPOSITORY_METADATA);
const pluginReadme = readText(PLUGIN_README);
const canonicalNames = directoryNames(CANONICAL_SKILLS);
const pluginNames = directoryNames(PLUGIN_SKILLS);

if (canonicalNames.length === 0) addError(CANONICAL_SKILLS, "no canonical skill directories found");
compareSkillNames(canonicalNames, pluginNames);

const releaseVersion = pkg?.version;
if (typeof releaseVersion !== "string" || !/^\d+\.\d+\.\d+$/.test(releaseVersion)) {
  addError(PACKAGE_JSON, "top-level version must use strict semantic versioning");
}

if (packageLock) {
  if (packageLock.version !== releaseVersion) addError(PACKAGE_LOCK, `expected top-level version \`${releaseVersion}\``);
  if (packageLock.packages?.[""]?.version !== releaseVersion) {
    addError(PACKAGE_LOCK, `expected root package version \`${releaseVersion}\``);
  }
}

if (codexManifest) {
  if (codexManifest.name !== PLUGIN_NAME) addError(CODEX_MANIFEST, `expected name \`${PLUGIN_NAME}\``);
  if (codexManifest.version !== releaseVersion) addError(CODEX_MANIFEST, `expected version \`${releaseVersion}\``);
  if (codexManifest.skills !== "./skills/") addError(CODEX_MANIFEST, "expected `skills` to be `./skills/`");
  requireString(codexManifest, "description", CODEX_MANIFEST);
  if (!isHttpsUrl(codexManifest.homepage)) addError(CODEX_MANIFEST, "expected `homepage` to be an https URL");
  if (!isHttpsUrl(codexManifest.repository)) addError(CODEX_MANIFEST, "expected `repository` to be an https URL");
  if (!Array.isArray(codexManifest.keywords) || codexManifest.keywords.length < 5) {
    addError(CODEX_MANIFEST, "expected at least five discovery keywords");
  }

  const iface = codexManifest.interface;
  if (!iface || typeof iface !== "object" || Array.isArray(iface)) {
    addError(CODEX_MANIFEST, "missing `interface` metadata object");
  } else {
    const shortDescription = requireString(iface, "shortDescription", CODEX_MANIFEST, "interface.");
    const longDescription = requireString(iface, "longDescription", CODEX_MANIFEST, "interface.");
    for (const field of ["displayName", "developerName", "category"]) {
      requireString(iface, field, CODEX_MANIFEST, "interface.");
    }

    if (shortDescription && !shortDescription.includes(`${canonicalNames.length} reusable Minecraft`)) {
      addError(CODEX_MANIFEST, `interface.shortDescription must advertise ${canonicalNames.length} reusable Minecraft skills`);
    }
    if (longDescription) {
      for (const name of canonicalNames) {
        if (!longDescription.includes(name)) addError(CODEX_MANIFEST, `interface.longDescription must name ${name}`);
      }
    }

    if (!Array.isArray(iface.capabilities) || iface.capabilities.length === 0) {
      addError(CODEX_MANIFEST, "expected interface.capabilities to be a non-empty array");
    }
    if (!Array.isArray(iface.defaultPrompt) || iface.defaultPrompt.length === 0 || iface.defaultPrompt.length > 3) {
      addError(CODEX_MANIFEST, "expected interface.defaultPrompt to contain one to three prompts");
    } else {
      iface.defaultPrompt.forEach((prompt, index) => {
        if (typeof prompt !== "string" || prompt.trim() === "" || prompt.length > 128) {
          addError(CODEX_MANIFEST, `interface.defaultPrompt[${index}] must be a non-empty string no longer than 128 characters`);
        }
      });
    }
    if (!isHttpsUrl(iface.websiteURL)) addError(CODEX_MANIFEST, "expected interface.websiteURL to be an https URL");
    if (!isHttpsUrl(iface.privacyPolicyURL)) addError(CODEX_MANIFEST, "expected interface.privacyPolicyURL to be an https URL");
    if (!isHttpsUrl(iface.termsOfServiceURL)) addError(CODEX_MANIFEST, "expected interface.termsOfServiceURL to be an https URL");
  }
}

if (claudeManifest) {
  if (claudeManifest.name !== PLUGIN_NAME) addError(CLAUDE_MANIFEST, `expected name \`${PLUGIN_NAME}\``);
  if (claudeManifest.version !== releaseVersion) addError(CLAUDE_MANIFEST, `expected version \`${releaseVersion}\``);
  requireString(claudeManifest, "description", CLAUDE_MANIFEST);
  if (!isHttpsUrl(claudeManifest.homepage)) addError(CLAUDE_MANIFEST, "expected `homepage` to be an https URL");
  if (!isHttpsUrl(claudeManifest.repository)) addError(CLAUDE_MANIFEST, "expected `repository` to be an https URL");
}

if (repositoryMetadata) requireString(repositoryMetadata, "description", REPOSITORY_METADATA);

if (marketplace) {
  const pluginEntry = Array.isArray(marketplace.plugins)
    ? marketplace.plugins.find((entry) => entry?.name === PLUGIN_NAME)
    : null;
  if (!pluginEntry) {
    addError(MARKETPLACE, `missing plugin entry for \`${PLUGIN_NAME}\``);
  } else {
    if (pluginEntry.source?.source !== "local") addError(MARKETPLACE, "expected plugin source.source to be `local`");
    if (pluginEntry.source?.path !== "./plugins/minecraft-codex-skills") {
      addError(MARKETPLACE, "expected plugin source.path to be `./plugins/minecraft-codex-skills`");
    }
    if (pluginEntry.policy?.installation !== "AVAILABLE") addError(MARKETPLACE, "expected installation policy `AVAILABLE`");
    if (pluginEntry.policy?.authentication !== "ON_INSTALL") addError(MARKETPLACE, "expected authentication policy `ON_INSTALL`");
    if (typeof pluginEntry.category !== "string" || pluginEntry.category.trim() === "") {
      addError(MARKETPLACE, "expected a non-empty plugin category");
    }
  }
}

if (pluginReadme) {
  for (const snippet of [
    "plugins/minecraft-codex-skills/",
    ".agents/plugins/marketplace.json",
    "## Skill groups",
    "## Compatibility",
    "## Troubleshooting",
  ]) {
    if (!pluginReadme.includes(snippet)) addError(PLUGIN_README, `missing required guidance: ${snippet}`);
  }
  for (const name of canonicalNames) {
    if (!pluginReadme.includes(name)) addError(PLUGIN_README, `missing canonical skill name: ${name}`);
  }
}

if (errors.length > 0) {
  console.error("Plugin bundle validation failed:\n");
  for (const error of errors) console.error(`- ${error}`);
  process.exit(1);
}

console.log(`Plugin bundle validation passed (${canonicalNames.length} skills)`);
