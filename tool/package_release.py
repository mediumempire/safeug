"""Package only deployable code/assets; never include records or signing keys."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import shutil
import tarfile

parser = argparse.ArgumentParser()
parser.add_argument('--apk', type=Path, help='Optional production-signed APK')
parser.add_argument('--output', type=Path, default=Path('output/releases'))
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
version = re.search(r'^version:\s*(\S+)', (root/'pubspec.yaml').read_text(), re.M)[1]
app_version, build_number = version.split('+')
release = version + '-' + datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
for app in ['web', 'admin']:
    built = json.loads((root/f'build/{app}/version.json').read_text())
    if built['version'] != app_version or built['build_number'] != build_number:
        raise SystemExit(f'Rebuild {app}: version does not match pubspec.yaml')
    if not (root/f'build/{app}/main.dart.js').is_file():
        raise SystemExit(f'Missing {app} build')
stage = args.output.resolve()/release/'safeug-release'
stage.mkdir(parents=True, exist_ok=False)
(stage/'local').mkdir()
for source in (root/'local').glob('*.mjs'):
    if not source.name.endswith('.test.mjs'):
        shutil.copy2(source, stage/'local'/source.name)
for app in ['web', 'admin']:
    shutil.copytree(root/f'build/{app}', stage/f'build/{app}')
shutil.copytree(root/'deploy', stage/'deploy')
shutil.copytree(root/'local/catalog', stage/'local/catalog')
shutil.copytree(root/'landing', stage/'landing')
(stage/'docs').mkdir()
shutil.copy2(root/'docs/VPS-DEPLOYMENT.md', stage/'docs/VPS-DEPLOYMENT.md')
if args.apk:
    if not args.apk.is_file():
        raise SystemExit('APK not found')
    destination = stage/'build/web/downloads'
    destination.mkdir(exist_ok=True)
    shutil.copy2(args.apk, destination/'safeug.apk')
(stage/'release.json').write_text(json.dumps({'release':release,'version':version,'origin':'https://www.safeug.online','androidIncluded':bool(args.apk)},indent=2)+'\n')
archive = stage.parent/f'safeug-{release}.tar.gz'
with tarfile.open(archive, 'w:gz') as bundle:
    bundle.add(stage, arcname='safeug-release')
checksum = hashlib.file_digest(archive.open('rb'),'sha256').hexdigest()
archive.with_suffix(archive.suffix+'.sha256').write_text(f'{checksum}  {archive.name}\n')
print(archive)
print('Bundle excludes database, credentials and signing keys.')
