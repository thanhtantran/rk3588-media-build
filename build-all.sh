#!/bin/bash
# Build librga, rockchip_mpp and ffmpeg-rockchip on the board.
# Does not install. Run install-new-to-usr-local.sh with sudo afterwards.
#
# Pins (do not git pull; upstream force-pushes):
#   rkrga            1d330cc28551943bed3380261a5a9c6fbd58ff53  jellyfin-rga
#   rkmpp            848b885f95587994a53216e435f650041a894e31  jellyfin-mpp
#   ffmpeg-rockchip  e6fd228e1e2be00f9a4e1f003b287a72d252a55d  master
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
JOBS="$(nproc)"
export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}

if [[ "$(id -u)" -eq 0 ]]; then
  echo "Run as the normal user, not root. Install is a separate sudo step." >&2
  exit 1
fi

need() {
  command -v "$1" >/dev/null || { echo "Missing $1" >&2; exit 1; }
}
need meson
need ninja
need cmake
need pkg-config
# libx264 and libass are required by the ffmpeg configure in
# install-new-to-usr-local.sh. Install libx264-dev and libass-dev first.
pkg-config --exists x264 || { echo "Missing libx264-dev (pkg-config x264)" >&2; exit 1; }
pkg-config --exists libass || { echo "Missing libass-dev (pkg-config libass)" >&2; exit 1; }

cd "$SRC/rkrga"
echo "== rkrga $(git rev-parse --short=8 HEAD) =="
rm -rf build-native
meson setup build-native --prefix=/usr/local --buildtype=release \
  -Dlibdrm=true -Dlibrga_demo=false
ninja -C build-native

cd "$SRC/rkmpp"
echo "== rkmpp $(git rev-parse --short=8 HEAD) =="
# build-new was configured for the trial prefix. Reconfigure for /usr/local
# so cmake --install writes the new librockchip_mpp.so.0 over the old one.
rm -rf build-new
cmake -S . -B build-new \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/usr/local \
  -DBUILD_TEST=ON
cmake --build build-new -j"$JOBS"

grep -q '848b885f' mpp/version.h || {
  echo "mpp/version.h is not 848b885f. Refusing to continue." >&2
  exit 1
}

cd "$SRC/ffmpeg-rockchip"
echo "== ffmpeg-rockchip $(git rev-parse --short=8 HEAD) =="
if [[ -f ffbuild/config.mak ]] && grep -q '^SRC_PATH=.' ffbuild/config.mak; then
  make distclean >/dev/null 2>&1 || true
else
  rm -f ffbuild/config.mak config.h config_components.h .config
fi
# Configure only. install-new-to-usr-local.sh configures again after MPP
# is in /usr/local, because this configure would still see the old library.
echo "BUILD_OK rkrga build-native, rkmpp build-new"
echo "Next: sudo bash $SRC/install-new-to-usr-local.sh"
