const path = require("path")
const promisify = require("util").promisify
const fs = require("fs")
const copy = promisify(fs.copyFile)

const VERSION = "10.0.26100.0"

const windowsKitsDir = "C:\\Program Files (x86)\\Windows Kits\\10"
const sourceDir = path.resolve(windowsKitsDir, "bin", VERSION)
const destination = path.join(__dirname, "../out/winCodeSign/windows-kits")

// noinspection SpellCheckingInspection
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
  "pvk2pfx.exe"
]

function copyFiles(files, archWin) {
  fs.mkdirSync(path.join(destination, archWin), { recursive: true })
  return files.map(async file => {
    const sourceFilePath = path.join(sourceDir, archWin, file)
    console.log(`- ${sourceFilePath}`)
    await copy(sourceFilePath, path.join(destination, archWin, file))
    return file
  })
}

// copy files
Promise.all([
  ...copyFiles(files, "x86"),
  ...copyFiles(files, "x64"),
  ...copyFiles(files, "arm64"),
])
.then(files => {
  console.log("Files copied successfully")
})
.catch(error => {
  console.error(error)
  process.exit(1)
})

// add version file
fs.writeFileSync(
  path.join(destination, "VERSION"),
  VERSION,
  "utf8"
)