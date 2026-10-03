#!/usr/bin/env bash
set -Eeuo pipefail
ROOT=$(cd "$(dirname "$0")" && pwd)
cd "$ROOT"
mkdir -p logs build/original build/patched
# Keep every build command and its output; the calling session also records it.
exec > >(tee -a logs/build.log) 2>&1
PS4='+ ${BASH_SOURCE##*/}:${LINENO}: '
set -x
trap 'echo "Build failed at line $LINENO"' ERR
ISO=downloads/ubuntu-20.04.6-live-server-amd64.iso
test -s "$ISO"
if [[ -f tools/local/usr/share/keyrings/ubuntu-archive-keyring.gpg ]]; then
    UBUNTU_KEY="$ROOT/tools/local/usr/share/keyrings/ubuntu-archive-keyring.gpg"
else
    UBUNTU_KEY=/usr/share/keyrings/ubuntu-archive-keyring.gpg
fi
gpgv --keyring "$UBUNTU_KEY" downloads/SHA256SUMS.gpg downloads/SHA256SUMS
(cd downloads && grep 'ubuntu-20.04.6-live-server-amd64.iso$' SHA256SUMS | sha256sum -c -)
# ISO directories are read-only after extraction; allow the next build to replace them.
chmod -R u+w build/original
tools/xorriso -osirrox on -overwrite on -indev "$ISO" -extract /boot/grub build/original/boot/grub -extract /isolinux build/original/isolinux -extract /md5sum.txt build/original/md5sum.txt
python3 tools/customize_iso.py
# Update the original media checksums for all changed and added files.
python3 - <<'PY'
import hashlib
import pathlib
root = pathlib.Path('.')
changed = {}
for path in (root / 'build/patched').rglob('*'):
    if path.is_file():
        changed['./' + path.relative_to(root / 'build/patched').as_posix()] = path
for filename in ('user-data', 'meta-data'):
    changed['./nocloud/' + filename] = root / 'nocloud' / filename
changed['./course-setup/keys/ros-snapshot.asc'] = root / 'keys/ros-snapshot.asc'
lines = []
for line in (root / 'build/original/md5sum.txt').read_text().splitlines():
    checksum, filename = line.split(None, 1)
    filename = filename.lstrip('*')
    if filename not in changed:
        lines.append(line)
for filename, path in sorted(changed.items()):
    lines.append(hashlib.md5(path.read_bytes()).hexdigest() + '  ' + filename)
(root / 'build/md5sum.txt').write_text('\n'.join(lines) + '\n')
PY
OUTPUT=course-ubuntu-20.04.iso
if [[ -e "$OUTPUT.part" ]]; then rm "$OUTPUT.part"; fi
tools/xorriso -indev "$ISO" -outdev "$OUTPUT.part" -overwrite on \
    -map build/patched/boot/grub/grub.cfg /boot/grub/grub.cfg \
    -map build/patched/boot/grub/loopback.cfg /boot/grub/loopback.cfg \
    -map build/patched/isolinux/txt.cfg /isolinux/txt.cfg \
    -map build/patched/isolinux/isolinux.cfg /isolinux/isolinux.cfg \
    -map nocloud/user-data /nocloud/user-data \
    -map nocloud/meta-data /nocloud/meta-data \
    -map keys/ros-snapshot.asc /course-setup/keys/ros-snapshot.asc \
    -map build/md5sum.txt /md5sum.txt \
    -boot_image any replay -compliance no_emul_toc
mv "$OUTPUT.part" "$OUTPUT"
sha256sum "$OUTPUT" > "$OUTPUT.sha256"
tools/xorriso -indev "$OUTPUT" -report_el_torito plain -report_system_area plain -ls /nocloud
cat "$OUTPUT.sha256"
