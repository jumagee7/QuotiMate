#!/usr/bin/env bash
# Restore android/keystore/quotimate-release.jks + android/key.properties from the
# encrypted backup committed in signing/. Run once on any new machine after cloning.
set -euo pipefail

cd "$(dirname "$0")/.."
ENC=signing/quotimate-release.jks.enc
JKS=android/keystore/quotimate-release.jks
PROPS=android/key.properties
EXPECTED_SHA256=c490ceeb7a08dd94711e7635f7c26e5be8f18e3c58bee59370127d0a58aded87

[ -f "$ENC" ] || { echo "Missing $ENC — run signing/backup_signing.sh on the machine that has the keystore."; exit 1; }
command -v openssl >/dev/null || { echo "openssl is required (Git Bash ships it)."; exit 1; }

if [ -f "$JKS" ] && [ "${1:-}" != "--force" ]; then
  echo "$JKS already exists; nothing to restore. Use --force to overwrite."
  exit 0
fi

if [ -n "${QT_BACKUP_PASS:-}" ]; then
  pass=$QT_BACKUP_PASS
else
  read -r -s -p "Backup passphrase: " pass || true; echo
fi
[ -n "$pass" ] || { echo "Empty passphrase — aborted."; exit 1; }

mkdir -p android/keystore
tmp="${JKS}.tmp"
trap 'rm -f "$tmp"' EXIT
printf '%s' "$pass" | openssl enc -d -aes-256-cbc -pbkdf2 -iter 600000 -md sha256 \
  -in "$ENC" -out "$tmp" -pass stdin
unset pass

if ! command -v keytool >/dev/null; then
  echo "keytool not found — install a JDK (Android Studio bundles one) and retry."
  exit 1
fi

read -r -s -p "Keystore store password: " storePass || true; echo
[ -n "$storePass" ] || { echo "Empty store password — aborted."; exit 1; }

export QT_STORE_PASS="$storePass"
alias=$(keytool -list -keystore "$tmp" -storepass:env QT_STORE_PASS 2>/dev/null \
  | awk -F, '/PrivateKeyEntry/{print $1}' | head -1)
[ -n "$alias" ] || { echo "Could not read the keystore — wrong passphrase or wrong backup file."; exit 1; }

read -r -s -p "Key password (Enter = same as store password): " keyPass || true; echo
[ -n "$keyPass" ] || keyPass=$storePass

actual=$(keytool -list -v -keystore "$tmp" -alias "$alias" -storepass:env QT_STORE_PASS 2>/dev/null \
  | awk -F': ' '/SHA256:/{print $2; exit}' | tr -d ':' | tr 'A-F' 'a-f')

mv "$tmp" "$JKS"

{
  printf 'storePassword=%s\n' "$storePass"
  printf 'keyPassword=%s\n' "$keyPass"
  printf 'keyAlias=%s\n' "$alias"
  printf 'storeFile=keystore/quotimate-release.jks\n'
} > "$PROPS"
chmod 600 "$PROPS"
unset storePass keyPass QT_STORE_PASS

if [ "$actual" != "$EXPECTED_SHA256" ]; then
  echo
  echo "WARNING: signer certificate SHA-256 is $actual"
  echo "Expected: $EXPECTED_SHA256"
  echo "This is not the QuotiMate release key — do not ship builds signed with it."
  exit 1
fi

echo
echo "Restored:"
echo "  $JKS (alias: $alias)"
echo "  $PROPS"
echo "Certificate SHA-256 matches the released QuotiMate key."
echo "Release builds now sign automatically — verify each APK with signing/verify_apk.sh."
