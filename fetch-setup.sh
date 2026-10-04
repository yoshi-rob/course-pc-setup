#!/usr/bin/env bash
# Fetch one consistent snapshot of main; the installer runs setup.sh afterwards.
set -Eeuo pipefail
REPOSITORY_URL="https://github.com/yoshi-rob/course-pc-setup.git"
SETUP_BRANCH="main"
OUTPUT_DIR=${1:-/opt/course-setup}

command -v git >/dev/null
mkdir -p "$OUTPUT_DIR"
download_dir=$(mktemp -d "$OUTPUT_DIR/.setup-download.XXXXXX")
trap 'rm -rf "$download_dir"' EXIT
downloaded=false
for attempt in 1 2 3; do
    if GIT_TERMINAL_PROMPT=0 timeout 180 git clone --depth 1 --single-branch \
        --branch "$SETUP_BRANCH" --no-checkout "$REPOSITORY_URL" "$download_dir/source"; then
        downloaded=true
        break
    fi
    rm -rf "$download_dir/source"
done
if [[ $downloaded != true ]]; then
    echo "Could not fetch the latest setup from $REPOSITORY_URL." >&2
    exit 1
fi
revision=$(git -C "$download_dir/source" rev-parse --verify HEAD)
[[ $revision =~ ^[0-9a-f]{40}$ ]]
git -C "$download_dir/source" show "$revision:setup.sh" > "$download_dir/setup.sh"
bash -n "$download_dir/setup.sh"
chmod 755 "$download_dir/setup.sh"
mv "$download_dir/setup.sh" "$OUTPUT_DIR/setup.sh"
printf '%s\n' "$revision" > "$OUTPUT_DIR/setup-ref.txt"
(cd "$OUTPUT_DIR" && sha256sum setup.sh > setup.sh.sha256)
printf '[COURSE SETUP] fetched %s commit %s\n' "$SETUP_BRANCH" "$revision"
cat "$OUTPUT_DIR/setup.sh.sha256"
