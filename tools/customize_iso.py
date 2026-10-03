#!/usr/bin/env python3
"""Generate NoCloud data and patch both UEFI GRUB and legacy BIOS menus."""
import hashlib
import os
import pathlib
import re
import subprocess
import yaml

root = pathlib.Path(__file__).resolve().parents[1]
revision = os.environ.get('SETUP_REF') or subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip()
if not re.fullmatch(r'[0-9a-f]{40}', revision):
    raise SystemExit('SETUP_REF must be an immutable 40-character Git commit SHA')
committed_script = subprocess.check_output(['git', 'show', revision + ':setup.sh'], cwd=root)
if committed_script != (root / 'setup.sh').read_bytes():
    raise SystemExit('Commit setup.sh before building: local source differs from SETUP_REF')
password_hash = subprocess.check_output(['openssl', 'passwd', '-6', '-stdin'], input='hogehoge\n', text=True).strip()
setup_url = f'https://raw.githubusercontent.com/yoshi-rob/course-pc-setup/{revision}/setup.sh'
setup_sha = hashlib.sha256(committed_script).hexdigest()
template = (root / 'nocloud/user-data.template').read_text()
config = template.replace('@PASSWORD_HASH@', password_hash).replace('@SETUP_URL@', setup_url).replace('@SETUP_SHA256@', setup_sha)
data = yaml.safe_load(config)['autoinstall']
assert data['interactive-sections'] == ['network', 'storage']
assert 'storage' not in data and 'network' not in data
assert '@SETUP' not in config
(root / 'nocloud/user-data').write_text(config)
(root / 'nocloud/meta-data').write_text('')
subprocess.run(['curl', '-fsSL', '--retry', '3', setup_url, '-o', str(root / 'build/published-setup.sh')], check=True)
assert (root / 'build/published-setup.sh').read_bytes() == committed_script, 'GitHub source differs'

for relative in ['boot/grub/grub.cfg', 'boot/grub/loopback.cfg', 'isolinux/txt.cfg']:
    original = root / 'build/original' / relative
    if not original.exists():
        continue
    text = original.read_text()
    if relative.startswith('boot/grub/'):
        text = re.sub(r'^set timeout=.*$', 'set timeout=5', text, flags=re.M)
        # GRUB removes quotes, preserving the semicolon within the ds argument.
        text, count = re.subn(r'(?m)^(\s*linux\s+[^\n]*?)\s+---', r"\1 autoinstall ds='nocloud;s=/cdrom/nocloud/' ---", text)
    else:
        # ISOLINUX does not interpret shell quoting; use a bare semicolon.
        text, count = re.subn(r'(?m)^(\s*append\s+[^\n]*?)\s+---', r'\1 autoinstall ds=nocloud;s=/cdrom/nocloud/ ---', text)
    assert count > 0, f'No install kernel found in {relative}'
    text = text.replace('Install Ubuntu Server', 'Install Course Ubuntu 20.04')
    destination = root / 'build/patched' / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(text)
    print(f'Patched {relative}: {count} boot entries')

syslinux = root / 'build/original/isolinux/isolinux.cfg'
if syslinux.exists():
    text = re.sub(r'(?m)^timeout\s+\d+', 'timeout 50', syslinux.read_text())
    (root / 'build/patched/isolinux/isolinux.cfg').write_text(text)
print('Pinned setup URL:', setup_url)
print('setup.sh SHA256:', setup_sha)
(root / 'build/setup-ref.txt').write_text(revision + '\n')
