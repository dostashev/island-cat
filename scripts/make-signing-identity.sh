#!/usr/bin/env bash
# Creates "Island Cat Local Signing", a self-signed code-signing identity in
# the login keychain, so that local builds keep one signature and macOS
# keeps the permissions granted to them (Input Monitoring) across rebuilds.
# It is not trusted by anyone else; it only gives local builds an identity.
set -euo pipefail
name="Island Cat Local Signing"
if security find-identity -p codesigning | grep -q "\"$name\""; then
  echo "$name already exists"
  exit 0
fi
dir="$(mktemp -d)"
trap 'rm -rf "$dir"' EXIT
cat > "$dir/cfg.cnf" <<CONF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $name
[ext]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
CONF
openssl req -x509 -newkey rsa:2048 -nodes -keyout "$dir/key.pem" -out "$dir/cert.pem" \
  -days 3650 -config "$dir/cfg.cnf" 2>/dev/null
openssl pkcs12 -export -inkey "$dir/key.pem" -in "$dir/cert.pem" -out "$dir/id.p12" \
  -passout pass:island -name "$name"
security import "$dir/id.p12" -k ~/Library/Keychains/login.keychain-db -P island -T /usr/bin/codesign
echo "Created $name"
