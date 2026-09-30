#!/usr/bin/env node
// Build the place with Rojo and push it to Roblox via Open Cloud.
//
// Credentials come from the environment (or a gitignored .env) and are never
// written to disk, echoed, or included in error output. Nothing in this repo
// stores a key.
//
//   ROBLOX_API_KEY       Open Cloud key with "Universe Places: write"
//   ROBLOX_UNIVERSE_ID   the experience's universe id
//   ROBLOX_PLACE_ID      the place id inside that universe
//
//   node scripts/publish.mjs            # publish (live)
//   node scripts/publish.mjs --saved    # save a version without going live

import { readFileSync, existsSync, statSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const OUTPUT = resolve(root, "build/perwd-fishing.rbxl");

function loadDotEnv() {
  const path = resolve(root, ".env");
  if (!existsSync(path)) return;

  for (const line of readFileSync(path, "utf8").split("\n")) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;

    const eq = trimmed.indexOf("=");
    if (eq === -1) continue;

    const key = trimmed.slice(0, eq).trim();
    const value = trimmed.slice(eq + 1).trim().replace(/^["']|["']$/g, "");
    if (value && !process.env[key]) process.env[key] = value;
  }
}

function required(name) {
  const value = process.env[name];
  if (!value) {
    console.error(
      `Missing ${name}.\n` +
        `Set it in your shell or in a .env file (copy .env.example).\n` +
        `.env is gitignored — do not commit it, and do not paste the key into chat, ` +
        `an issue, a commit message, or a screenshot.`,
    );
    process.exit(1);
  }
  return value;
}

function build() {
  console.log("building place with rojo…");
  try {
    execFileSync("rojo", ["build", "default.project.json", "--output", OUTPUT], {
      cwd: root,
      stdio: "inherit",
    });
  } catch (error) {
    if (error.code === "ENOENT") {
      console.error("rojo not found on PATH. Install it with `aftman install`.");
    } else {
      console.error("rojo build failed.");
    }
    process.exit(1);
  }
}

async function publish() {
  loadDotEnv();

  const apiKey = required("ROBLOX_API_KEY");
  const universeId = required("ROBLOX_UNIVERSE_ID");
  const placeId = required("ROBLOX_PLACE_ID");

  build();

  const body = readFileSync(OUTPUT);
  console.log(`uploading ${(statSync(OUTPUT).size / 1024).toFixed(0)} KB…`);

  const versionType = process.argv.includes("--saved") ? "Saved" : "Published";
  const url =
    `https://apis.roblox.com/universes/v1/${universeId}` +
    `/places/${placeId}/versions?versionType=${versionType}`;

  const response = await fetch(url, {
    method: "POST",
    headers: {
      "x-api-key": apiKey,
      "Content-Type": "application/octet-stream",
    },
    body,
  });

  const text = await response.text();

  if (!response.ok) {
    // Deliberately does not echo headers, so the key cannot leak into a log,
    // a CI transcript, or a pasted error report.
    console.error(`Open Cloud returned ${response.status}: ${text}`);
    if (response.status === 401 || response.status === 403) {
      console.error(
        "Check that the key is valid, has the Universe Places write scope for " +
          "this experience, and that your IP is inside the key's allowed range.",
      );
    }
    process.exit(1);
  }

  let version = text;
  try {
    version = JSON.parse(text).versionNumber ?? text;
  } catch {
    // Non-JSON success body; print it as-is.
  }

  console.log(`done — ${versionType.toLowerCase()} version ${version}`);
  console.log(`https://www.roblox.com/games/${placeId}`);
}

publish().catch((error) => {
  console.error(error.message ?? error);
  process.exit(1);
});
