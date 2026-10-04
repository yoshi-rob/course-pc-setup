#!/usr/bin/env bash
# Run only inside the installed Ubuntu Focal target (curtin in-target).
set -Eeuo pipefail
COURSE_USER="student"
STUDENT_PASSWORD="hogehoge"
ROS_REPOSITORY="http://snapshots.ros.org/noetic/final/ubuntu"
SNAPSHOT_FINGERPRINT="4B63CF8FDE49746E98FA01DDAD19BAB3CBF125EA"

if [[ $(id -u) != 0 ]]; then
    echo "Run as root inside the installed Ubuntu 20.04 target." >&2
    exit 1
fi
# shellcheck disable=SC1091
source /etc/os-release
if [[ ${ID:-} != ubuntu || ${VERSION_CODENAME:-} != focal || $(dpkg --print-architecture) != amd64 ]]; then
    echo "Ubuntu 20.04 Focal amd64 is required; no changes were made." >&2
    exit 1
fi
exec > >(tee -a /var/log/course-setup.log) 2>&1
PS4='+ ${BASH_SOURCE##*/}:${LINENO}: '
set -x
on_error() {
    local status=$?
    echo "[ERROR] setup failed at line ${BASH_LINENO[0]} (exit ${status}); inspect /var/log/course-setup.log"
    exit "$status"
}
trap on_error ERR
export DEBIAN_FRONTEND=noninteractive
APT_OPTIONS=(-y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold -o Acquire::Retries=3)

# Subiquity defers identity user creation to cloud-init on the first boot.
# Desktop and rosdep need the user during late-commands, so create it now.
if ! getent passwd "$COURSE_USER" >/dev/null; then
    useradd -m -s /bin/bash -c Student -G adm,cdrom,dip,plugdev,sudo "$COURSE_USER"
fi

# Do not log the password value, even though this classroom default is public.
set +x
printf '%s:%s\n' "$COURSE_USER" "$STUDENT_PASSWORD" | chpasswd
set -x

apt-get update
apt-get install "${APT_OPTIONS[@]}" curl ca-certificates gnupg software-properties-common
add-apt-repository -y universe
apt-get update
apt-get install "${APT_OPTIONS[@]}" \
    ubuntu-desktop language-pack-ja language-pack-gnome-ja fonts-noto-cjk ibus-mozc \
    wget git vim nano unzip zip build-essential cmake pkg-config python3 python3-pip \
    sudo os-prober terminator
# Install the official Microsoft Debian package; avoid Snap in curtin's chroot.
MICROSOFT_KEY=$(mktemp)
curl -fsSL --retry 3 --connect-timeout 20 --max-time 180 \
    https://packages.microsoft.com/keys/microsoft.asc -o "$MICROSOFT_KEY"
gpg --batch --yes --dearmor -o /usr/share/keyrings/course-microsoft.gpg "$MICROSOFT_KEY"
rm -f "$MICROSOFT_KEY"
chmod 644 /usr/share/keyrings/course-microsoft.gpg
printf 'deb [arch=amd64 signed-by=/usr/share/keyrings/course-microsoft.gpg] https://packages.microsoft.com/repos/code stable main\n' \
    > /etc/apt/sources.list.d/course-vscode.list
# We manage the source and key above, so do not let code add a second source.
printf 'code code/add-microsoft-repo boolean false\n' | debconf-set-selections
apt-get update
apt-get install "${APT_OPTIONS[@]}" code

# Write student favorites before the first login, using a private session bus.
# Ubuntu's existing favorites and any user customizations are kept.
sudo -u "$COURSE_USER" -H env XDG_CURRENT_DESKTOP=ubuntu dbus-run-session -- python3 - <<'PY'
from pathlib import Path
from gi.repository import Gio

settings = Gio.Settings.new('org.gnome.shell')
favorites = settings.get_strv('favorite-apps')
for desktop_id in ('code.desktop', 'terminator.desktop'):
    if not (Path('/usr/share/applications') / desktop_id).is_file():
        raise RuntimeError(f'Missing application launcher: {desktop_id}')
    if desktop_id not in favorites:
        favorites.append(desktop_id)
if not settings.set_strv('favorite-apps', favorites):
    raise RuntimeError('Could not save the student favorites')
Gio.Settings.sync()
print('Student favorites:', favorites)
PY

locale-gen ja_JP.UTF-8
update-locale LANG=ja_JP.UTF-8 LANGUAGE=ja_JP:ja
# systemd is not running inside curtin's chroot: use files instead of *ctl calls.
ln -snf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime
printf 'Asia/Tokyo\n' > /etc/timezone
systemctl set-default graphical.target

# Preserve the network chosen in the installer and make it available in GNOME.
python3 - <<'PY'
import pathlib
import yaml
for path in pathlib.Path('/etc/netplan').glob('*.yaml'):
    config = yaml.safe_load(path.read_text()) or {}
    network = config.get('network')
    if not isinstance(network, dict):
        continue
    network['renderer'] = 'NetworkManager'
    for category in ('ethernets', 'wifis', 'bridges', 'bonds', 'vlans'):
        for interface in (network.get(category) or {}).values():
            if isinstance(interface, dict):
                interface.pop('renderer', None)
    path.write_text(yaml.safe_dump(config, sort_keys=False))
    path.chmod(0o600)
PY
netplan generate

# Snapshots use a DIFFERENT signing key from rosdistro/master/ros.key.
KEY_SOURCE="$(dirname "$(readlink -f "$0")")/keys/ros-snapshot.asc"
test -s "$KEY_SOURCE"
actual_fingerprint=$(gpg --batch --show-keys --with-colons "$KEY_SOURCE" | awk -F: '$1 == "fpr" { print $10; exit }')
test "$actual_fingerprint" = "$SNAPSHOT_FINGERPRINT"
gpg --batch --yes --dearmor -o /usr/share/keyrings/ros-snapshot-archive-keyring.gpg "$KEY_SOURCE"
chmod 644 /usr/share/keyrings/ros-snapshot-archive-keyring.gpg
printf 'deb [arch=amd64 signed-by=/usr/share/keyrings/ros-snapshot-archive-keyring.gpg] %s focal main\n' \
    "$ROS_REPOSITORY" > /etc/apt/sources.list.d/course-ros-noetic.list
apt-get update
apt-get install "${APT_OPTIONS[@]}" \
    ros-noetic-desktop-full python3-rosdep python3-rosinstall \
    python3-rosinstall-generator python3-wstool python3-catkin-tools

if [[ ! -f /etc/ros/rosdep/sources.list.d/20-default.list ]]; then
    rosdep init
fi
# Noetic is EOL; the ordinary rosdep update skips its distribution cache.
sudo -u "$COURSE_USER" -H rosdep update --include-eol-distros --rosdistro=noetic
usermod -aG dialout,video,plugdev "$COURSE_USER"
COURSE_HOME=$(getent passwd "$COURSE_USER" | cut -d: -f6)
touch "$COURSE_HOME/.bashrc"
if ! grep -Fxq 'source /opt/ros/noetic/setup.bash' "$COURSE_HOME/.bashrc"; then
    printf '\nsource /opt/ros/noetic/setup.bash\n' >> "$COURSE_HOME/.bashrc"
fi
install -d -o "$COURSE_USER" -g "$COURSE_USER" "$COURSE_HOME/catkin_ws" "$COURSE_HOME/catkin_ws/src"
sudo -u "$COURSE_USER" -H bash -c 'source /opt/ros/noetic/setup.bash; cd "$HOME/catkin_ws"; catkin_make'
if ! grep -Fxq 'source ~/catkin_ws/devel/setup.bash' "$COURSE_HOME/.bashrc"; then
    printf 'source ~/catkin_ws/devel/setup.bash\n' >> "$COURSE_HOME/.bashrc"
fi
chown "$COURSE_USER:$COURSE_USER" "$COURSE_HOME/.bashrc"

# Installer machine-id can still be empty or shared: persist our own unique ID.
install -d /var/lib/course-setup
if [[ ! -s /var/lib/course-setup/hostname ]]; then
    suffix=$(cut -c1-8 /proc/sys/kernel/random/uuid)
    printf 'course-%s\n' "$suffix" > /var/lib/course-setup/hostname
fi
NEW_HOSTNAME=$(cat /var/lib/course-setup/hostname)
printf '%s\n' "$NEW_HOSTNAME" > /etc/hostname
if grep -q '^127\.0\.1\.1[[:space:]]' /etc/hosts; then
    sed -i "s/^127\\.0\\.1\\.1[[:space:]].*/127.0.1.1 ${NEW_HOSTNAME}/" /etc/hosts
else
    printf '127.0.1.1 %s\n' "$NEW_HOSTNAME" >> /etc/hosts
fi
install -d /etc/default/grub.d
printf 'GRUB_DISABLE_OS_PROBER=false\nGRUB_TIMEOUT_STYLE=menu\nGRUB_TIMEOUT=5\n' > /etc/default/grub.d/99-course.cfg
update-grub
test -f /opt/ros/noetic/setup.bash
sudo -u "$COURSE_USER" -H bash -c 'source /opt/ros/noetic/setup.bash; test "$(rosversion -d)" = noetic; rosversion -d'
date --iso-8601=seconds > /var/lib/course-setup/complete
echo '[COURSE SETUP] completed successfully'
