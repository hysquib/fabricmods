"""Build the Pages site with the same-origin download address in the client."""
import json
import shutil
import subprocess
import sys
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

base = sys.argv[1].rstrip('/')
site = Path('_site')
site.mkdir(exist_ok=False)
destination = site / 'mods'
if any(Path('data/mods').glob('*.jar')):
    subprocess.run([sys.executable, 'publish.py', 'data/mods', str(destination)], check=True)
else:
    destination.mkdir()
    (destination / 'manifest.json').write_text(json.dumps({'format': 1, 'mods': []}))
shutil.copyfile('web/index.html', site / 'index.html')
with ZipFile(site / 'FabricModSync.zip', 'w', ZIP_DEFLATED) as package:
    for name in ('ModSync.exe', 'Sync.ps1'):
        package.write(Path('Client') / name, name)
    package.writestr('server.txt', base + '/mods/manifest.json\n')
