# Release signing

QuotiMate updates only install over existing installs when they are signed with the
same key, so the release keystore must survive losing `android/keystore/`.

## Local backup (primary)

`signing/local/` holds the working copies inside the project folder:

| File | Contents |
| --- | --- |
| `quotimate-release.jks` | Byte-identical copy of the release keystore |
| `key.properties` | Same credentials, but `storeFile=signing/local/quotimate-release.jks` |

Both are git-ignored, so they never leave the machine. `android/app/build.gradle.kts`
uses `android/key.properties` when it exists and otherwise falls back to
`signing/local/key.properties`, resolving `storeFile` against both the `android/`
directory and the repo root. A release build therefore keeps signing with this key
even if `android/key.properties` or `android/keystore/` is lost.

Moving to another computer: copy the whole project folder (including the git-ignored
`signing/local/` directory), or make the encrypted backup below.

Expected signer certificate SHA-256:
`c490ceeb7a08dd94711e7635f7c26e5be8f18e3c58bee59370127d0a58aded87`
(DN: `CN=QuotiMate, OU=App, O=QuotiMate, L=Kolkata, ST=West Bengal, C=IN`)

## Optional: encrypted copy in git

For a fresh `git clone` on another machine, an encrypted keystore can be committed.
The repository is public, so the plaintext keystore and `key.properties` must never
be committed.

```bash
bash signing/backup_signing.sh   # asks for a passphrase, writes signing/quotimate-release.jks.enc
```

Commit the `.enc`, and keep the passphrase plus the keystore store/key passwords and
alias in a password manager. On the new machine:

```bash
bash signing/restore_signing.sh  # decrypts, prompts for passwords, writes android/key.properties
```

The script refuses to finish unless the certificate matches the fingerprint above.
Set `QT_BACKUP_PASS` only for non-interactive runs.

## Before publishing a build

```bash
bash signing/verify_apk.sh build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

The Gradle config also fails a release build outright when no keystore can be found,
instead of silently falling back to debug signing.

## Rules

- Never commit `android/key.properties`, `android/keystore/`, or `signing/local/`.
- Keep the keystore passwords and alias in a password manager — the backup is
  worthless without them.
- Losing the key means no further updates to existing installs, only a new listing.
