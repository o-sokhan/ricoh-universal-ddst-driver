#!/usr/bin/env bash
# ==============================================================================
# Build the macOS installer package.
#
#   packaging/build_pkg.sh [version] [output-dir]
#
# Optional signing (all skipped when unset, giving an unsigned package):
#   APP_SIGN_IDENTITY   "Developer ID Application: ..."  signs the filters
#   PKG_SIGN_IDENTITY   "Developer ID Installer: ..."    signs the .pkg
#   NOTARY_PROFILE      notarytool keychain profile      notarizes + staples
#
# The package only places files under /Library/Printers. It has no install
# scripts: it does not restart CUPS, add printers, or change sharing settings.
# ==============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${1:-$(git -C "$ROOT" describe --tags --always 2>/dev/null | sed 's/^v//' || echo 0.0.0)}"
OUT_DIR="${2:-$ROOT/dist}"
IDENTIFIER="io.github.o-sokhan.ricoh-ddst-driver"

[ "$(uname -s)" = "Darwin" ] || { echo "Error: build_pkg.sh must run on macOS." >&2; exit 1; }

WORK="$(mktemp -d -t ricoh_pkg)"
trap 'rm -rf "$WORK"' EXIT
PAYLOAD="$WORK/payload"
FILTER_DIR="/Library/Printers/Ricoh/Filter"

cd "$ROOT"
make clean >/dev/null
make build
make install DESTDIR="$PAYLOAD" OWNER= >/dev/null

for f in "$PAYLOAD$FILTER_DIR"/*; do
    lipo -info "$f"
    if [ -n "${APP_SIGN_IDENTITY:-}" ]; then
        codesign --force --options runtime --timestamp \
            --identifier "$IDENTIFIER.$(basename "$f")" \
            --sign "$APP_SIGN_IDENTITY" "$f"
        codesign --verify --strict --verbose=2 "$f"
    fi
done

mkdir -p "$OUT_DIR"
PKG="$OUT_DIR/ricoh-ddst-driver-$VERSION.pkg"
SIGN_ARGS=()
[ -n "${PKG_SIGN_IDENTITY:-}" ] && SIGN_ARGS=(--sign "$PKG_SIGN_IDENTITY" --timestamp)

COPYFILE_DISABLE=1 pkgbuild \
    --root "$PAYLOAD" \
    --identifier "$IDENTIFIER" \
    --version "$VERSION" \
    --ownership recommended \
    --install-location / \
    ${SIGN_ARGS[@]+"${SIGN_ARGS[@]}"} \
    "$PKG"

if [ -n "${NOTARY_PROFILE:-}" ]; then
    [ -n "${PKG_SIGN_IDENTITY:-}" ] || { echo "Error: notarization needs PKG_SIGN_IDENTITY." >&2; exit 1; }
    xcrun notarytool submit "$PKG" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$PKG"
fi

pkgutil --payload-files "$PKG"
[ -n "${PKG_SIGN_IDENTITY:-}" ] && pkgutil --check-signature "$PKG"
shasum -a 256 "$PKG"
