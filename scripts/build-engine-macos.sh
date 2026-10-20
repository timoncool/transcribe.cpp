#!/bin/bash
# libtranscribe_engine.dylib for macOS (TRANSCRIBE_ENGINE_DLL: libtranscribe and ggml whole in one library), from the
# committed HEAD, for macOS 13 and newer:
#   metal (default): Apple silicon, Metal with its shaders embedded in the library, and the CPU.
#   cpu:             Intel Macs (x86_64), the CPU alone.
#   scripts/build-engine-macos.sh <output folder> [metal|cpu]
set -euo pipefail

out="${1:?output folder}"
backend="${2:-metal}"
repo="$(cd "$(dirname "$0")/.." && pwd)"
case "$backend" in
  metal) flags=(-DCMAKE_OSX_ARCHITECTURES=arm64 -DGGML_METAL=ON -DGGML_METAL_EMBED_LIBRARY=ON) ;;
  cpu) flags=(-DCMAKE_OSX_ARCHITECTURES=x86_64 -DGGML_METAL=OFF -DGGML_NATIVE=OFF) ;;
  *) echo "[ERROR] backend $backend: metal or cpu"; exit 1 ;;
esac
build="$(mktemp -d)"
echo "[..] source $(git -C "$repo" rev-parse --short HEAD), $backend"
git -C "$repo" archive HEAD | tar -x -C "$build"
cmake -S "$build" -B "$build/out" -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0 \
  -DTRANSCRIBE_ENGINE_DLL=ON -DTRANSCRIBE_BUILD_SHARED=OFF -DTRANSCRIBE_BUILD_TESTS=OFF -DTRANSCRIBE_BUILD_EXAMPLES=OFF \
  -DTRANSCRIBE_USE_SYSTEM_BLAS=OFF -DBUILD_SHARED_LIBS=OFF "${flags[@]}" >/dev/null
echo "[..] build"
cmake --build "$build/out" --target transcribe_engine -j "$(sysctl -n hw.ncpu)" 2>&1 | tail -3
mkdir -p "$out"
cp "$build/out/src/libtranscribe_engine.dylib" "$out/"
otool -L "$out/libtranscribe_engine.dylib"
lipo -archs "$out/libtranscribe_engine.dylib"
nm -gU "$out/libtranscribe_engine.dylib" | grep -c ' _transcribe_' | sed 's/^/exported transcribe_ symbols: /'
shasum -a 256 "$out/libtranscribe_engine.dylib"
echo "[OK] libtranscribe_engine.dylib ($backend)"
