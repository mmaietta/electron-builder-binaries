const path = require("path");
const fs = require("fs");
const { execSync } = require("child_process");

// changeset status expects relative __dirname even if we set absolute output path
const changesetJsonPath = "changeset-status.json";

execSync(`pnpm changeset status --output ${changesetJsonPath}`);

const changesetJson = JSON.parse(fs.readFileSync(changesetJsonPath, "utf-8"));
const releases = changesetJson.releases;

console.log("Release candidates:", releases);

releases.forEach((release) => {
  const { name } = release;
  const artifactPath = path.resolve(__dirname, "../artifacts", name);
  const newArtifactPath = path.resolve(__dirname, "../artifacts-new", name);
  if (!process.env.DRY_RUN) {
    fs.rmSync(artifactPath, { recursive: true, force: true });
    fs.renameSync(newArtifactPath, artifactPath);
    console.log(`Moved ${newArtifactPath} to ${artifactPath}...`);
    
    execSync(`git add --force -A ${artifactPath}`);
    console.log(`Committed ${artifactPath}...`);
  } else {
    console.log(`DRY_RUN: Verified ${artifactPath}...`);
  }
});
