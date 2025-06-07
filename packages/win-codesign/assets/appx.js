const path = require("path");
const promisify = require("util").promisify;
const fs = require("fs");
const copy = promisify(fs.copyFile);

const destination = path.resolve(__dirname, "../out/win-codesign/windows-10");

const sdkBase = process.env["WINDOWS_KIT_PATH"] || "C:\\Program Files (x86)\\Windows Kits\\10\\bin";

const versions = fs.readdirSync(sdkBase).filter((v) => /^10\./.test(v));
const VERSION = versions?.sort().pop();
if (!VERSION) {
  console.error("No Windows SDK version found in", sdkBase);
  console.error("Available versions:", fs.readdirSync(sdkBase));
  process.exit(1);
}
console.log("Using Windows SDK version:", VERSION);
console.log("SDK base directory:", sdkBase);
console.log("Destination directory:", destination);

// Ensure the destination directory exists
if (!fs.existsSync(destination)) {
  fs.mkdirSync(destination, { recursive: true });
}

const files = [
  "appxpackaging.dll",
  "makeappx.exe",
  "makecert.exe",

  "makecat.exe",
  "makecat.exe.manifest",

  "Microsoft.Windows.Build.Signing.mssign32.dll.manifest",
  "mssign32.dll",

  "Microsoft.Windows.Build.Appx.AppxSip.dll.manifest",
  "appxsip.dll",

  "Microsoft.Windows.Build.Signing.wintrust.dll.manifest",
  "wintrust.dll",

  "makepri.exe",
  "Microsoft.Windows.Build.Appx.AppxPackaging.dll.manifest",
  "Microsoft.Windows.Build.Appx.OpcServices.dll.manifest",
  "opcservices.dll",
  "signtool.exe",
  "signtool.exe.manifest",
  "pvk2pfx.exe",
];

const sourceDir = path.resolve(sdkBase, VERSION);

function copyFiles(files, archWin, archNode) {
  fs.mkdirSync(path.join(destination, archNode), { recursive: true });
  return files.map(async (file) => {
    await copy(path.join(sourceDir, archWin, file), path.join(destination, archNode, file));
    console.log("Copied:", file);
    return file;
  });
}

// copy files
console.log("Copying files...");
Promise.all([...copyFiles(files, "x86", "x86"), ...copyFiles(files, "x64", "x64"), ...copyFiles(files, "arm64", "arm64")])
  .then((_files) => {
    console.log("Files copied successfully");
  })
  .catch((error) => {
    process.exitCode = 1;
    console.error(error);
  });

// add version file
fs.writeFileSync(path.join(destination, "VERSION.txt"), VERSION, "utf8");
