const path = require("path");
const fs = require("fs");
const { execSync } = require("child_process");
const packageMap = require("./changeset-packagemap");

// changeset status expects relative __dirname even if we set absolute output path
const changesetJsonPath = "changeset-status.json";

execSync(`pnpm changeset status --output ${changesetJsonPath}`);

const changesetJson = JSON.parse(fs.readFileSync(changesetJsonPath, "utf-8"));
const releases = changesetJson.releases;

console.log("Release candidates:", releases);

releases.forEach((release) => {
  const { name } = release;
  const artifactsToUpload = packageMap[name];
  if (!artifactsToUpload) {
    throw new Error(`No artifacts found for ${name}`);
  }
  const artifactPath = path.resolve(__dirname, "../artifacts", name);
  if (!process.env.DRY_RUN) {
    execSync(`git add --force ${artifactPath}`);
    console.log(`Committed ${artifactPath}...`);
  } else {
    console.log(`DRY_RUN: Verified ${artifactPath}...`);
  }
});
