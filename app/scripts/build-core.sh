#!/usr/bin/env bash
# Compila o núcleo em Rust e gera a ponte para o app macOS.
#
# Saída (não versionada, refeita a cada build):
#   macos/YggiCore/YggiCoreFFI.xcframework        biblioteca estática + cabeçalho C
#   macos/YggiCore/Sources/YggiCore/yggi_core.swift  ponte Swift gerada pelo UniFFI
#
# Uso: scripts/build-core.sh [--universal]
#   --universal  gera para Apple Silicon e Intel (precisa de: rustup target add x86_64-apple-darwin)
set -euo pipefail

APP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CORE_DIR="$APP_DIR/core"
PKG_DIR="$APP_DIR/macos/YggiCore"
OUT_SWIFT="$PKG_DIR/Sources/YggiCore"
XCFRAMEWORK="$PKG_DIR/YggiCoreFFI.xcframework"
LIB="libyggi_core.a"

# O xcodebuild precisa do Xcode completo, mesmo se o xcode-select apontar para as Command Line Tools.
if [[ -z "${DEVELOPER_DIR:-}" && "$(xcode-select -p)" == *CommandLineTools* ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
export MACOSX_DEPLOYMENT_TARGET=14.0

targets=("$(rustc -vV | sed -n 's/^host: //p')")
if [[ "${1:-}" == "--universal" ]]; then
  targets=(aarch64-apple-darwin x86_64-apple-darwin)
fi

cd "$CORE_DIR"
libs=()
for t in "${targets[@]}"; do
  echo "▸ núcleo Rust ($t)"
  cargo build --release --lib --target "$t"
  libs+=("target/$t/release/$LIB")
done

# Pontes: gera a partir da biblioteca dinâmica (tem os metadados do UniFFI).
echo "▸ ponte Swift (UniFFI)"
GEN="$(mktemp -d)"
trap 'rm -rf "$GEN"' EXIT
cargo run --quiet --release --features bindgen --bin uniffi-bindgen -- \
  generate "target/${targets[0]}/release/libyggi_core.dylib" --language swift --out-dir "$GEN"

mkdir -p "$GEN/lib" "$GEN/include" "$OUT_SWIFT"
lipo -create "${libs[@]}" -output "$GEN/lib/$LIB"
cp "$GEN/yggi_coreFFI.h" "$GEN/include/"
cp "$GEN/yggi_coreFFI.modulemap" "$GEN/include/module.modulemap"
cp "$GEN/yggi_core.swift" "$OUT_SWIFT/"

echo "▸ xcframework"
rm -rf "$XCFRAMEWORK"
xcodebuild -create-xcframework -library "$GEN/lib/$LIB" -headers "$GEN/include" -output "$XCFRAMEWORK" >/dev/null

echo "✓ pronto: $(basename "$XCFRAMEWORK") e yggi_core.swift em macos/YggiCore"
