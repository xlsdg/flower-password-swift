# Release signing certificate

CI re-signs every release with one fixed self-signed certificate (see "Code signing" in [architecture.md](architecture.md)). macOS pins Accessibility grants to the resulting designated requirement, so this certificate must stay the same for the life of the app.

## Where it lives

- GitHub secrets: `SIGNING_CERTIFICATE_P12` (base64 of the `.p12`) and `SIGNING_CERTIFICATE_PASSWORD`.
- Backup: the maintainer's password manager, entry `FlowerPassword code signing` (password field is the `.p12` password; the note says where the `.p12` file is stored).

The update-archive key (`ED25519_PRIVATE_KEY`) is separate; see the header of `scripts/sign-update.swift`.

## Restore the secrets from the backup

```bash
base64 -i FlowerPassword-signing.p12 | gh secret set SIGNING_CERTIFICATE_P12 -R xlsdg/flower-password-swift
printf '%s' "$PASSWORD" | gh secret set SIGNING_CERTIFICATE_PASSWORD -R xlsdg/flower-password-swift
```

Check the backup is the right certificate. The SHA-1 fingerprint must match the `certificate leaf` hash that `codesign -d -r- /Applications/FlowerPassword.app` prints:

```bash
openssl pkcs12 -in FlowerPassword-signing.p12 -nokeys -passin pass:"$PASSWORD" \
  | openssl x509 -noout -fingerprint -sha1
```

## Create a new certificate (only if the backup is lost)

Every existing user will lose the Accessibility grant once and must re-enable Auto-Type. Say so in the release notes.

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
# 100-year validity: an expired certificate can fail the updater's codesign check.
openssl req -x509 -newkey rsa:2048 -nodes -keyout key.pem -out cert.pem -days 36500 -config cert.cnf
PASSWORD=$(openssl rand -base64 24)
openssl pkcs12 -export -inkey key.pem -in cert.pem -out FlowerPassword-signing.p12 -passout pass:"$PASSWORD"
```

Then back up the `.p12` and `$PASSWORD`, set both secrets as above, and `rm -rf "$D"`, because `key.pem` is the unencrypted private key.
