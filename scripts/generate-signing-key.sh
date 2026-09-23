#!/usr/bin/env bash
#
# One-time setup helper: create the cosign key pair used to sign this image.
#
# Run it from the repository root:
#
#   ./scripts/generate-signing-key.sh
#
# It creates cosign.pub (commit this) and cosign.key (never commit this, it is
# already in .gitignore) and then prints the command that stores the private
# key as the SIGNING_SECRET repository secret.
#
# See README.md, "One-time setup", for the full explanation.

set -euo pipefail

if ! command -v cosign >/dev/null 2>&1; then
    cat >&2 <<'EOF'
error: cosign is not installed.

Install it first:
  https://edu.chainguard.dev/open-source/sigstore/cosign/how-to-install-cosign/
EOF
    exit 1
fi

repo_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$repo_root"

if [ -e cosign.pub ] || [ -e cosign.key ]; then
    echo "cosign.pub and/or cosign.key already exist in $repo_root."
    echo "Remove them first if you really want to generate a new key pair."
    exit 1
fi

# The key must not be password protected: GitHub Actions cannot prompt for one.
COSIGN_PASSWORD="" cosign generate-key-pair

cat <<EOF

Generated:
  $(pwd)/cosign.pub   <- commit this
  $(pwd)/cosign.key   <- keep private, never commit

Next, store the private key as the SIGNING_SECRET repository secret:

  gh secret set SIGNING_SECRET < cosign.key

or paste the contents of cosign.key into
Settings -> Secrets and variables -> Actions -> New repository secret.
EOF
