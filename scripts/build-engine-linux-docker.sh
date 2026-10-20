#!/bin/bash
# libtranscribe_engine.so for Linux x86-64 (TRANSCRIBE_ENGINE_DLL: libtranscribe and ggml whole in one library), built in
# an Ubuntu 22.04 container (glibc 2.35: runs there and on anything newer) from the committed HEAD.
#   cuda (default): CUDA 13.3, machine code for every listed architecture and no PTX; its RUNPATH looks beside it and in
#                   ../higgs-engine, where the CUDA runtime and cuBLAS are kept by the host application.
#   vulkan:         Vulkan and the CPU, for AMD and Intel cards; built against the LunarG Vulkan SDK (Ubuntu 22.04 has no
#                   glslc), the Vulkan loader of the system's drivers at run time.
#   cpu:            the CPU alone.
#   scripts/build-engine-linux-docker.sh <output folder> [cache folder] [cuda|vulkan|cpu]
set -euo pipefail

ARCHS="75-real;80-real;86-real;89-real;90-real;100-real;120-real"
VULKAN_SDK_VERSION="1.4.357.0"

if [ "${1:-}" = "--inside" ]; then
  backend="$2"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -q >/dev/null
  apt-get install -y -q --no-install-recommends git ninja-build python3-pip ca-certificates build-essential curl xz-utils >/dev/null
  pip3 install -q "cmake>=3.28" >/dev/null
  flags=()
  case "$backend" in
    cuda) flags=(-DTRANSCRIBE_CUDA=ON -DGGML_CUDA_NCCL=OFF -DCMAKE_CUDA_ARCHITECTURES="$ARCHS" '-DCMAKE_BUILD_RPATH=$ORIGIN;$ORIGIN/../higgs-engine') ;;
    vulkan)
      sdk=/cache/vulkansdk-$VULKAN_SDK_VERSION
      if [ ! -x "$sdk/x86_64/bin/glslc" ]; then
        echo "[..] Vulkan SDK $VULKAN_SDK_VERSION"
        mkdir -p "$sdk"
        curl -fsSL "https://sdk.lunarg.com/sdk/download/$VULKAN_SDK_VERSION/linux/vulkansdk-linux-x86_64-$VULKAN_SDK_VERSION.tar.xz" | tar -xJ -C "$sdk" --strip-components=1
      fi
      export VULKAN_SDK="$sdk/x86_64" PATH="$sdk/x86_64/bin:$PATH"
      # the SDK keeps its loader apart since 1.4.3xx: linked from the system folder it adds nothing to RUNPATH, and at
      # run time libvulkan.so.1 is the loader of the machine's drivers
      cp -P "$sdk"/x86_64/lib/VulkanLoader/lib/libvulkan.so* /usr/lib/x86_64-linux-gnu/
      flags=(-DTRANSCRIBE_VULKAN=ON -DVulkan_LIBRARY=/usr/lib/x86_64-linux-gnu/libvulkan.so '-DCMAKE_BUILD_RPATH=$ORIGIN') ;;
    cpu) flags=('-DCMAKE_BUILD_RPATH=$ORIGIN') ;;
    *) echo "[ERROR] backend $backend: cuda, vulkan or cpu"; exit 1 ;;
  esac
  echo "[..] source $(git -c safe.directory=/src -C /src rev-parse --short HEAD), $backend"
  rm -rf /cache/src && mkdir -p /cache/src
  git -c safe.directory=/src -C /src archive HEAD | tar -x -C /cache/src
  cd /cache/src
  # settings come from this script alone, not from a cache an earlier run left
  rm -rf "/cache/build-$backend/CMakeCache.txt"
  cmake -B "/cache/build-$backend" -G Ninja -DCMAKE_BUILD_TYPE=Release -DTRANSCRIBE_ENGINE_DLL=ON \
    -DTRANSCRIBE_BUILD_TESTS=OFF -DTRANSCRIBE_BUILD_EXAMPLES=OFF -DTRANSCRIBE_USE_SYSTEM_BLAS=OFF "${flags[@]}" >/dev/null
  echo "[..] build"
  cmake --build "/cache/build-$backend" -j "$(( $(nproc) * 4 / 5 ))" 2>&1 | tail -3
  cp "/cache/build-$backend/src/libtranscribe_engine.so" /out/
  readelf -d /out/libtranscribe_engine.so | grep -E 'NEEDED|RUNPATH'
  sha256sum /out/libtranscribe_engine.so
  echo "[OK] libtranscribe_engine.so ($backend)"
  exit 0
fi

out="${1:?output folder}"
cache="${2:-$HOME/transcribe-linux2204-cache}"
backend="${3:-cuda}"
repo="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$out" "$cache"
cp "$repo/scripts/build-engine-linux-docker.sh" "$out/.build-engine-linux-docker.sh"
image=ubuntu:22.04
[ "$backend" = "cuda" ] && image=nvidia/cuda:13.3.1-devel-ubuntu22.04
docker run --rm -v "$repo:/src:ro" -v "$(cd "$out" && pwd):/out" -v "$cache:/cache" "$image" bash /out/.build-engine-linux-docker.sh --inside "$backend"
