#!/bin/bash
set -ex

# ============================================================
# FFmpeg n7.1 minimal build script — Windows x64 (cross-compile on Linux)
# Usage:
#   ./build-win-x64.sh build-dep   # build external deps
#   ./build-win-x64.sh compile     # configure + compile FFmpeg
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEPS_DIR="$SCRIPT_DIR/deps"
INSTALL_PREFIX="$DEPS_DIR/install-win64"
OUTPUT_DIR="$SCRIPT_DIR/output-win64"
NPROC=$(nproc 2>/dev/null || echo 4)

# MinGW cross-compile toolchain (posix threads variant)
HOST=x86_64-w64-mingw32
CC="${HOST}-gcc-posix"
CXX="${HOST}-g++-posix"
AR="${HOST}-ar"
RANLIB="${HOST}-ranlib"
STRIP="${HOST}-strip"
PKG_CONFIG="${HOST}-pkg-config"

export PKG_CONFIG_PATH="$INSTALL_PREFIX/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
export CROSS_COMPILE="${HOST}-"

# ----------------------------------------------------------
# Dependency builders
# ----------------------------------------------------------

build_nv_codec_headers() {
    cd "$DEPS_DIR"
    if [ ! -d nv-codec-headers ]; then
        git clone --depth 1 --branch n12.2.72.0 https://github.com/FFmpeg/nv-codec-headers.git
    fi
    cd nv-codec-headers
    make install PREFIX="$INSTALL_PREFIX"
}

build_x264() {
    cd "$DEPS_DIR"
    if [ ! -d x264 ]; then
        git clone --depth 1 https://code.videolan.org/videolan/x264.git
    fi
    cd x264
    make distclean || true
    ./configure \
        --prefix="$INSTALL_PREFIX" \
        --enable-static \
        --disable-cli \
        --disable-asm \
        --host="$HOST" \
        --cross-prefix="${HOST}-"
    make -j"$NPROC"
    make install
}

build_x265() {
    cd "$DEPS_DIR"
    if [ ! -d x265 ]; then
        git clone https://bitbucket.org/multicoreware/x265_git.git x265
    fi
    cd x265/source

    # Generate cmake toolchain file for MinGW cross-compile
    cat > toolchain-mingw.cmake <<EOF
set(CMAKE_SYSTEM_NAME Windows)
set(CMAKE_C_COMPILER $CC)
set(CMAKE_CXX_COMPILER $CXX)
set(CMAKE_AR $AR)
set(CMAKE_RANLIB $RANLIB)
set(CMAKE_FIND_ROOT_PATH $INSTALL_PREFIX)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
EOF

    rm -rf build-mingw && mkdir build-mingw && cd build-mingw
    cmake -G "Unix Makefiles" \
        -DCMAKE_TOOLCHAIN_FILE=../toolchain-mingw.cmake \
        -DCMAKE_INSTALL_PREFIX="$INSTALL_PREFIX" \
        -DENABLE_SHARED=OFF \
        -DENABLE_CLI=OFF \
        -DENABLE_LIBNUMA=OFF \
        -DENABLE_ASM=OFF \
        -DCMAKE_EXE_LINKER_FLAGS="-static -static-libgcc -static-libstdc++" \
        ..
    make -j"$NPROC"
    make install

    # Manually generate x265.pc with full static link flags for Windows
    cat > "$INSTALL_PREFIX/lib/pkgconfig/x265.pc" <<EOF
prefix=$INSTALL_PREFIX
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: x265
Description: H.265/HEVC encoder
Version: 3.5
Libs: -L\${libdir} -lx265 -lstdc++ -lpthread -lm
Cflags: -I\${includedir}
EOF
}

build_libvpx() {
    cd "$DEPS_DIR"
    if [ ! -d libvpx ]; then
        git clone --depth 1 --branch v1.14.1 https://github.com/webmproject/libvpx.git
    fi
    cd libvpx
    make distclean || true
    ./configure \
        --prefix="$INSTALL_PREFIX" \
        --enable-vp8 \
        --enable-vp9 \
        --disable-shared \
        --enable-static \
        --disable-examples \
        --disable-tools \
        --disable-docs \
        --disable-unit-tests \
        --target=x86_64-win64-gcc
    make -j"$NPROC"
    make install
}

build_fdk_aac() {
    cd "$DEPS_DIR"
    if [ ! -d fdk-aac ]; then
        git clone --depth 1 --branch v2.0.2 https://github.com/mstorsjo/fdk-aac.git
    fi
    cd fdk-aac
    make distclean || true
    autoreconf -fiv
    CFLAGS="-O2" CXXFLAGS="-O2" \
    ./configure \
        --prefix="$INSTALL_PREFIX" \
        --disable-shared \
        --enable-static \
        --host="$HOST" \
        CC="$CC" CXX="$CXX" AR="$AR" RANLIB="$RANLIB"
    make -j"$NPROC"
    make install
}

build_opus() {
    cd "$DEPS_DIR"
    if [ ! -d opus ]; then
        git clone --depth 1 --branch v1.5.2 https://github.com/xiph/opus.git
    fi
    cd opus
    make distclean || true
    autoreconf -fiv
    CFLAGS="-O2" \
    ./configure \
        --prefix="$INSTALL_PREFIX" \
        --disable-shared \
        --enable-static \
        --host="$HOST" \
        CC="$CC" CXX="$CXX" AR="$AR" RANLIB="$RANLIB"
    make -j"$NPROC"
    make install

    # Ensure opus.pc includes -lm for static linking
    sed -i 's/^Libs: /Libs: -lm /' "$INSTALL_PREFIX/lib/pkgconfig/opus.pc" 2>/dev/null || true
}

build_lame() {
    cd "$DEPS_DIR"
    if [ ! -d lame-3.100 ]; then
        wget -q https://downloads.sourceforge.net/project/lame/lame/3.100/lame-3.100.tar.gz
        tar xzf lame-3.100.tar.gz
    fi
    cd lame-3.100
    CFLAGS="-O2" \
    ./configure \
        --prefix="$INSTALL_PREFIX" \
        --disable-shared \
        --enable-static \
        --disable-frontend \
        --host="$HOST" \
        CC="$CC" CXX="$CXX" AR="$AR" RANLIB="$RANLIB"
    make -j"$NPROC"
    make install

    # Manually generate libmp3lame.pc and lame.pc
    cat > "$INSTALL_PREFIX/lib/pkgconfig/libmp3lame.pc" <<EOF
prefix=$INSTALL_PREFIX
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: libmp3lame
Description: MP3 encoding library
Version: 3.100
Libs: -L\${libdir} -lmp3lame
Cflags: -I\${includedir}
EOF
    cp "$INSTALL_PREFIX/lib/pkgconfig/libmp3lame.pc" "$INSTALL_PREFIX/lib/pkgconfig/lame.pc"
}

# ----------------------------------------------------------
# build-dep subcommand
# ----------------------------------------------------------
build_dep() {
    mkdir -p "$DEPS_DIR" "$INSTALL_PREFIX"
    build_nv_codec_headers
    build_x264
    build_x265
    build_libvpx
    build_fdk_aac
    build_opus
    build_lame
    echo "=== All dependencies built into $INSTALL_PREFIX ==="
}

# ----------------------------------------------------------
# compile subcommand
# ----------------------------------------------------------
compile() {
    cd "$SCRIPT_DIR"
    make distclean || true

    export PKG_CONFIG_PATH="$INSTALL_PREFIX/lib/pkgconfig:${PKG_CONFIG_PATH:-}"

    ./configure \
        --prefix="$OUTPUT_DIR" \
        --target-os=mingw32 \
        --arch=x86_64 \
        --cross-prefix="${HOST}-" \
        --cc="$CC" \
        --cxx="$CXX" \
        --pkg-config="$PKG_CONFIG" \
        --extra-cflags="-I$INSTALL_PREFIX/include" \
        --extra-ldflags="-L$INSTALL_PREFIX/lib -static -static-libgcc -static-libstdc++ -lwinpthread" \
        --disable-everything \
        --disable-programs \
        --enable-ffmpeg \
        --disable-avdevice \
        --disable-network \
        --disable-doc \
        --disable-debug \
        --enable-small \
        --enable-stripping \
        --enable-gpl \
        --enable-nonfree \
        --enable-libx264 \
        --enable-libx265 \
        --enable-libvpx \
        --enable-libfdk-aac \
        --enable-libmp3lame \
        --enable-libopus \
        --enable-pthreads \
        --disable-w32threads \
        --enable-nvenc \
        --enable-nvdec \
        --enable-hwaccel=h264_cuvid \
        --enable-hwaccel=hevc_cuvid \
        --enable-protocol=file \
        --enable-protocol=pipe \
        --enable-muxer=mp4 \
        --enable-muxer=mov \
        --enable-muxer=matroska \
        --enable-muxer=webm \
        --enable-muxer=flv \
        --enable-muxer=avi \
        --enable-muxer=mpegts \
        --enable-muxer=rawvideo \
        --enable-muxer=wav \
        --enable-muxer=mp3 \
        --enable-muxer=ogg \
        --enable-muxer=adts \
        --enable-muxer=ac3 \
        --enable-muxer=flac \
        --enable-muxer=null \
        --enable-demuxer=mov \
        --enable-demuxer=matroska \
        --enable-demuxer=flv \
        --enable-demuxer=avi \
        --enable-demuxer=mpegts \
        --enable-demuxer=mpegvideo \
        --enable-demuxer=rawvideo \
        --enable-demuxer=wav \
        --enable-demuxer=mp3 \
        --enable-demuxer=ogg \
        --enable-demuxer=aac \
        --enable-demuxer=ac3 \
        --enable-demuxer=flac \
        --enable-demuxer=concat \
        --enable-demuxer=image2 \
        --enable-encoder=libx264 \
        --enable-encoder=libx265 \
        --enable-encoder=libvpx-vp9 \
        --enable-encoder=mpeg4 \
        --enable-encoder=mpeg2video \
        --enable-encoder=flv \
        --enable-encoder=h263 \
        --enable-encoder=h263p \
        --enable-encoder=mjpeg \
        --enable-encoder=ffv1 \
        --enable-encoder=png \
        --enable-encoder=bmp \
        --enable-encoder=h264_nvenc \
        --enable-encoder=hevc_nvenc \
        --enable-encoder=libfdk_aac \
        --enable-encoder=libmp3lame \
        --enable-encoder=libopus \
        --enable-encoder=aac \
        --enable-encoder=ac3 \
        --enable-encoder=eac3 \
        --enable-encoder=flac \
        --enable-encoder=opus \
        --enable-encoder=pcm_s16le \
        --enable-encoder=mp2 \
        --enable-encoder=vorbis \
        --enable-encoder=wavpack \
        --enable-encoder=ass \
        --enable-encoder=ssa \
        --enable-encoder=subrip \
        --enable-encoder=srt \
        --enable-encoder=webvtt \
        --enable-decoder=h264 \
        --enable-decoder=hevc \
        --enable-decoder=mpeg4 \
        --enable-decoder=mpeg2video \
        --enable-decoder=mpegvideo \
        --enable-decoder=vp9 \
        --enable-decoder=vp8 \
        --enable-decoder=av1 \
        --enable-decoder=flv \
        --enable-decoder=h263 \
        --enable-decoder=mjpeg \
        --enable-decoder=png \
        --enable-decoder=bmp \
        --enable-decoder=h264_cuvid \
        --enable-decoder=hevc_cuvid \
        --enable-decoder=aac \
        --enable-decoder=ac3 \
        --enable-decoder=eac3 \
        --enable-decoder=mp3 \
        --enable-decoder=flac \
        --enable-decoder=libopus \
        --enable-decoder=opus \
        --enable-decoder=vorbis \
        --enable-decoder=pcm_s16le \
        --enable-decoder=mp2 \
        --enable-decoder=wavpack \
        --enable-decoder=ass \
        --enable-decoder=ssa \
        --enable-decoder=subrip \
        --enable-decoder=srt \
        --enable-decoder=webvtt \
        --enable-parser=h264 \
        --enable-parser=hevc \
        --enable-parser=mpeg4video \
        --enable-parser=mpegvideo \
        --enable-parser=vp9 \
        --enable-parser=vp8 \
        --enable-parser=av1 \
        --enable-parser=aac \
        --enable-parser=ac3 \
        --enable-parser=flac \
        --enable-parser=opus \
        --enable-parser=mpegaudio \
        --enable-parser=vorbis \
        --enable-parser=mjpeg \
        --enable-parser=png \
        --enable-bsf=h264_mp4toannexb \
        --enable-bsf=hevc_mp4toannexb \
        --enable-bsf=aac_adtstoasc \
        --enable-bsf=extract_extradata \
        --enable-bsf=null \
        --enable-filter=buffer \
        --enable-filter=buffersink \
        --enable-filter=scale \
        --enable-filter=fps \
        --enable-filter=format \
        --enable-filter=null \
        --enable-filter=crop \
        --enable-filter=transpose \
        --enable-filter=vflip \
        --enable-filter=hflip \
        --enable-filter=pad \
        --enable-filter=setpts \
        --enable-filter=setsar \
        --enable-filter=setdar \
        --enable-filter=yadif \
        --enable-filter=abuffer \
        --enable-filter=abuffersink \
        --enable-filter=aresample \
        --enable-filter=aformat \
        --enable-filter=anull \
        --enable-filter=volume \
        --enable-filter=atempo

    make -j"$NPROC"

    mkdir -p "$OUTPUT_DIR"
    cp ffmpeg.exe "$OUTPUT_DIR/"
    $STRIP "$OUTPUT_DIR/ffmpeg.exe"
    echo "=== FFmpeg built to $OUTPUT_DIR/ffmpeg.exe ==="
}

# ----------------------------------------------------------
# Main
# ----------------------------------------------------------
case "${1:-}" in
    build-dep) build_dep ;;
    compile)   compile ;;
    *) echo "Usage: $0 {build-dep|compile}"; exit 1 ;;
esac
