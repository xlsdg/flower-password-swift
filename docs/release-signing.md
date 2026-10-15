# Release signing certificate

One fixed self-signed certificate re-signs every release. macOS pins Accessibility grants to it, so it must never change (see Code signing in [architecture.md](architecture.md)).

## Where it lives

- GitHub secrets: `SIGNING_CERTIFICATE_P12` (base64 `.p12`), `SIGNING_CERTIFICATE_PASSWORD`.
- Backup: maintainer's password manager, entry `FlowerPassword code signing` (password field = `.p12` password; note = where the `.p12` is stored).

The Sparkle update key `ED25519_PRIVATE_KEY` (base64 32-byte Ed25519 seed) is separate. Its public half is `SUPublicEDKey` in `FlowerPassword/Info.plist`; CI refuses to publish on a mismatch. Never rotate it either: installs trust only the key they shipped with.

## Restore secrets from backup

```bash
base64 -i FlowerPassword-signing.p12 | gh secret set SIGNING_CERTIFICATE_P12 -R xlsdg/flower-password-swift
printf '%s' "$PASSWORD" | gh secret set SIGNING_CERTIFICATE_PASSWORD -R xlsdg/flower-password-swift
```

Verify: the SHA-1 fingerprint must equal the `certificate leaf` hash from `codesign -d -r- /Applications/FlowerPassword.app`:

```bash
openssl pkcs12 -in FlowerPassword-signing.p12 -nokeys -passin pass:"$PASSWORD" \
  | openssl x509 -noout -fingerprint -sha1
```

## Create a new certificate (backup lost only)

Every user loses the Accessibility grant once and must re-enable Auto-Type; say so in the release notes.

```bash
D=$(mktemp -d) && cd "$D"
cat > cert.cnf <<'EOF'
[req]
distinguished_name=dn
x509_extensions=ext
prompt=no
[dn]
CN=FlowerPassword Code Signing
[ext]
basicConstraints=critical,CA:false
keyUsage=critical,digitalSignature
extendedKeyUsage=critical,codeSigning
EOF
# 100-year validity: an expired certificate can fail Sparkle's code-signature check.
openssl req -x509 -newkey rsa:2048 -nodes -keyout key.pem -out cert.pem -days 36500 -config cert.cnf
PASSWORD=$(openssl rand -base64 24)
openssl pkcs12 -export -inkey key.pem -in cert.pem -out FlowerPassword-signing.p12 -passout pass:"$PASSWORD"
```

Then back up the `.p12` and `$PASSWORD`, set both secrets as above, and `rm -rf "$D"` (`key.pem` is the unencrypted private key).
