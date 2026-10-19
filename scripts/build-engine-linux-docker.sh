#!/bin/bash
# libtranscribe_engine.so for Linux x86-64 (TRANSCRIBE_ENGINE_DLL: libtranscribe and ggml whole in one library), built in
# a CUDA 13.3 Ubuntu 22.04 container (glibc 2.35: runs there and on anything newer) from the committed HEAD, with
# machine code for every listed architecture and no PTX. Its RUNPATH looks beside it and in ../higgs-engine, where the
# CUDA runtime and cuBLAS are kept by the host application.
#   scripts/build-engine-linux-docker.sh <output folder> [cache folder]
set -euo pipefail

ARCHS="75-real;80-real;86-real;89-real;90-real;100-real;120-real"

if [ "${1:-}" = "--inside" ]; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -q >/dev/null
  apt-get install -y -q --no-install-recommends git ninja-build python3-pip ca-certificates >/dev/null
  pip3 install -q "cmake>=3.28" >/dev/null
  echo "[..] source $(git -c safe.directory=/src -C /src rev-parse --short HEAD)"
  rm -rf /cache/src && mkdir -p /cache/src
  git -c safe.directory=/src -C /src archive HEAD | tar -x -C /cache/src
  cd /cache/src
  echo "[..] configure ($ARCHS)"
  cmake -B /cache/build -G Ninja -DCMAKE_BUILD_TYPE=Release -DTRANSCRIBE_CUDA=ON -DTRANSCRIBE_ENGINE_DLL=ON \
    -DTRANSCRIBE_BUILD_TESTS=OFF -DTRANSCRIBE_BUILD_EXAMPLES=OFF -DTRANSCRIBE_USE_SYSTEM_BLAS=OFF \
    -DCMAKE_CUDA_ARCHITECTURES="$ARCHS" \
    '-DCMAKE_SHARED_LINKER_FLAGS=-Wl,-rpath,$ORIGIN:$ORIGIN/../higgs-engine' >/dev/null
  echo "[..] build"
  cmake --build /cache/build -j "$(( $(nproc) * 4 / 5 ))" 2>&1 | tail -3
  cp /cache/build/src/libtranscribe_engine.so /out/
  readelf -d /out/libtranscribe_engine.so | grep -E 'NEEDED|RUNPATH'
  sha256sum /out/libtranscribe_engine.so
  echo "[OK] libtranscribe_engine.so"
  exit 0
fi

out="${1:?output folder}"
cache="${2:-$HOME/transcribe-linux2204-cache}"
repo="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$out" "$cache"
cp "$repo/scripts/build-engine-linux-docker.sh" "$out/.build-engine-linux-docker.sh"
docker run --rm -v "$repo:/src:ro" -v "$(cd "$out" && pwd):/out" -v "$cache:/cache" nvidia/cuda:13.3.1-devel-ubuntu22.04 bash /out/.build-engine-linux-docker.sh --inside
