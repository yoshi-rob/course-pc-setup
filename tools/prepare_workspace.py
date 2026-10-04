#!/usr/bin/env python3
"""Prepare only lesson 1 workspace sources; keep course code out of public Git."""
import argparse, gzip, hashlib, io, pathlib, tarfile

root = pathlib.Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('workspace', type=pathlib.Path, help='Original coins_ws directory')
args = parser.parse_args()
source = args.workspace / 'src'
assert (source / 'coins_ex/package.xml').is_file()
assert (source / 'ypspur_ros/package.xml').is_file()
destination = root / 'local-assets/coins_ws-src.tar.gz'
destination.parent.mkdir(exist_ok=True)
with destination.open('wb') as output, gzip.GzipFile(fileobj=output, mode='wb', filename='', mtime=0) as compressed, tarfile.open(fileobj=compressed, mode='w') as archive:
    for path in sorted(source.rglob('*')):
        relative = path.relative_to(source)
        if any(part in ('.git', '__pycache__') for part in relative.parts):
            continue
        # catkin_make recreates this machine-specific link.
        if relative.as_posix() == 'CMakeLists.txt':
            continue
        if path.is_symlink():
            raise RuntimeError(f'Unexpected source symlink: {relative}')
        name = 'src/' + relative.as_posix().replace('sbeego', 'speego')
        entry = tarfile.TarInfo(name)
        entry.uid = entry.gid = entry.mtime = 0
        entry.uname = entry.gname = ''
        if path.is_dir():
            entry.type = tarfile.DIRTYPE
            entry.mode = 0o755
            archive.addfile(entry)
        elif path.is_file():
            content = path.read_bytes()
            try:
                content = content.decode('utf-8').replace('sbeego', 'speego').encode('utf-8')
            except UnicodeDecodeError:
                pass
            entry.mode = 0o755 if path.suffix in ('.py', '.sh') else 0o644
            entry.size = len(content)
            archive.addfile(entry, io.BytesIO(content))
digest = hashlib.sha256(destination.read_bytes()).hexdigest()
(root / 'course-workspace.sha256').write_text(digest + '  coins_ws-src.tar.gz\n')
print('Local-only workspace:', destination)
print('SHA256:', digest)
with tarfile.open(destination) as archive:
    names = archive.getnames()
    assert 'src/coins_ex/launch/urg_speego.launch' in names
    assert not any('sbeego' in name or name.startswith(('build/', 'devel/')) for name in names)
    print('Archive entries:', len(names))
