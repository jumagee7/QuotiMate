#!/usr/bin/env bash
# Encrypt this machine's release keystore into signing/quotimate-release.jks.enc.
# Run once on the machine that holds the original keystore, then commit the .enc.
set -euo pipefail

cd "$(dirname "$0")/.."
SRC=android/keystore/quotimate-release.jks
OUT=signing/quotimate-release.jks.enc

[ -f "$SRC" ] || { echo "No keystore at $SRC — nothing to back up."; exit 1; }
command -v openssl >/dev/null || { echo "openssl is required (Git Bash ships it)."; exit 1; }

if [ -f "$OUT" ]; then
  read -r -p "$OUT already exists. Overwrite? [y/N] " answer
  [[ "$answer" == [yY] ]] || { echo "Aborted."; exit 1; }
fi

if [ -n "${QT_BACKUP_PASS:-}" ]; then
  pass=$QT_BACKUP_PASS
else
  while true; do
    read -r -s -p "Backup passphrase (store it in a password manager): " p1 || true; echo
    read -r -s -p "Confirm passphrase: " p2 || true; echo
    [ -n "$p1" ] && [ "$p1" = "$p2" ] && { pass=$p1; unset p1 p2; break; }
    [ -n "$p1" ] || break
    echo "Passphrases do not match. Try again."
  done
fi

[ -n "$pass" ] || { echo "Empty passphrase — aborted."; exit 1; }

tmp="${OUT}.tmp"
printf '%s' "$pass" | openssl enc -aes-256-cbc -pbkdf2 -iter 600000 -md sha256 -salt \
  -in "$SRC" -out "$tmp" -pass stdin
unset pass
mv "$tmp" "$OUT"

echo
echo "Encrypted backup written: $OUT"
echo "Next steps:"
echo "  1. git add signing/quotimate-release.jks.enc"
echo "  2. git commit -m 'Add encrypted release keystore backup' && git push"
echo "  3. Keep the passphrase (and keystore passwords) in a password manager."
