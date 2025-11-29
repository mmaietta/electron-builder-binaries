const path = require("path");
const promisify = require("util").promisify;
const fs = require("fs");
const copy = promisify(fs.copyFile);


const sdkBase = process.env["WINDOWS_KIT_PATH"] || "C:\\Program Files (x86)\\Windows Kits\\10\\bin";

const dirContents = fs.readdirSync(sdkBase);
const versions = dirContents.filter((v) => /^10\./.test(v));
const VERSION = versions?.sort().pop();
if (!VERSION) {
  console.error("No Windows SDK version found in directory. Contents: ", dirContents);
  console.error("Available versions:", versions);
  process.exit(1);
}
console.log("Using Windows SDK version:", VERSION);
console.log("SDK base directory:", sdkBase);

const destination = path.resolve(__dirname, "../out/win-codesign/windows-kits");

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

function copyFiles(files, arch) {
  fs.mkdirSync(path.join(destination, arch), { recursive: true });
  return files.map(async (file) => {
    const src = path.join(sourceDir, arch, file);
    const dest = path.join(destination, arch, file);
    await copy(src, dest);
    console.log(`Copied ${arch} || ${file}`);
    return dest;
  });
}

// copy files
console.log("Copying files...");
Promise.all(["x86", "x64", "arm64"].flatMap(arch => copyFiles(files, arch)))
  .then((files) => {
    console.log("Files copied successfully. Total: ", files.length);
  })
  .catch((error) => {
    process.exitCode = 1;
    console.error(error);
  });


// add version file
fs.writeFileSync(path.join(destination, "VERSION.txt"), VERSION, "utf8");
