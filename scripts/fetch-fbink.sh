#!/bin/sh
# Fetch the original author build; no system/hotfix FBInk is replaced.
set -eu
BASE=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
TEMP=$(mktemp -d)
trap 'rm -rf "$TEMP"' EXIT
trap 'exit 1' HUP INT TERM
curl -fL --connect-timeout 15 --max-time 180 \
    'https://www.mobileread.com/forums/attachment.php?attachmentid=198200&d=1670270603' \
    -o "$TEMP/fbink.tar.gz"
python3 - "$TEMP/fbink.tar.gz" "$BASE/clock/bin/fbink" <<'PY'
import hashlib, pathlib, sys, tarfile
archive, target = map(pathlib.Path, sys.argv[1:])
assert hashlib.sha256(archive.read_bytes()).hexdigest() == '1a1368671cb39f90cac337cf8e9ccea188bb82ff3c855a9c55d21cdc85c79a8d', 'Archive checksum mismatch'
with tarfile.open(archive, 'r:gz') as tar:
    data = tar.extractfile('PW2/bin/fbink').read()
assert hashlib.sha256(data).hexdigest() == 'b6e9b97f7f9f2945d7792674420f5767d9a2ff437a9e6b96893bf03f4ad027c4', 'Binary checksum mismatch'
target.parent.mkdir(parents=True, exist_ok=True)
target.write_bytes(data)
target.chmod(0o755)
print('FBInk 1.25.0 PW2 ready:', target)
PY
