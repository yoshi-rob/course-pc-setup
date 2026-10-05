#!/usr/bin/env python3
"""Generate NoCloud data and patch both UEFI GRUB and legacy BIOS menus."""
import hashlib
import pathlib
import re
import subprocess
import yaml

root = pathlib.Path(__file__).resolve().parents[1]
workspace_manifest = (root / 'course-workspace.sha256').read_bytes()
expected_digest, archive_name = workspace_manifest.decode().split()
assert archive_name == 'coins_ws-src.tar.gz'
assert hashlib.sha256((root / 'local-assets' / archive_name).read_bytes()).hexdigest() == expected_digest, 'Workspace archive differs from ISO manifest'
password_hash = subprocess.check_output(['openssl', 'passwd', '-6', '-stdin'], input='student1\n', text=True).strip()
template = (root / 'nocloud/user-data.template').read_text()
config = template.replace('@PASSWORD_HASH@', password_hash)
data = yaml.safe_load(config)['autoinstall']
assert data['identity']['username'] == 'student1'
assert data['interactive-sections'] == ['network', 'storage']
assert 'storage' not in data and 'network' not in data
assert '@SETUP' not in config
(root / 'nocloud/user-data').write_text(config)
(root / 'nocloud/meta-data').write_text('')

for relative in ['boot/grub/grub.cfg', 'boot/grub/loopback.cfg', 'isolinux/txt.cfg']:
    original = root / 'build/original' / relative
    if not original.exists():
        continue
    text = original.read_text()
    # Boot the official ISO's matching HWE kernel/initrd by default.
    # Keep its GA kernel as an explicit fallback for older machines.
    if relative == 'boot/grub/grub.cfg':
        primary, separator, fallback = text.partition("submenu 'Boot and Install with the HWE kernel'")
        assert separator, 'Official HWE boot entry is missing'
        primary = primary.replace('/casper/vmlinuz', '/casper/hwe-vmlinuz').replace('/casper/initrd', '/casper/hwe-initrd')
        fallback = fallback.replace('/casper/hwe-vmlinuz', '/casper/vmlinuz').replace('/casper/hwe-initrd', '/casper/initrd')
        text = primary + "submenu 'Fallback: install with the 5.4 kernel'" + fallback
    elif relative == 'boot/grub/loopback.cfg':
        text = text.replace('/casper/vmlinuz', '/casper/hwe-vmlinuz').replace('/casper/initrd', '/casper/hwe-initrd')
    else:
        primary, separator, fallback = text.partition('label hwe-live')
        assert separator, 'Official BIOS HWE boot entry is missing'
        primary = primary.replace('/casper/vmlinuz', '/casper/hwe-vmlinuz').replace('/casper/initrd', '/casper/hwe-initrd')
        fallback = fallback.replace('/casper/hwe-vmlinuz', '/casper/vmlinuz').replace('/casper/hwe-initrd', '/casper/initrd')
        fallback = fallback.replace('Install Ubuntu Server with the HWE kernel', 'Install Ubuntu Server (fallback: 5.4 kernel)')
        text = primary + 'label hwe-live' + fallback
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
print('Setup source: latest main from https://github.com/yoshi-rob/course-pc-setup')
