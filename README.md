# RK3588 media stack

[Tiếng Việt](README-vi.md)

Native build of three upstream trees on an Orange Pi 5 or 5 Plus (RK3588):

1. `rkrga` — userspace RGA 2D driver (`librga`)
2. `rkmpp` — Rockchip Media Process Platform (`librockchip_mpp`, `librockchip_vpu`)
3. `ffmpeg-rockchip` — FFmpeg with MPP codecs and RGA filters

This repository does **not** contain that source. The three directories are [git submodules](https://git-scm.com/book/en/v2/Git-Tools-Submodules) pointing at nyanmisaka's GitHub repos. A normal `git push` of this repo uploads only this README, the scripts, `.gitmodules`, and the three commit ids. It does not upload `rkrga/`, `rkmpp/`, or `ffmpeg-rockchip/`.

People who clone this repo get empty directories until they fetch the submodules. The commands below do that.

Install prefix is `/usr/local`. Debian/Ubuntu `/usr/bin/ffmpeg` stays the software build and has no `*_rkmpp` codecs. Always call `/usr/local/bin/ffmpeg` for hardware tests.

Verified on an Orange Pi 5 Plus, Debian 12, kernel `6.1.43-rockchip-rk3588`. The same commands built on Ubuntu 22.04 with kernel `5.10.160-rockchip-rk3588`.

## Pins

Do not `git pull` inside the three trees. Both `rkmpp` and `ffmpeg-rockchip` have been force-pushed upstream; pulling can check out a different history than the one these scripts build.

| Path | Upstream | Branch | Commit |
| --- | --- | --- | --- |
| `rkrga` | https://github.com/nyanmisaka/rk-mirrors.git | `jellyfin-rga` | `1d330cc28551943bed3380261a5a9c6fbd58ff53` |
| `rkmpp` | https://github.com/nyanmisaka/mpp.git | `jellyfin-mpp` | `848b885f95587994a53216e435f650041a894e31` |
| `ffmpeg-rockchip` | https://github.com/nyanmisaka/ffmpeg-rockchip.git | `master` | `e6fd228e1e2be00f9a4e1f003b287a72d252a55d` |

`librga` 2.1.0 (im2d API 1.10.4). `rockchip_mpp` 1.3.9. FFmpeg reports version `e6fd228e1e` when `.git` is present. A copy without `.git` reports the `RELEASE` version instead; match the codecs, not the banner.

`ffmpeg-rockchip` configure requires all of:

- `rockchip_mpp >= 1.3.9`
- `--enable-libdrm` together with `--enable-rkmpp`
- `--enable-rkmpp` together with `--enable-rkrga`
- headers visible as `rga/im2d.h` through pkg-config

## What the board needs

- aarch64 userland (Debian 12 or Ubuntu 22.04)
- Rockchip BSP kernel 5.10 or 6.1, not mainline. Mainline does not ship these device nodes.
- `/dev/rga`, `/dev/mpp_service`, `/dev/dri/renderD128`, `/dev/dma_heap/system`
- the user who runs the smoke tests in groups `video` and `render`
- no cross compiler

`rkrga/cmake-linux.sh` points at a cross gcc that is not on the board. Do not run it.

## 1. Clone

Substitute the URL of this GitHub repo.

```bash
git clone --recurse-submodules https://github.com/thanhtantran/rk3588-media-build.git
cd rk3588-media-build
```

If you already cloned without `--recurse-submodules`, the three directories are empty. Fill them at the pinned commits (this does not pull a newer upstream tip):

```bash
git submodule update --init --recursive
```

Check the pins before building:

```bash
git submodule status
# 1d330cc28551943bed3380261a5a9c6fbd58ff53 rkrga
# 848b885f95587994a53216e435f650041a894e31 rkmpp
# e6fd228e1e2be00f9a4e1f003b287a72d252a55d ffmpeg-rockchip
```

A leading space and those full ids means the checkout matches this repo. A `-` means that submodule was not fetched. A `+` means the working tree is not the pinned commit; do not build that.

## 2. Packages

```bash
sudo apt update
sudo apt install -y \
  build-essential cmake ninja-build meson pkg-config \
  git libdrm-dev

ls -l /dev/rga /dev/mpp_service /dev/dri/renderD128 /dev/dma_heap/system
groups    # need video and render before the smoke tests
```

`nasm` is not required. This board built ffmpeg-rockchip without it.

If the groups are missing, add them and log in again. Compile does not open the devices; the tests do.

```bash
sudo usermod -aG video,render "$USER"
```

## 3. Build

From the repo root, as your normal user (not root):

```bash
bash build-all.sh
```

The script builds `rkrga` into `rkrga/build-native` and `rkmpp` into `rkmpp/build-new` with `-DCMAKE_INSTALL_PREFIX=/usr/local`. It does not install. It refuses to continue unless `rkmpp/mpp/version.h` contains `848b885f`.

Then install. This asks for your sudo password, installs MPP into `/usr/local`, and configures, builds, and installs ffmpeg-rockchip. The FFmpeg build takes about 10 minutes.

```bash
sudo bash install-new-to-usr-local.sh
```

`librga` is installed by that script only when `/usr/local/lib/librga.so.2` is not already there. On a fresh board, install it yourself before the FFmpeg step if the script skips it:

```bash
sudo ninja -C rkrga/build-native install
sudo ldconfig
pkg-config --modversion librga    # 2.1.0
```

Why the MPP prefix matters: `cmake --install` writes to the prefix stored in `rkmpp/build-new/CMakeCache.txt`. A tree configured for another directory (a side-by-side trial) will not replace `/usr/local/lib/librockchip_mpp.so.0`. `install-new-to-usr-local.sh` exits if that cache prefix is not `/usr/local`. Re-run `build-all.sh` in that case. Do not copy a trial `ffmpeg` binary into `/usr/local`; it was linked with an rpath to the trial prefix.

## 4. Confirm the install

```bash
/usr/local/bin/ffmpeg -version | head -n 3
pkg-config --modversion librga rockchip_mpp
ldd /usr/local/bin/ffmpeg | grep -E 'rockchip_mpp|rga'
```

Expect version `e6fd228e1e` (or `RELEASE` if the ffmpeg tree has no `.git`), `librga` 2.1.0, `rockchip_mpp` 1.3.9, and both libraries resolved under `/usr/local/lib`.

The `configuration:` line must contain `--enable-rkmpp` and `--enable-rkrga`. `/usr/bin/ffmpeg` will not.

Codecs and filters:

```bash
FF=/usr/local/bin/ffmpeg
$FF -hide_banner -decoders | grep rkmpp
$FF -hide_banner -encoders | grep rkmpp
$FF -hide_banner -filters  | grep rkrga
```

Decoders: `av1_rkmpp`, `h263_rkmpp`, `h264_rkmpp`, `hevc_rkmpp`, `mjpeg_rkmpp`, `mpeg1_rkmpp`, `mpeg2_rkmpp`, `mpeg4_rkmpp`, `vp8_rkmpp`, `vp9_rkmpp`.

Encoders: `h264_rkmpp`, `hevc_rkmpp`, `mjpeg_rkmpp`.

Filters: `scale_rkrga`, `vpp_rkrga`, `overlay_rkrga`.

`scale_rkrga` and `vpp_rkrga` only accept `drm_prime` frames. Keep `-hwaccel rkmpp -hwaccel_output_format drm_prime`. Do not put a software `scale` or `format` in front of them.

## 5. Smoke test

This FFmpeg build has no `libx264`. Make the input with the software `mpeg4` encoder, then transcode it on the VPU and RGA.

```bash
FF=/usr/local/bin/ffmpeg
mkdir -p /tmp/mpp-smoke
$FF -y -hide_banner -f lavfi -i testsrc=size=1280x720:rate=30 \
  -frames:v 30 -c:v mpeg4 -q:v 4 -pix_fmt yuv420p /tmp/mpp-smoke/src.mp4

$FF -y -hide_banner \
  -hwaccel rkmpp -hwaccel_output_format drm_prime \
  -i /tmp/mpp-smoke/src.mp4 \
  -vf 'scale_rkrga=w=640:h=360:format=nv12' \
  -c:v h264_rkmpp -b:v 2M /tmp/mpp-smoke/h264.mp4

$FF -y -hide_banner \
  -hwaccel rkmpp -hwaccel_output_format drm_prime \
  -i /tmp/mpp-smoke/h264.mp4 \
  -c:v hevc_rkmpp -b:v 1500k /tmp/mpp-smoke/hevc.mp4

ffprobe -hide_banner -v error -select_streams v:0 \
  -show_entries stream=codec_name,width,height -of csv=p=0 \
  /tmp/mpp-smoke/h264.mp4
ffprobe -hide_banner -v error -select_streams v:0 \
  -show_entries stream=codec_name,width,height -of csv=p=0 \
  /tmp/mpp-smoke/hevc.mp4
```

Expect `h264,640,360` and `hevc,640,360`. The log names `mpeg4_rkmpp` or `h264_rkmpp` on decode, `scale_rkrga` in the graph, and `h264_rkmpp` / `hevc_rkmpp` on encode. RGA prints `rga_api version 1.10.4`.

`mpp_info_test` (installed with MPP) takes no file. It should name the RK3588 VPU and exit 0.

### Install checks

Run this after `install-new-to-usr-local.sh`. Every line should print, and the last line should be `INSTALL_OK`.

```bash
set -e
FF=/usr/local/bin/ffmpeg
test -x "$FF"
"$FF" -version | head -n 1 | grep -E 'e6fd228e1e|ffmpeg version'
"$FF" -hide_banner -buildconf | grep -q -- '--enable-rkmpp'
"$FF" -hide_banner -buildconf | grep -q -- '--enable-rkrga'
pkg-config --modversion librga | grep -qx '2.1.0'
pkg-config --modversion rockchip_mpp | grep -qx '1.3.9'
ldd "$FF" | grep -q '/usr/local/lib/librockchip_mpp.so'
ldd "$FF" | grep -q '/usr/local/lib/librga.so'
# Run as the normal user. sudo's PATH often has no strings(1).
strings /usr/local/lib/librockchip_mpp.so.0 | grep -q '848b885f'
"$FF" -hide_banner -decoders | grep -q 'h264_rkmpp'
"$FF" -hide_banner -encoders | grep -q 'h264_rkmpp'
"$FF" -hide_banner -encoders | grep -q 'hevc_rkmpp'
"$FF" -hide_banner -filters  | grep -q 'scale_rkrga'
test -r /dev/rga && test -r /dev/mpp_service && test -r /dev/dri/renderD128
mpp_info_test >/dev/null
echo INSTALL_OK
```

If `strings` is missing, confirm the MPP commit from the source tree instead:

```bash
grep -m1 MPP_VERSION rkmpp/mpp/version.h
# "848b885f author: nyanmisaka    2026-11-03 ..."
```

A passing install check is not a hardware test. Section 5 is. `INSTALL_OK` plus `h264,640,360` and `hevc,640,360` from section 5 means the stack is usable.

## 6. Failures

| Symptom | Cause |
| --- | --- |
| `rkrga/` is empty after clone | Clone without `--recurse-submodules`. Run `git submodule update --init --recursive`. |
| `Missing nasm` from an old `build-all.sh` | Update the script. `nasm` is not required. |
| `mpp/version.h is not 848b885f` | The submodule is not the pinned commit. Run `git submodule update --init`. |
| `build-new prefix is not /usr/local` | `rkmpp/build-new` was configured for another prefix. Re-run `build-all.sh`. |
| `cmake --install` succeeds but `/usr/local/lib/librockchip_mpp.so.0` is old | Same prefix bug. The install went to the prefix in `CMakeCache.txt`, not to `/usr/local`. |
| `ERROR: rkmpp requires --enable-libdrm` | Install `libdrm-dev` and keep the flag in the script. |
| `rockchip_mpp >= 1.3.9` not found | MPP is not installed, or `PKG_CONFIG_PATH` is missing `/usr/local/lib/pkgconfig`. |
| `ffmpeg` has no `*_rkmpp` | You ran `/usr/bin/ffmpeg`. Use `/usr/local/bin/ffmpeg`. |
| Cannot open `/dev/mpp_service` or `/dev/rga` | User not in `video`/`render`, or this is not the vendor 5.10/6.1 kernel. The compile can still succeed. |
| `scale_rkrga` rejects the pixel format | A software filter ran first. Keep `-hwaccel_output_format drm_prime`. |
| `strings` under `sudo` says the library is the wrong build | `sudo` `secure_path` often has no `strings`. The install script checks `mpp/version.h` instead. |

## License

Each submodule keeps its own license (Rockchip MPP and librga are Apache-2.0; FFmpeg is LGPL/GPL, and this build enables GPL and version 3). This README and the two shell scripts are the documentation for the pinned build.
