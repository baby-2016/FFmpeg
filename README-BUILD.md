# 精简版 FFmpeg 构建说明

本仓库提供三个平台的 FFmpeg `n7.1` 精简构建脚本。目标是保留常用音视频压缩、转码、封装转换能力，同时砍掉播放、探测、网络、设备、文档、调试符号等非必要组件。

## 构建目标

| 平台 | 脚本 | 输出目录 |
|---|---|---|
| Windows x64 | `build-win-x64.sh` | `output-win64` |
| Linux x64 | `build-linux-x64.sh` | `output-linux-x64` |
| macOS arm64 | `build-mac-arm.sh` | `output-mac-arm64` |

## 构建命令

先构建依赖，再编译 FFmpeg。

### Windows x64

```bash
./build-win-x64.sh build-dep
./build-win-x64.sh compile
```

### Linux x64

```bash
./build-linux-x64.sh build-dep
./build-linux-x64.sh compile
```

### macOS arm64

```bash
./build-mac-arm.sh build-dep
./build-mac-arm.sh compile
```

## 外部依赖

| 平台 | 依赖 |
|---|---|
| Windows x64 | `nv-codec-headers`、`libvpx`、`x264`、`x265`、`fdk-aac`、`opus`、`lame` |
| Linux x64 | `nv-codec-headers`、`libvpx`、`x264`、`x265`、`fdk-aac`、`opus`、`lame` |
| macOS arm64 | `libvpx`、`x264`、`x265`、`fdk-aac`、`opus`、`lame` |

说明：

- `libx264` 用于 H.264 软件编码。
- `libx265` 用于 HEVC/H.265 软件编码，脚本会手动生成 `x265.pc`，确保 FFmpeg configure 能通过 `pkg-config` 检测到。
- `libvpx_vp9` 用于 VP9 编码，脚本会在构建 `libvpx` 时显式启用 VP8/VP9；FFmpeg configure 选项名是 `libvpx_vp9`，命令行编码器名是 `libvpx-vp9`。
- `libmp3lame` 用于 MP3 编码，脚本会手动生成 `libmp3lame.pc` 和 `lame.pc`，并给 FFmpeg configure 传入 `--extra-cflags` / `--extra-ldflags`，确保能检测到头文件和静态库。
- `libopus` 用于 Opus 编码/解码，脚本会手动生成 `opus.pc`，包含静态链接所需的 `-lm` 和头文件路径，确保 FFmpeg configure 能通过 `pkg-config` 检测到。
- `libfdk_aac` 用于高质量 AAC 编码。
- `pcm_s16le` 是 FFmpeg 原生 PCM 编解码器，已启用。
- `libfdk_aac` 属于 nonfree 组件，因此构建参数包含 `--enable-nonfree`。

## 构建工具要求

构建外部依赖需要以下工具，请提前安装：

### Windows x64（交叉编译，在 Linux 上执行）

```bash
sudo apt install -y mingw-w64 build-essential yasm nasm git pkg-config cmake autoconf automake libtool
```

### Linux x64

```bash
sudo apt install -y build-essential yasm nasm pkg-config libva-dev libdrm-dev git cmake autoconf automake libtool
```

### macOS arm64

```bash
brew install yasm nasm pkg-config cmake autoconf automake libtool
```

工具用途说明：

- **cmake**：编译 `x265`
- **autoconf / automake / libtool**：`fdk-aac`、`opus`、`lame` 的 `autoreconf -fiv` 和 `./configure` 需要
- **yasm / nasm**：`x264`、`libvpx` 汇编优化需要
- **pkg-config**：FFmpeg configure 查找外部库需要
- **mingw-w64**：Windows 交叉编译工具链

## 全局裁剪策略

三个脚本都启用：

- `--disable-everything`
- `--disable-programs`
- `--enable-ffmpeg`
- `--disable-avdevice`
- `--disable-postproc`
- `--disable-network`
- `--disable-doc`
- `--disable-debug`
- `--enable-small`
- `--enable-stripping`
- `--enable-lto`

只构建 `ffmpeg` 命令行工具，不构建 `ffplay` 和 `ffprobe`。

## 协议支持

启用协议：

- `file`
- `pipe`

禁用网络协议，例如：

- `http`
- `https`
- `rtmp`
- `tcp`
- `udp`

## 容器格式支持

### 输出容器 muxer

- `mp4`
- `mov`
- `matroska`
- `webm`
- `flv`
- `avi`
- `mpegts`
- `rawvideo`
- `wav`
- `mp3`
- `ogg`
- `adts`
- `ac3`
- `flac`
- `null`

### 输入容器 demuxer

- `mov`
- `matroska`
- `flv`
- `avi`
- `mpegts`
- `mpegvideo`
- `rawvideo`
- `wav`
- `mp3`
- `ogg`
- `aac`
- `ac3`
- `flac`
- `concat`
- `image2`

## 视频编码器

### 软件视频编码器

- `libx264`：H.264 高质量软件编码
- `libx265`：HEVC/H.265 高质量软件编码
- `libvpx_vp9`：VP9 编码
- `mpeg4`
- `mpeg2video`
- `flv`
- `h263`
- `h263p`
- `mjpeg`
- `ffv1`
- `png`
- `bmp`

### 硬件视频编码器

Windows x64：

- `h264_nvenc`
- `hevc_nvenc`

Linux x64：

- `h264_nvenc`
- `hevc_nvenc`
- `h264_vaapi`
- `hevc_vaapi`

macOS arm64：

- `h264_videotoolbox`
- `hevc_videotoolbox`

## 视频解码器

启用视频解码器：

- `h264`
- `hevc`
- `mpeg4`
- `mpeg2video`
- `mpegvideo`
- `vp9`
- `vp8`
- `av1`
- `flv`
- `h263`
- `mjpeg`
- `png`
- `bmp`

Windows x64 / Linux x64 额外启用：

- `h264_cuvid`
- `hevc_cuvid`

## 音频编码器

启用音频编码器：

- `libfdk_aac`
- `libmp3lame`
- `libopus`
- `aac`
- `ac3`
- `eac3`
- `flac`
- `opus`
- `pcm_s16le`
- `mp2`
- `vorbis`
- `wavpack`

## 音频解码器

启用音频解码器：

- `aac`
- `ac3`
- `eac3`
- `mp3`
- `flac`
- `libopus`
- `opus`
- `vorbis`
- `pcm_s16le`
- `mp2`
- `wavpack`

## 字幕编解码器

- `ass`
- `ssa`
- `subrip`
- `srt`
- `webvtt`

## Parser 支持

- `h264`
- `hevc`
- `mpeg4video`
- `mpegvideo`
- `vp9`
- `vp8`
- `av1`
- `aac`
- `ac3`
- `flac`
- `opus`
- `mpegaudio`
- `vorbis`
- `mjpeg`
- `png`

## Bitstream Filter 支持

- `h264_mp4toannexb`
- `hevc_mp4toannexb`
- `aac_adtstoasc`
- `extract_extradata`
- `null`

## 滤镜支持

### 视频滤镜

- `buffer`
- `buffersink`
- `scale`
- `fps`
- `format`
- `null`
- `crop`
- `transpose`
- `vflip`
- `hflip`
- `pad`
- `setpts`
- `setsar`
- `setdar`
- `yadif`

### 音频滤镜

- `abuffer`
- `abuffersink`
- `aresample`
- `aformat`
- `anull`
- `volume`
- `atempo`

## 硬件加速支持

### Windows x64

- `--enable-nvenc`
- `--enable-nvdec`
- `--enable-hwaccel=h264_cuvid,hevc_cuvid`

支持：

- H.264 NVENC 编码：`h264_nvenc`
- HEVC NVENC 编码：`hevc_nvenc`
- H.264 CUVID 解码：`h264_cuvid`
- HEVC CUVID 解码：`hevc_cuvid`

### Linux x64

- `--enable-nvenc`
- `--enable-nvdec`
- `--enable-vaapi`
- `--enable-hwaccel=h264_vaapi,hevc_vaapi,h264_cuvid,hevc_cuvid`

支持：

- NVIDIA H.264 编码：`h264_nvenc`
- NVIDIA HEVC 编码：`hevc_nvenc`
- VAAPI H.264 编码：`h264_vaapi`
- VAAPI HEVC 编码：`hevc_vaapi`
- CUVID/VAAPI 硬件解码

### macOS arm64

- `--enable-videotoolbox`
- `--enable-hwaccel=h264_videotoolbox,hevc_videotoolbox`

支持：

- H.264 VideoToolbox 编码：`h264_videotoolbox`
- HEVC VideoToolbox 编码：`hevc_videotoolbox`
- H.264/HEVC VideoToolbox 硬件解码

## 检查构建结果

```bash
ffmpeg -version
ffmpeg -buildconf
ffmpeg -encoders
ffmpeg -decoders
ffmpeg -muxers
ffmpeg -demuxers
ffmpeg -filters
ffmpeg -protocols
```

检查关键编码器：

```bash
ffmpeg -encoders | grep -E "libx264|libx265|libvpx|libmp3lame|libopus|libfdk_aac|h264_nvenc|hevc_nvenc"
```

检查关键解码器：

```bash
ffmpeg -decoders | grep -E "h264|hevc|vp9|vp8|av1|aac|mp3|flac|opus|pcm_s16le"
```

## 常用压缩命令

### H.264 软件压缩

```bash
ffmpeg -i input.mp4 -c:v libx264 -preset medium -crf 23 -c:a libfdk_aac -b:a 96k output_h264.mp4
```

### H.265 / HEVC 软件压缩

```bash
ffmpeg -i input.mp4 -c:v libx265 -preset medium -crf 28 -c:a libfdk_aac -b:a 96k output_h265.mp4
```

### VP9 压缩

```bash
ffmpeg -i input.mp4 -c:v libvpx-vp9 -crf 32 -b:v 0 -row-mt 1 -c:a libopus -b:a 96k output_vp9.webm
```

### MP3 音频输出

```bash
ffmpeg -i input.mp4 -vn -c:a libmp3lame -b:a 128k output.mp3
```

### Opus 音频输出

```bash
ffmpeg -i input.mp4 -vn -c:a libopus -b:a 96k output.opus
```

## 各视频格式互转命令

### MP4 转 MKV

```bash
ffmpeg -i input.mp4 -c copy output.mkv
```

### MKV 转 MP4

```bash
ffmpeg -i input.mkv -c:v libx264 -crf 23 -preset medium -c:a libfdk_aac -b:a 96k output.mp4
```

如果 MKV 内部本来就是 H.264 + AAC，可以直接无损换封装：

```bash
ffmpeg -i input.mkv -c copy output.mp4
```

### MP4 转 WebM / VP9

```bash
ffmpeg -i input.mp4 -c:v libvpx-vp9 -crf 32 -b:v 0 -row-mt 1 -c:a libopus -b:a 96k output.webm
```

### WebM 转 MP4

```bash
ffmpeg -i input.webm -c:v libx264 -crf 23 -preset medium -c:a libfdk_aac -b:a 96k output.mp4
```

### MP4 转 AVI

```bash
ffmpeg -i input.mp4 -c:v mpeg4 -q:v 5 -c:a libmp3lame -b:a 128k output.avi
```

### AVI 转 MP4

```bash
ffmpeg -i input.avi -c:v libx264 -crf 23 -preset medium -c:a libfdk_aac -b:a 96k output.mp4
```

### MP4 转 FLV

```bash
ffmpeg -i input.mp4 -c:v flv -q:v 5 -c:a libmp3lame -b:a 128k output.flv
```

### FLV 转 MP4

```bash
ffmpeg -i input.flv -c:v libx264 -crf 23 -preset medium -c:a libfdk_aac -b:a 96k output.mp4
```

### MP4 转 MPEG-TS

```bash
ffmpeg -i input.mp4 -c:v libx264 -crf 23 -preset medium -c:a libfdk_aac -b:a 96k -f mpegts output.ts
```

### MPEG-TS 转 MP4

```bash
ffmpeg -i input.ts -c:v libx264 -crf 23 -preset medium -c:a libfdk_aac -b:a 96k output.mp4
```

### MOV 转 MP4

```bash
ffmpeg -i input.mov -c:v libx264 -crf 23 -preset medium -c:a libfdk_aac -b:a 96k output.mp4
```

如果 MOV 内部编码兼容 MP4，也可以直接换封装：

```bash
ffmpeg -i input.mov -c copy output.mp4
```

### MP4 转 MOV

```bash
ffmpeg -i input.mp4 -c copy output.mov
```

### 任意视频转 H.264 MP4

```bash
ffmpeg -i input.any -c:v libx264 -preset medium -crf 23 -c:a libfdk_aac -b:a 96k output.mp4
```

### 任意视频转 H.265 MP4

```bash
ffmpeg -i input.any -c:v libx265 -preset medium -crf 28 -c:a libfdk_aac -b:a 96k output.mp4
```

### 任意视频转 VP9 WebM

```bash
ffmpeg -i input.any -c:v libvpx-vp9 -crf 32 -b:v 0 -row-mt 1 -c:a libopus -b:a 96k output.webm
```

### 压缩并改分辨率

```bash
ffmpeg -i input.mp4 -vf scale=1280:-2 -c:v libx264 -preset medium -crf 24 -c:a libfdk_aac -b:a 96k output_720p.mp4
```

### 只改容器，不重新编码

```bash
ffmpeg -i input.mkv -c copy output.mp4
```

## GitHub Actions 自动构建

本项目配置了 GitHub Actions workflow（`.github/workflows/main.yml`），push 到 `master` 分支或手动触发即可自动构建三平台产物。

### 触发方式

- **自动触发**：push 代码到 `master` 分支
- **手动触发**：在 GitHub 仓库页面 → Actions → 选择 workflow → Run workflow

### 构建产物

| 平台 | artifact 名 | 内容 |
|---|---|---|
| Windows x64 | `ffmpeg-win-x64` | `ffmpeg.exe` |
| Linux x64 | `ffmpeg-linux-x64` | `ffmpeg` |
| macOS arm64 | `ffmpeg-mac-arm64` | `ffmpeg` |

构建完成后在 Actions 页面下载 artifact。GitHub 会自动把 artifact 打成 zip，因此 workflow 直接上传二进制文件，不再额外生成 `.zip` 或 `.tar.gz`，避免出现“压缩包套压缩包”。

### 注意事项

- GitHub Actions 每次运行都是全新虚拟机，不需要手动清理上次环境。
- Windows x64 在 Ubuntu 上交叉编译（`mingw-w64`），不是在 Windows runner 上构建。
- workflow 中 Linux 已配置 `strip` 和 `upx` 压缩，Windows 仅执行 `strip`；Windows 版不使用 `upx`，避免压缩后的 `ffmpeg.exe` 启动即崩溃。Windows 版还会静态链接 MinGW 的 `libgcc` / `libstdc++`，避免目标机器缺少运行库或出现入口点错误。
- `upload-artifact` 下载时会自动变成 zip，workflow 直接上传二进制文件，避免 zip 内再套 zip/tar.gz。
- 如果 Action 报错 `autoreconf: command not found`，说明构建工具未装全，确认 workflow 的 Install 步骤包含 `autoconf automake libtool`。
- 如果 Linux 报 `vaapi requested but not found`，确认安装了 `libva-dev` 和 `libdrm-dev`，并且不要用 `PKG_CONFIG_LIBDIR` 覆盖系统 pkg-config 搜索路径。

## 注意事项

- `libfdk_aac` 会让 FFmpeg 变成 nonfree 构建，不能按 GPL/LGPL 二进制形式再分发。
- NVENC 需要兼容的 NVIDIA 驱动。如果提示 NVENC API 版本不够，请升级显卡驱动。
- 网络协议已禁用，只支持本地文件和管道。
- 该版本追求体积小和常用转码能力，不追求覆盖所有冷门格式。
- `x265` 编译时间较长，属于正常现象。
- Windows 交叉编译时 `x265` 需要 cmake toolchain 文件，脚本会自动生成，并强制使用 `-static -static-libgcc -static-libstdc++` 静态链接 MinGW 运行库，避免运行时缺少 `libstdc++` 入口点。为避免 Windows 下 `libx265` 运行时访问冲突，脚本还关闭了 x265 汇编优化、使用 `gcc-posix` / `g++-posix` 编译器、强制 FFmpeg 使用 `pthreads`（`--enable-pthreads --disable-w32threads`）、显式链接 `winpthread`，并移除了 Windows FFmpeg 的 LTO。
- 如果 FFmpeg configure 报 `x265 not found using pkg-config`，通常是缺少 `x265.pc`、静态链接参数不完整，或 `PKG_CONFIG_PATH` 未指向依赖目录；当前脚本已自动生成 `x265.pc` 并设置 `PKG_CONFIG_PATH`。Linux 下 `x265.pc` 已补充 `-lstdc++ -lpthread -lm -ldl`，并在构建 x265 时关闭 `libnuma`。
- 如果 FFmpeg configure 报 `opus not found using pkg-config`，通常是缺少 `opus.pc`、静态链接参数不完整，或 `PKG_CONFIG_PATH` 未指向依赖目录；当前脚本已自动生成 `opus.pc`，并设置 `PKG_CONFIG_PATH`。
- 如果 FFmpeg configure 报 `libmp3lame >= 3.98.3 not found`，通常是 FFmpeg 检测不到 `lame/lame.h` 或 `libmp3lame.a`；当前脚本已在 configure 阶段传入外部依赖的 include/lib 路径，并自动生成 `libmp3lame.pc` 与 `lame.pc`。
- 如果运行时提示 `Unknown encoder 'libvpx-vp9'`，说明产物里没有编进 VP9 编码器；当前脚本已显式启用 `libvpx` 的 VP8/VP9，并在 FFmpeg configure 前打印 `pkg-config vpx` 诊断信息。
