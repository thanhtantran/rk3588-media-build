#!/bin/bash
# Install the build-all.sh products into /usr/local.
#
# rkmpp/build-new must have been configured with
#   -DCMAKE_INSTALL_PREFIX=/usr/local
# A tree configured for /home/orangepi/opt/rk3588-media-new installs there
# and leaves the August 2025 librockchip_mpp.so.0 in /usr/local.
#
# Do not check the .so with `strings` under sudo. sudo secure_path often
# lacks /usr/bin, so strings is missing and the check exits 1 even when
# the library is the right build. The commit id is in mpp/version.h.
set -euo pipefail

PREFIX=/usr/local
SRC="$(cd "$(dirname "$0")" && pwd)"
MPP_BUILD="$SRC/rkmpp/build-new"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run as root: sudo bash $0" >&2
  exit 1
fi

if [[ ! -f "$MPP_BUILD/mpp/librockchip_mpp.so.0" ]]; then
  echo "Missing $MPP_BUILD. Run build-all.sh first." >&2
  exit 1
fi

if ! grep -q '848b885f' "$SRC/rkmpp/mpp/version.h"; then
  echo "mpp/version.h is not 848b885f. Refusing to install." >&2
  exit 1
fi

cache="$(grep -E '^CMAKE_INSTALL_PREFIX' "$MPP_BUILD/CMakeCache.txt" | head -1 || true)"
case "$cache" in
  *"/usr/local") ;;
  *)
    echo "build-new prefix is not /usr/local ($cache)." >&2
    echo "Re-run build-all.sh. cmake --install would miss /usr/local." >&2
    exit 1
    ;;
esac

echo "== install rockchip_mpp into /usr/local =="
cmake --install "$MPP_BUILD"
ldconfig

echo "== configure and install ffmpeg-rockchip =="
cd "$SRC/ffmpeg-rockchip"
make distclean
export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig
./configure \
  --prefix="$PREFIX" \
  --enable-gpl --enable-version3 \
  --enable-libdrm --enable-rkmpp --enable-rkrga
make -j"$(nproc)"
make install
ldconfig

if [[ -d "$SRC/rkrga/build-native" ]] && [[ ! -e /usr/local/lib/librga.so.2 ]]; then
  echo "== install librga =="
  ninja -C "$SRC/rkrga/build-native" install
  ldconfig
fi

echo "== installed =="
/usr/local/bin/ffmpeg -version | head -3
pkg-config --modversion rockchip_mpp
ldd /usr/local/bin/ffmpeg | grep -E 'rockchip_mpp|rga'
echo DONE
