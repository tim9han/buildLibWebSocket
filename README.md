The repository is based on https://github.com/honjane/buildLibWebSocket

This repository is designed to build the libwebsocket.so file for use as http server/client in your project. 

There have been significant changes in the NDK (NDK r19+), which required changes in honjane's script.

Major changes in the modern NDK:
1. Clang instead of GCC:
Old: arm-linux-androideabi-gcc
New: armv7a-linux-androideabi21-clang

2. Prebuilt toolchain:
Old: Create a standalone toolchain
New: Directly use $NDK/toolchains/llvm/prebuilt/

3. API level in the compiler name:
New approach includes API level in the name: ${TARGET}${API}-clang

4. LLVM tools:
llvm-ar, llvm-ranlib, llvm-strip instead of GNU versions

-------------------------------------

To build the project, run the android-make-script-all.sh script in the directory buildws

Use the build parameter:
ARM|ARM64|X86|X86_64|ALL

The build has been tested on android 11 and 12 as an http server.

!Attention! The repository uses only the http server, to run the https server you will need to build the libwebsocket library together with SSL (see honjane's repository)
