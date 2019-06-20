# !/bin/bash

set -eu

VERSION="8.0.0"

LLVM_SOURCES_URL="http://releases.llvm.org/${VERSION}/llvm-${VERSION}.src.tar.xz"
CLANG_SOURCES_URL="http://releases.llvm.org/${VERSION}/cfe-${VERSION}.src.tar.xz"

CURRENT_DIR="$(pwd)"
LLVM_DIR="${CURRENT_DIR}/llvm"
CLANG_DIR="${CURRENT_DIR}/clang"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

print_help_and_die() {
    echo "Usage: $0 path_to_ndk"
    echo "  path_to_ndk should point to NDK directory to be used with cmake to"
    echo "  create initial version of genereated headers for Android"
    exit -1
}

ask_if_continue() {
    echo "This script will initialize clang and llvm (${VERSION}) in ${CLANG_DIR} and ${LLVM_DIR}."
    read -p "continue? [y/N] " should_continue
    case "${should_continue}" in
        y|Y ) ;;
        * ) echo "aborting"; exit 1;;
    esac
}

get_sources() {
    echo "downloading and unpacking sources..."
    (
        set -x
        cd "${TMP_DIR}"
        wget "${LLVM_SOURCES_URL}" -q
        tar xf "llvm-${VERSION}.src.tar.xz"

        cp -r "llvm-${VERSION}.src" "${LLVM_DIR}"

        wget "${CLANG_SOURCES_URL}" -q
        tar xf "cfe-${VERSION}.src.tar.xz"
        cp -r "cfe-${VERSION}.src" "${CLANG_DIR}"
    )
}

generate_host_llvm_headers() {
    # To generate host headers it's enough to invoke cmake and copy generated
    # *.h and *.def files from llvm/Config
    echo "generating headers for host..."
    (
        set -x
        cd "${TMP_DIR}"
        mkdir host_build_dir
        cd host_build_dir

        cmake "${LLVM_DIR}"

        mkdir "${LLVM_DIR}/host"
        find include/llvm/Config -type f \
             \( -name "*.h" -o -name "*.def" \) \
             -exec cp --parents "{}" "${LLVM_DIR}/host" ";"
    )
}

generate_android_headers() {
    # Generating headers for Android is a bit more challenging. We need to
    # setup ndk toolchain and tell cmake to use it. Once cmake finishes
    # running we can copy relevant headers again.
    echo "generating headers for Android..."
    (
        set -x
        cd "${TMP_DIR}"
        eval "${NDK_PATH}/build/tools/make_standalone_toolchain.py" \
             --arch arm64 \
             --api 28 \
             --install-dir "${TMP_DIR}/toolchain"

        cat > "${TMP_DIR}/toolchain.cmake" <<EOF
set(CMAKE_SYSTEM_NAME Android)
set(CMAKE_SYSTEM_VERSION 28)
set(CMAKE_ANDROID_STANDALONE_TOOLCHAIN ${TMP_DIR}/toolchain)
set(CMAKE_ANDROID_ARCH_ABI arm64-v8a)
EOF

        mkdir android_build_dir
        cd android_build_dir

        cmake "${LLVM_DIR}" \
              -DLLVM_ENABLE_PROJECTS=clang \
              -DCMAKE_TOOLCHAIN_FILE="${TMP_DIR}/toolchain.cmake"

        mkdir "${LLVM_DIR}/device"
        find include/llvm/Config -type f \
             \( -name "*.h" -o -name "*.def" \) \
             -exec cp --parents "{}" "${LLVM_DIR}/device" ";"

        cd tools/clang
        mkdir "${CLANG_DIR}/device"
        find include/clang -type f \
             \( -name "*.h" -o -name "*.inc" \) \
             -exec cp --parents "{}" "${CLANG_DIR}/device" ";"
    )
}

if [[ $# -ne 1 ]]; then
    print_help_and_die
fi
NDK_PATH=$1

ask_if_continue
get_sources
generate_host_llvm_headers
generate_android_headers
