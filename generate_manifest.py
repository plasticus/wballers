import os
import json
import sys
from pathlib import Path

FOLDERS = {
    'hair': 'hair',
    'eyes': 'eyes',
    'eyebrows': 'eyebrows',
    'nose': 'nose',
    'mouth': 'mouth',
    'facial': 'facial',
    'accessories': 'accessories',
    'shoulders': 'shoulders',
    'hats': 'hats',
    'glasses': 'glasses'
}

root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path('.')
manifest = {}
for key, folder in FOLDERS.items():
    path = root / folder
    if not path.is_dir():
        manifest[key] = []
        continue
    files = sorted([
        f for f in path.iterdir()
        if f.is_file() and f.suffix.lower() in ('.png', '.jpg', '.jpeg', '.gif', '.webp')
    ])
    manifest[key] = [f.name for f in files]

out = root / 'manifest.json'
with open(out, 'w') as f:
    json.dump(manifest, f, indent=2)

print(f'{out} generated:')
print(json.dumps(manifest, indent=2))
