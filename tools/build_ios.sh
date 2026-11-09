#!/bin/bash
# Cross-compile the runtime and shared launcher without game files.
set -euo pipefail
cd "$(dirname "$0")/.."
SDK=${1:-iphonesimulator}
case "$SDK" in
    iphoneos|iphonesimulator) ;;
    *) echo "Usage: $0 [iphonesimulator|iphoneos]" >&2; exit 2 ;;
esac
MIN=18.0
TARGET=arm64-apple-ios$MIN
[ "$SDK" != iphonesimulator ] || TARGET+=-simulator
SYSROOT=$(xcrun --sdk "$SDK" --show-sdk-path)
CC=$(xcrun --sdk "$SDK" --find clang)
JOBS=${JOBS:-$(sysctl -n hw.ncpu 2>/dev/null || echo 4)}
OUT=$PWD/build/ios/$SDK
DOWNLOADS=$PWD/build/ios/downloads
mkdir -p "$OUT" "$DOWNLOADS"

fetch() {
    local archive=$DOWNLOADS/$1
    if [ ! -f "$archive" ]; then
        curl -fsSL "$2" -o "$archive.part"
        mv "$archive.part" "$archive"
    fi
    echo "$3  $archive" | shasum -a 256 -c --quiet
}
unpack() {
    local dst=$OUT/$2
    [ ! -d "$dst" ] || return 0
    mkdir -p "$dst.tmp"
    tar -xf "$DOWNLOADS/$1" -C "$dst.tmp" --strip-components 1
    mv "$dst.tmp" "$dst"
}
fetch SDL3-3.4.18.tar.gz https://github.com/libsdl-org/SDL/releases/download/release-3.4.18/SDL3-3.4.18.tar.gz \
    9c75cf16330322c217dedd2e0609f1124f1b54b8633e763467b4684d0f4334a3
fetch ffmpeg-9.0.2.tar.xz https://ffmpeg.org/releases/ffmpeg-9.0.2.tar.xz \
    8c3850283eb25fa026482078a04051e0be17347b09ef81a0849bec15a96e002e
unpack SDL3-3.4.18.tar.gz sdl
unpack ffmpeg-9.0.2.tar.xz ffmpeg

if [ ! -f "$OUT/deps/lib/libavformat.a" ] || [ ! -f "$OUT/deps/include/libswscale/swscale.h" ]; then
    mkdir -p "$OUT/ffmpeg-build"
    (cd "$OUT/ffmpeg-build"
    "$OUT/ffmpeg/configure" --prefix="$OUT/deps" --cc="$CC" --arch=arm64 --target-os=darwin \
        --enable-cross-compile --sysroot="$SYSROOT" --extra-cflags="-target $TARGET" \
        --extra-ldflags="-target $TARGET" --enable-static --disable-shared \
        --disable-autodetect --disable-programs --disable-doc --disable-network --disable-avdevice --disable-avfilter \
        --disable-swresample --disable-everything --enable-protocol=file --enable-demuxer=matroska,mov \
        --enable-decoder=vp9,vp8,vorbis,opus,h264,aac --enable-parser=vp9,vp8,vorbis,opus,h264,aac
    make -j"$JOBS"
    make install)
fi

GAME_SOURCE=
if [ -n "${IOS_GAME_ROOT:-}" ]; then
    GAME_ROOT=$(cd "$IOS_GAME_ROOT" && pwd -P)
    GAME_SOURCE=$OUT/generated-private
    mkdir -p "$GAME_SOURCE"
    python3 ios/game_ids.py "$GAME_ROOT/exefs" "$GAME_SOURCE/ios_game_ids.h"
    PY=$PWD/tools/venv/bin/python
    (cd tools
    "$PY" gen.py sdk "$GAME_ROOT/exefs/sdk" 0x7008000000 "$GAME_SOURCE/sdk" --hle ../runtime/hle/hle_symbols.txt
    "$PY" gen.py main "$GAME_ROOT/exefs/main" 0x7000000000 "$GAME_SOURCE/main")
fi

cmake -S ios -B "$OUT/app" -G Ninja -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT="$SYSROOT" \
    -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET="$MIN" -DCMAKE_BUILD_TYPE=Release \
    -DMONZA_SDL_SOURCE="$OUT/sdl" -DMONZA_FFMPEG="$OUT/deps" -DMONZA_IOS_GAME_SOURCE="$GAME_SOURCE"
cmake --build "$OUT/app" -j "$JOBS"
APP=$OUT/app/MonZaMac.app
if [ "$SDK" = iphonesimulator ]; then
    codesign -f -s - "$APP"
fi
echo "$APP"
