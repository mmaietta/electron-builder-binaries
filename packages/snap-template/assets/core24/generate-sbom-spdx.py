#!/usr/bin/env python3
import os
import sys
import json
import hashlib
import subprocess
from pathlib import Path

ROOT = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(".")
SBOM_OUT = sys.argv[2] if len(sys.argv) > 2 else "sbom.spdx.json"

def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while True:
            chunk = f.read(8192)
            if not chunk:
                break
            h.update(chunk)
    return h.hexdigest()

def is_elf(path):
    try:
        out = subprocess.check_output(["file", "-b", path], text=True)
        return "ELF" in out
    except:
        return False

packages = []
files_seen = set()

for root, _, files in os.walk(ROOT):
    for name in files:
        path = Path(root) / name
        if not path.is_file():
            continue
        if not is_elf(path):
            continue

        rel = str(path.relative_to(ROOT))
        files_seen.add(rel)

        pkg = {
            "name": path.name,
            "SPDXID": f"SPDXRef-{hash(rel)}",
            "versionInfo": "unknown",
            "supplier": "Organization: Canonical / Ubuntu",
            "filesAnalyzed": True,
            "licenseDeclared": "NOASSERTION",
            "licenseConcluded": "NOASSERTION",
            "checksums": [
                {
                    "algorithm": "SHA256",
                    "checksumValue": sha256(path)
                }
            ],
            "externalRefs": [],
            "primaryPackagePurpose": "LIBRARY"
        }

        packages.append(pkg)

sbom = {
    "spdxVersion": "SPDX-2.3",
    "dataLicense": "CC0-1.0",
    "SPDXID": "SPDXRef-DOCUMENT",
    "name": "electron-gnome-runtime",
    "documentNamespace": f"https://example.org/sbom/{hash(str(ROOT))}",
    "creationInfo": {
        "created": subprocess.check_output(["date", "-u", "+%Y-%m-%dT%H:%M:%SZ"], text=True).strip(),
        "creators": [
            "Tool: offline-snap-runtime-builder"
        ]
    },
    "packages": packages,
    "relationships": [
        {
            "spdxElementId": "SPDXRef-DOCUMENT",
            "relationshipType": "DESCRIBES",
            "relatedSpdxElement": pkg["SPDXID"]
        } for pkg in packages
    ]
}

with open(SBOM_OUT, "w") as f:
    json.dump(sbom, f, indent=2)

print(f"✅ SBOM generated: {SBOM_OUT}")
print(f"   Packages: {len(packages)}")
print(f"   Files: {len(files_seen)}")
for f in sorted(files_seen):
    print(f"   - {f}")