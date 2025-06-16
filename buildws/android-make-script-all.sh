#!/bin/bash

# Build libwebsockets static library without SSL support for Android using modern NDK

# Get the absolute path to the current directory where the script is located
CURRENT_DIR=$(cd "$(dirname "$0")" && pwd) 
SCRIPT_DIR=$CURRENT_DIR

set -e # end script at first mistake

##############################
# Check the directory exists #
##############################
function check_directory(){
if [ -d "$2" ]; then
    echo "$1 path:"$'\n'" $2"
else
    echo "Not exist $1 path:"$'\n'" $2"
    exit 1
fi
}

#########################
# Check the file exists #
#########################
function check_file(){
    if [ -f "$2" ]; then
        echo "$1 file:"$'\n'" $2"
    else
        echo "Not exist $1 file:"$'\n'" $2"
        exit 1
    fi
}


# Set paths
export NDK="$ANDROID_NDK"  # Your android NDK path
export SDK="$ANDROID_SDK"  # Your android SDK path
export CMAKE="$SDK/cmake/3.22.1/bin/cmake"  # Your CMAKE path in android SDK
export API_LEVEL=21


# Check paths
check_directory "NDK" "$NDK"  # Check android NDK set in your system path
check_directory "SDK" "$SDK"  # Check android SDK set in your system path
check_file "CMAKE" "$CMAKE"   # Check CMAKE from android SDK


# Download packages libwebsockets
if [ ! -f libwebsockets.tar.gz ]; then
  git clone https://github.com/warmcat/libwebsockets.git
  check_directory "libwebsockets" "$SCRIPT_DIR/libwebsockets"  
  cd libwebsockets 
  # checkout supported git commit
  git checkout 5102a5c8d6110b25a01492fcf96fb668b13dd6e7 
  cd ..
  # pack libwebsocket for next script 
  tar czf libwebsockets.tar.gz libwebsockets
fi

# Create build directories

# libwebsockets 
cd "$SCRIPT_DIR/libwebsockets"
rm -rf ./build
mkdir build


#########################################################
# set compiler and archivator in dependense of platform #
#########################################################
function setup_toolchain() {
    ABI=$1

    UNAME=$(uname -s) # check current OS
    ARCH=$(uname -m)  # check CPU architecture


    # set HOST_TAG value in depence of current OS and CPU architecture
    case "$UNAME" in
        Linux)
            HOST_TAG=linux-x86_64
            ;;
        Darwin)
            case "$ARCH" in
                arm64)
                    HOST_TAG=darwin-arm64
                    ;;
                *)
                    HOST_TAG=darwin-x86_64
                    ;;
            esac
            ;;
        MINGW*|MSYS*|CYGWIN*)
            HOST_TAG=windows-x86_64
            ;;
        *)
            echo "Unsupported system: $UNAME"
            exit 1
            ;;
    esac

    # set toolchain path
    TOOLCHAIN="$NDK/toolchains/llvm/prebuilt/$HOST_TAG"
    export AR="$TOOLCHAIN/bin/llvm-ar"

    case "$ABI" in
        armeabi-v7a)
            export CC="$TOOLCHAIN/bin/armv7a-linux-androideabi$API_LEVEL-clang"
            ;;
        arm64-v8a)
            export CC="$TOOLCHAIN/bin/aarch64-linux-android$API_LEVEL-clang"
            ;;
        x86)
            export CC="$TOOLCHAIN/bin/i686-linux-android$API_LEVEL-clang"
            ;;
        x86_64)
            export CC="$TOOLCHAIN/bin/x86_64-linux-android$API_LEVEL-clang"
            ;;
        *)
            echo "Unknown ABI: $ABI"
            exit 1
            ;;
    esac
}

##############################
# Build libwebsockets module #
##############################
function build_libwebsockets() {
    # setup toolchain compiler and archivator
    ABI=$1
    BUILD_DIR=$2
    setup_toolchain "$ABI"
    echo "Building libwebsockets for $ABI..."

    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"

    $CMAKE -DCMAKE_POLICY_DEFAULT_CMP0057=NEW "$SCRIPT_DIR/libwebsockets" \
        -DCMAKE_TOOLCHAIN_FILE=$NDK/build/cmake/android.toolchain.cmake \
        -DANDROID_ABI=$ABI \
        -DANDROID_PLATFORM=android-$API_LEVEL \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_C_COMPILER="$CC" \
        -DCMAKE_AR="$AR" \
        -DCMAKE_INSTALL_PREFIX=$2 \
        -DLWS_WITH_STATIC=ON \
        -DLWS_WITH_SHARED=OFF \
        -DLWS_WITHOUT_TESTAPPS=ON \
        -DLWS_WITH_SSL=OFF \
        -DLWS_WITH_HTTP2=ON \
        -DLWS_USE_BUNDLED_ZLIB=OFF \
        -DLWS_WITH_ZLIB=OFF \
        -DLWS_WITHOUT_DAEMONIZE=ON \
        -DLWS_IPV6=OFF \
        -DLWS_WITH_PLUGINS=OFF \
        -DLWS_ROLE_DBUS=OFF \
        -DLWS_CMAKE_WARNINGS_ARE_ERRORS=OFF \
        -DLWS_WITHOUT_BUILTIN_GETIFADDRS=OFF \
        -DLWS_WITH_GETIFADDRS=OFF \
        -DLWS_WITH_GETGRNAM=OFF \
        -DLWS_WITH_GETGRGID=OFF \
        -DLWS_NO_LOGS=ON \
        -DCMAKE_SHARED_LINKER_FLAGS="-Wl,--gc-sections" \
        -DCMAKE_C_FLAGS="-fvisibility=hidden -ffunction-sections -fdata-sections -Wno-error=unused-label -Wno-error=sign-conversion -std=c11 -DLWS_WITH_GETIFADDRS=0 -DLWS_WITH_GETGRNAM=0 -DLWS_WITH_GETGRGID=0"

    make -j$(nproc)
    make install

    # Сlear unnecessary files after build complete
    find "$BUILD_DIR" -mindepth 1 -maxdepth 1 ! -name lib ! -name include -exec rm -rf {} +
    echo "Build for $ABI completed: $BUILD_DIR"
    cd ../..
}


function build_all() {
    ABI=$1
    OUTPUT_LIBWEBSOCKET_DIR="$SCRIPT_DIR/build/build-android-$ABI"
  
    # Build libwebsockets module
    build_libwebsockets $ABI $OUTPUT_LIBWEBSOCKET_DIR 
    echo "Build for $ABI completed. Output in $OUTPUT_LIBWEBSOCKET_DIR"
}

case "$1" in
    ARM | arm)
        build_all armeabi-v7a
        ;;
    ARM64 | arm64)
        build_all arm64-v8a
        ;;
    X86 | x86)
        build_all x86
        ;;
    X86_64 | x86_64)
        build_all x86_64
        ;;
    ALL | all)
        for abi in armeabi-v7a arm64-v8a x86 x86_64; do
            build_all $abi
        done
        ;;
    *)
        echo "Usage: $0 {ARM|ARM64|X86|X86_64|ALL}"
        ;;
esac

