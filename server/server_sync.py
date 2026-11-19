#!/usr/bin/env python3
"""Synchronize server mods before starting Minecraft."""
import hashlib
import json
import os
import re
import shutil
import sys
import tempfile
import urllib.parse
import urllib.request
import zipfile
from pathlib import Path

MANIFEST = os.environ.get("MODSYNC_MANIFEST", "https://mods.hysquib.cn/mods/manifest.json")
ROOT = Path.cwd()
MODS = ROOT / "mods"
BACKUPS = ROOT / "modsync-backups"
# Taiyitist supplies Fabric API modules. This package was absent from the server's mods directory.
SERVER_EXCLUSIONS = {"fabric-api"}

def mod_id(path):
    try:
        with zipfile.ZipFile(path) as jar:
            return json.loads(jar.read("fabric.mod.json")).get("id")
    except (OSError, KeyError, ValueError, zipfile.BadZipFile):
        return None

def digest(path):
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()

def main():
    MODS.mkdir(exist_ok=True)
    with urllib.request.urlopen(MANIFEST, timeout=30) as response:
        manifest = json.load(response)
    if manifest.get("format") != 1 or not isinstance(manifest.get("mods"), list) or not manifest["mods"]:
        raise ValueError("Invalid or empty manifest")
    entries = {}
    names = set()
    for mod in manifest["mods"]:
        name, identity, checksum = mod["name"], mod["id"], mod["sha256"]
        if (not re.fullmatch(r"[A-Za-z0-9_+()\[\]. -]+\.jar", name)
            or not re.fullmatch(r"[a-z][a-z0-9_-]+", identity)
            or not re.fullmatch(r"[a-f0-9]{64}", checksum)
            or identity in entries or name.lower() in names):
            raise ValueError("Invalid or duplicate manifest entry")
        entries[identity] = mod
        names.add(name.lower())
    entries = {key: value for key, value in entries.items() if key not in SERVER_EXCLUSIONS}
    existing = list(MODS.glob("*.jar"))
    old = []
    needed = []
    for identity, mod in entries.items():
        target = MODS / mod["name"]
        if target.exists() and mod_id(target) != identity:
            raise ValueError("Conflicting filename: " + target.name)
        if not target.exists() or digest(target) != mod["sha256"]:
            needed.append(mod)
            if target.exists():
                old.append(target)
        old.extend(p for p in existing if p != target and mod_id(p) == identity)
    if not needed and not old:
        print("[modsync] All managed mods are up to date.")
        return
    BACKUPS.mkdir(exist_ok=True)
    stage = Path(tempfile.mkdtemp(prefix="run-", dir=BACKUPS))
    backup = stage / "backup"
    downloads = stage / "downloads"
    backup.mkdir()
    downloads.mkdir()
    for mod in needed:
        url = urllib.parse.urljoin(MANIFEST, urllib.parse.quote(mod["name"]))
        path = downloads / mod["name"]
        with urllib.request.urlopen(url, timeout=120) as response, path.open("wb") as output:
            shutil.copyfileobj(response, output)
        if digest(path) != mod["sha256"] or mod_id(path) != mod["id"]:
            raise ValueError("Downloaded file did not pass verification: " + mod["name"])
    moved = []
    installed = []
    try:
        for path in old:
            os.replace(path, backup / path.name)
            moved.append(path.name)
        for mod in needed:
            path = MODS / mod["name"]
            os.replace(downloads / mod["name"], path)
            installed.append(path)
    except Exception:
        for path in installed:
            path.unlink(missing_ok=True)
        for name in moved:
            os.replace(backup / name, MODS / name)
        raise
    print(f"[modsync] Installed {len(installed)}; backed up {len(moved)} to {backup}")

if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print("[modsync] Synchronization failed:", error, file=sys.stderr)
        sys.exit(1)
