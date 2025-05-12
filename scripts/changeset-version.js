const path = require("path");
const fs = require("fs");
const { execSync, exec } = require("child_process");

// changeset status expects relative __dirname even if we set absolute output path
const changesetJsonPath = "changeset-status.json";

execSync(`pnpm changeset status --output ${changesetJsonPath}`);

const changesetJson = JSON.parse(fs.readFileSync(changesetJsonPath, "utf-8"));
const releases = changesetJson.releases;

console.log("Release candidates:", releases);

const shouldDelete = (filePath) => {
  const isReleaseCandidate = releases.some((release) => {
    const artifactPath = path.resolve(__dirname, "../artifacts", release.name);
    return filePath.startsWith(artifactPath);
  });
  return !isReleaseCandidate;
};
fs.readdirSync(path.resolve(__dirname, "../artifacts")).forEach((file) => {
  const filePath = path.resolve(__dirname, "../artifacts", file);
  if (shouldDelete(filePath)) {
    console.log(`Deleting ${filePath}...`);
    if (!process.env.DRY_RUN) {
      execSync(`git rm --force -r ${filePath}`);
    }
    return;
  }
})
releases.forEach((release) => {
  const { name } = release;
  const artifactPath = path.resolve(__dirname, "../artifacts", name);
  if (!process.env.DRY_RUN) {
    execSync(`git add --force -A ${artifactPath}`);
    console.log(`Committed ${artifactPath}...`);
  } else {
    console.log(`DRY_RUN: Verified ${artifactPath}...`);
  }
});
