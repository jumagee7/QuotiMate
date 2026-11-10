#!/usr/bin/env bash
# Print the signer certificate of an APK and compare it to the QuotiMate release key.
set -euo pipefail

cd "$(dirname "$0")/.."
apk=${1:?usage: bash signing/verify_apk.sh path/to/app.apk}
expected=c490ceeb7a08dd94711e7635f7c26e5be8f18e3c58bee59370127d0a58aded87

sdk=${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}
[ -n "$sdk" ] || for d in "$HOME/AppData/Local/Android/Sdk" "$HOME/Library/Android/sdk" "$HOME/Android/Sdk"; do
  [ -d "$d" ] && { sdk=$d; break; }
done
apksigner=$(ls "$sdk"/build-tools/*/apksigner* 2>/dev/null | sort -V | tail -1)
[ -n "$apksigner" ] || { echo "apksigner not found — set ANDROID_HOME."; exit 1; }

actual=$("$apksigner" verify --print-certs "$apk" | awk -F': ' '/SHA-256 digest/{print $2; exit}' | tr 'A-F' 'a-f')
echo "APK:    $apk"
echo "Signer: $actual"

if [ "$actual" = "$expected" ]; then
  echo "OK: signed with the QuotiMate release key."
else
  echo "MISMATCH — expected $expected"
  echo "Do not publish this APK: existing installs will reject the update."
  exit 1
fi
