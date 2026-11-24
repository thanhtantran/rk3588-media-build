# Bộ media RK3588

[English](README.md)

Build trên máy Orange Pi 5 hoặc 5 Plus (RK3588) từ ba cây mã nguồn:

1. `rkrga` — driver RGA 2D (`librga`)
2. `rkmpp` — Rockchip Media Process Platform (`librockchip_mpp`, `librockchip_vpu`)
3. `ffmpeg-rockchip` — FFmpeg có codec MPP và filter RGA

Repo này **không chứa** ba mã nguồn đó. Ba thư mục là [git submodule](https://git-scm.com/book/en/v2/Git-Tools-Submodules) trỏ về repo GitHub của nyanmisaka. `git push` repo cha chỉ đẩy README, script, `.gitmodules` và ba commit id. Không đẩy `rkrga/`, `rkmpp/`, `ffmpeg-rockchip/`.

Clone thường sẽ ra thư mục rỗng. Phải lấy submodule thì mới có mã để build. Lệnh ở dưới làm việc đó.

Prefix cài đặt là `/usr/local`. `/usr/bin/ffmpeg` của Debian/Ubuntu là bản phần mềm, không có codec `*_rkmpp`. Mọi lệnh thử phần cứng dùng `/usr/local/bin/ffmpeg`.

Đã chạy trên Orange Pi 5 Plus, Debian 12, kernel `6.1.43-rockchip-rk3588`. Cùng lệnh đã build được trên Ubuntu 22.04, kernel `5.10.160-rockchip-rk3588`.

## Commit được ghim

Đừng `git pull` trong ba thư mục. `rkmpp` và `ffmpeg-rockchip` đã bị force-push ở upstream. Pull có thể lấy lịch sử khác bản mà script này build.

| Đường dẫn | Upstream | Nhánh | Commit |
| --- | --- | --- | --- |
| `rkrga` | https://github.com/nyanmisaka/rk-mirrors.git | `jellyfin-rga` | `1d330cc28551943bed3380261a5a9c6fbd58ff53` |
| `rkmpp` | https://github.com/nyanmisaka/mpp.git | `jellyfin-mpp` | `848b885f95587994a53216e435f650041a894e31` |
| `ffmpeg-rockchip` | https://github.com/nyanmisaka/ffmpeg-rockchip.git | `master` | `e6fd228e1e2be00f9a4e1f003b287a72d252a55d` |

`librga` 2.1.0 (im2d API 1.10.4). `rockchip_mpp` 1.3.9. FFmpeg in `e6fd228e1e` khi còn `.git`. Bản copy không có `.git` in version `RELEASE`. So codec, đừng so dòng version.

`./configure` của `ffmpeg-rockchip` cần đủ:

- `rockchip_mpp >= 1.3.9`
- `--enable-libdrm` đi cùng `--enable-rkmpp`
- `--enable-rkmpp` đi cùng `--enable-rkrga`
- header `rga/im2d.h` thấy được qua pkg-config

## Máy cần có

- userland aarch64 (Debian 12 hoặc Ubuntu 22.04)
- kernel BSP Rockchip 5.10 hoặc 6.1, không phải mainline. Mainline không có các device node này.
- `/dev/rga`, `/dev/mpp_service`, `/dev/dri/renderD128`, `/dev/dma_heap/system`
- user chạy smoke test thuộc nhóm `video` và `render`
- không dùng cross compiler

`rkrga/cmake-linux.sh` trỏ tới gcc cross không có trên board. Đừng chạy script đó.

## 1. Clone

```bash
git clone --recurse-submodules https://github.com/thanhtantran/rk3588-media-build.git
cd rk3588-media-build
```

Nếu đã clone mà quên `--recurse-submodules`, ba thư mục sẽ rỗng. Lấy đúng commit đã ghim (không kéo tip mới hơn):

```bash
git submodule update --init --recursive
```

Kiểm tra trước khi build:

```bash
git submodule status
# 1d330cc28551943bed3380261a5a9c6fbd58ff53 rkrga
# 848b885f95587994a53216e435f650041a894e31 rkmpp
# e6fd228e1e2be00f9a4e1f003b287a72d252a55d ffmpeg-rockchip
```

Có khoảng trắng đầu dòng và đúng ba id là khớp repo này. Dấu `-` nghĩa là chưa tải submodule. Dấu `+` nghĩa là thư mục không đứng ở commit đã ghim; đừng build bản đó.

## 2. Gói

```bash
sudo apt update
sudo apt install -y \
  build-essential cmake ninja-build meson pkg-config \
  git libdrm-dev

ls -l /dev/rga /dev/mpp_service /dev/dri/renderD128 /dev/dma_heap/system
groups    # cần video và render trước khi smoke test
```

Không cần `nasm`. Board này build ffmpeg-rockchip không có nó.

Thiếu nhóm thì thêm rồi đăng nhập lại. Lúc biên dịch không mở thiết bị; lúc test thì có.

```bash
sudo usermod -aG video,render "$USER"
```

## 3. Build

Ở thư mục gốc repo, bằng user thường, không phải root:

```bash
bash build-all.sh
```

Script build `rkrga` vào `rkrga/build-native` và `rkmpp` vào `rkmpp/build-new` với `-DCMAKE_INSTALL_PREFIX=/usr/local`. Chưa cài. Dừng nếu `rkmpp/mpp/version.h` không chứa `848b885f`.

Rồi cài. Lệnh này hỏi mật khẩu sudo, cài MPP vào `/usr/local`, sau đó configure, build và cài ffmpeg-rockchip. Bước FFmpeg khoảng 10 phút.

```bash
sudo bash install-new-to-usr-local.sh
```

Script chỉ cài `librga` khi chưa có `/usr/local/lib/librga.so.2`. Máy mới, nếu script bỏ qua, cài tay trước bước FFmpeg:

```bash
sudo ninja -C rkrga/build-native install
sudo ldconfig
pkg-config --modversion librga    # 2.1.0
```

Prefix của MPP quan trọng: `cmake --install` ghi vào prefix trong `rkmpp/build-new/CMakeCache.txt`. Cây từng được cấu hình cho thư mục khác sẽ không đè `/usr/local/lib/librockchip_mpp.so.0`. `install-new-to-usr-local.sh` thoát nếu prefix trong cache không phải `/usr/local`. Khi đó chạy lại `build-all.sh`. Đừng copy binary `ffmpeg` của bản thử vào `/usr/local`; binary đó có rpath trỏ prefix thử.

## 4. Xác nhận đã cài

```bash
/usr/local/bin/ffmpeg -version | head -n 3
pkg-config --modversion librga rockchip_mpp
ldd /usr/local/bin/ffmpeg | grep -E 'rockchip_mpp|rga'
```

Kỳ vọng version `e6fd228e1e` (hoặc `RELEASE` nếu cây ffmpeg không còn `.git`), `librga` 2.1.0, `rockchip_mpp` 1.3.9, và cả hai thư viện nằm dưới `/usr/local/lib`.

Dòng `configuration:` phải có `--enable-rkmpp` và `--enable-rkrga`. `/usr/bin/ffmpeg` thì không có.

Codec và filter:

```bash
FF=/usr/local/bin/ffmpeg
$FF -hide_banner -decoders | grep rkmpp
$FF -hide_banner -encoders | grep rkmpp
$FF -hide_banner -filters  | grep rkrga
```

Decoder: `av1_rkmpp`, `h263_rkmpp`, `h264_rkmpp`, `hevc_rkmpp`, `mjpeg_rkmpp`, `mpeg1_rkmpp`, `mpeg2_rkmpp`, `mpeg4_rkmpp`, `vp8_rkmpp`, `vp9_rkmpp`.

Encoder: `h264_rkmpp`, `hevc_rkmpp`, `mjpeg_rkmpp`.

Filter: `scale_rkrga`, `vpp_rkrga`, `overlay_rkrga`.

`scale_rkrga` và `vpp_rkrga` chỉ nhận frame `drm_prime`. Giữ `-hwaccel rkmpp -hwaccel_output_format drm_prime`. Đừng đặt `scale` hoặc `format` phần mềm phía trước.

## 5. Smoke test

Bản FFmpeg này không có `libx264`. Tạo file vào bằng encoder `mpeg4` phần mềm, rồi transcode trên VPU và RGA.

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

Kỳ vọng `h264,640,360` và `hevc,640,360`. Log ghi `mpeg4_rkmpp` hoặc `h264_rkmpp` lúc decode, `scale_rkrga` trong graph, `h264_rkmpp` / `hevc_rkmpp` lúc encode. RGA in `rga_api version 1.10.4`.

`mpp_info_test` (cài cùng MPP) không nhận file. Phải in tên VPU RK3588 và thoát 0.

### Lệnh kiểm chứng sau khi cài

Chạy sau `install-new-to-usr-local.sh`, bằng user thường. Dòng cuối phải là `INSTALL_OK`.

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
# Không chạy bằng sudo. PATH của sudo thường không có strings(1).
strings /usr/local/lib/librockchip_mpp.so.0 | grep -q '848b885f'
"$FF" -hide_banner -decoders | grep -q 'h264_rkmpp'
"$FF" -hide_banner -encoders | grep -q 'h264_rkmpp'
"$FF" -hide_banner -encoders | grep -q 'hevc_rkmpp'
"$FF" -hide_banner -filters  | grep -q 'scale_rkrga'
test -r /dev/rga && test -r /dev/mpp_service && test -r /dev/dri/renderD128
mpp_info_test >/dev/null
echo INSTALL_OK
```

Nếu không có `strings`, đối chiếu commit MPP từ source:

```bash
grep -m1 MPP_VERSION rkmpp/mpp/version.h
# "848b885f author: nyanmisaka    2026-11-03 ..."
```

`INSTALL_OK` mới chứng minh file đã cài đúng. Phần 5 mới chứng minh phần cứng chạy. Cần cả `INSTALL_OK` lẫn `h264,640,360` và `hevc,640,360`.

## 6. Lỗi thường gặp

| Triệu chứng | Nguyên nhân |
| --- | --- |
| `rkrga/` rỗng sau clone | Clone thiếu `--recurse-submodules`. Chạy `git submodule update --init --recursive`. |
| `Missing nasm` từ `build-all.sh` cũ | Lấy script mới. Không cần `nasm`. |
| `mpp/version.h is not 848b885f` | Submodule không đúng commit. Chạy `git submodule update --init`. |
| `build-new prefix is not /usr/local` | `rkmpp/build-new` được cấu hình cho prefix khác. Chạy lại `build-all.sh`. |
| `cmake --install` xong mà `/usr/local/lib/librockchip_mpp.so.0` vẫn cũ | Cùng lỗi prefix. File được ghi vào prefix trong `CMakeCache.txt`, không phải `/usr/local`. |
| `ERROR: rkmpp requires --enable-libdrm` | Cài `libdrm-dev` và giữ cờ trong script. |
| Không thấy `rockchip_mpp >= 1.3.9` | MPP chưa cài, hoặc `PKG_CONFIG_PATH` thiếu `/usr/local/lib/pkgconfig`. |
| `ffmpeg` không có `*_rkmpp` | Đang chạy `/usr/bin/ffmpeg`. Dùng `/usr/local/bin/ffmpeg`. |
| Không mở được `/dev/mpp_service` hoặc `/dev/rga` | User không thuộc `video`/`render`, hoặc không phải kernel vendor 5.10/6.1. Biên dịch vẫn có thể thành công. |
| `scale_rkrga` từ chối pixel format | Một filter phần mềm chạy trước. Giữ `-hwaccel_output_format drm_prime`. |
| `strings` dưới `sudo` báo thư viện sai bản | `secure_path` của sudo thường không có `strings`. Script cài kiểm tra `mpp/version.h`. |

## Giấy phép

Mỗi submodule giữ giấy phép của nó. Xem [LICENSE](LICENSE). README và hai shell script là tài liệu cho bản build đã ghim.
