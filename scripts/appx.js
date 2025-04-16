const path = require("path")
const promisify = require("util").promisify
const copy = promisify(require("fs").copyFile)

const windowsKitsDir = "C:\\Program Files (x86)\\Microsoft SDKs\\Windows Kits\\10"
const sourceDir = path.resolve(windowsKitsDir, "bin\\10.0.26100")
const destination = path.join(__dirname, "../winCodeSign/windows-10")

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

function copyFiles(files, archWin, archNode) {
  return files.map(file => copy(path.join(sourceDir, archWin, file), path.join(destination, archNode, file)))
}

Promise.all([
  ...copyFiles(files, "x86", "ia32"),
  ...copyFiles(files, "x64", "x64"),
]).catch(error => {
  process.exitCode = 1
  console.error(error)
})

