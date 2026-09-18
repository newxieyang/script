#!/bin/bash
set -Eeuo pipefail

# ============================================================
# Parameter Parsing
# ============================================================
usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  --src-dir PATH        SDK source directory (WSL path)"
    echo "  --build-root PATH     Build root directory (WSL path)"
    echo "  --third-party PATH    Third party directory (WSL path)"
    echo "  --lib-name NAME       Base library name (e.g. FAP)"
    echo "  --demo-android PATH   Demo Android path"
    echo "  --demo-qt PATH        Demo Qt path"
    echo "  --demo-win PATH       Demo Win path"
    echo "  --linux-only          (Optional) Flag to indicate linux-only build"
    echo "  --build-static BOOL   (Optional) Build static libraries: true|false (default: true)"
    exit 1
}

# Default values
SRC_DIR=""
BUILD_ROOT=""
THIRD_PARTY_DIR=""
LIB_BASE_NAME="FAP"
DEMO_ANDROID=""
DEMO_QT=""
DEMO_WIN=""
BUILD_STATIC="true"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --src-dir) SRC_DIR="$2"; shift 2 ;;
        --build-root) BUILD_ROOT="$2"; shift 2 ;;
        --third-party) THIRD_PARTY_DIR="$2"; shift 2 ;;
        --lib-name) LIB_BASE_NAME="$2"; shift 2 ;;
        --demo-android) DEMO_ANDROID="$2"; shift 2 ;;
        --demo-qt) DEMO_QT="$2"; shift 2 ;;
        --demo-win) DEMO_WIN="$2"; shift 2 ;;
        --linux-only) shift ;;
        --build-static)
            case "$(echo "$2" | tr '[:upper:]' '[:lower:]')" in
                true|on|1|yes)  BUILD_STATIC="true" ;;
                false|off|0|no) BUILD_STATIC="false" ;;
                *) echo "[ERROR] Invalid value for --build-static: '$2' (expected true|false)"; usage ;;
            esac
            shift 2
            ;;
        *) usage ;;
    esac
done

# Normalize build targets: shared is always built, static only when requested
if [ "${BUILD_STATIC}" = "true" ]; then
    BUILD_TYPES=(static shared)
else
    BUILD_TYPES=(shared)
fi

if [ -z "$SRC_DIR" ] || [ -z "$BUILD_ROOT" ]; then
    echo "[ERROR] Missing required arguments --src-dir and --build-root"
    usage
fi

echo "DEBUG: THIRD_PARTY_DIR received: $THIRD_PARTY_DIR"

# ============================================================
# Global Path Configuration (WSL Perspective)
# ============================================================
if [ -z "$THIRD_PARTY_DIR" ]; then
    THIRD_PARTY_DIR="$(dirname "$(dirname "$SRC_DIR")")/3rd"
fi

# Compiler Roots
AARCH64_GCC_ROOT="/opt/aarch64-gcc9.3"
LOCAL_GCC_ROOT="/opt/gcc-9.3.0"

# AArch64 Cross Compiler
AARCH64_GCC="${AARCH64_GCC_ROOT}/bin/aarch64-linux-gnu-gcc"
AARCH64_GXX="${AARCH64_GCC_ROOT}/bin/aarch64-linux-gnu-g++"
AARCH64_SYSROOT="$("${AARCH64_GCC}" --print-sysroot 2>/dev/null || true)"
AARCH64_TOOLCHAIN_FILE="${AARCH64_GCC_ROOT}/cmake/aarch64-gcc9.3.cmake"

# WSL Local x64 Compiler
LOCAL_GCC="${LOCAL_GCC_ROOT}/bin/gcc"
LOCAL_GXX="${LOCAL_GCC_ROOT}/bin/g++"

BUILD_JOBS="${BUILD_JOBS:-$(nproc)}"
CURRENT_BUILD=""

# ============================================================
# Error Trap
# ============================================================
error_trap()
{
    local exit_code=$?
    echo
    echo "============================================================"
    echo "[ERROR] BUILD FAILED"
    echo "============================================================"
    if [ -n "${CURRENT_BUILD}" ]; then
        echo "Build target : ${CURRENT_BUILD}"
    fi
    echo "Exit code    : ${exit_code}"
    echo
    exit "${exit_code}"
}
trap error_trap ERR

# ============================================================
# Helper Functions
# ============================================================
check_command()
{
    local command_name="$1"
    if ! command -v "${command_name}" >/dev/null 2>&1; then
        echo "[ERROR] Required command not found: ${command_name}"
        exit 1
    fi
}

check_shared_library_arch()
{
    local lib="$1"
    local expected_arch="$2"
    echo
    echo "Architecture check:"
    echo "  Library: ${lib}"
    if [ ! -f "${lib}" ]; then
        echo "[ERROR] Library not found: ${lib}"
        return 1
    fi
    local info
    info="$(file "${lib}")"
    echo "  ${info}"
    case "${expected_arch}" in
        arm64)
            if echo "${info}" | grep -qiE 'ARM aarch64|AArch64'; then
                echo "  [OK] Architecture: ARM64"
                return 0
            fi
            ;;
        x86_64)
            if echo "${info}" | grep -qiE 'x86-64|x86_64'; then
                echo "  [OK] Architecture: x86_64"
                return 0
            fi
            ;;
        pe-x86|pe-x86_64)
            if echo "${info}" | grep -qiE 'PE32 executable|PE32+ executable'; then
                echo "  [OK] Architecture: Windows PE"
                return 0
            fi
            ;;
        *)
            echo "[ERROR] Unknown architecture: ${expected_arch}"
            return 1
            ;;
    esac
    echo "  [ERROR] Wrong architecture! Expected: ${expected_arch}"
    return 1
}

check_static_library_arch()
{
    local lib="$1"
    local expected_arch="$2"
    echo
    echo "Architecture check:"
    echo "  Library: ${lib}"
    if [ ! -f "${lib}" ]; then
        echo "[ERROR] Library not found: ${lib}"
        return 1
    fi
    if ! ar t "${lib}" >/dev/null 2>&1; then
        echo "[ERROR] Invalid ar archive: ${lib}"
        return 1
    fi
    echo
    file "${lib}"
    local tmpdir
    tmpdir="$(mktemp -d)"
    cleanup_static_check(){ rm -rf "${tmpdir}"; }
    trap cleanup_static_check RETURN
    (
        cd "${tmpdir}"
        ar x "${lib}"
        local object_count
        object_count=$(find . -type f | wc -l)
        if [ "${object_count}" -eq 0 ]; then
            echo "[ERROR] No object files found in archive!"
            exit 1
        fi
        local failed=0
        local object machine
        while IFS= read -r object; do
            machine="$(readelf -h "${object}" 2>/dev/null | grep 'Machine:' | sed 's/^[[:space:]]*//')"
            case "${expected_arch}" in
                arm64)
                    if ! echo "${machine}" | grep -q 'AArch64'; then
                        echo "  [ERROR] Wrong arch ${object}: ${machine}"
                        failed=1
                    fi
                    ;;
                x86_64)
                    if ! echo "${machine}" | grep -qE 'Advanced Micro Devices X86-64|X86-64'; then
                        echo "  [ERROR] Wrong arch ${object}: ${machine}"
                        failed=1
                    fi
                    ;;
            esac
        done < <(find . -type f | sort)
        if [ "${failed}" -ne 0 ]; then
            echo "[ERROR] Static library contains wrong architecture!"
            exit 1
        fi
        case "${expected_arch}" in
            arm64) echo "  [OK] All objects are ARM64 (AArch64)" ;;
            x86_64) echo "  [OK] All objects are x86_64" ;;
        esac
    )
    local result=$?
    rm -rf "${tmpdir}"
    trap - RETURN
    return "${result}"
}

check_library_arch()
{
    local lib="$1"
    local expected_arch="$2"
    case "${lib}" in
        *.a) check_static_library_arch "${lib}" "${expected_arch}" ;;
        *.so) check_shared_library_arch "${lib}" "${expected_arch}" ;;
        *.dll|*.lib) check_shared_library_arch "${lib}" "${expected_arch}" ;;
        *) echo "[ERROR] Unsupported library type ${lib}"; return 1 ;;
    esac
}

read_version()
{
    VERSION_FILE="${SRC_DIR}/version.cmake"
    VERSION_MAJOR=$(grep -E '^[[:space:]]*set\(FAP_VERSION_MAJOR[[:space:]]+' "${VERSION_FILE}" | head -1 | sed -E 's/.*FAP_VERSION_MAJOR[[:space:]]+([0-9]+).*/\1/')
    VERSION_MINOR=$(grep -E '^[[:space:]]*set\(FAP_VERSION_MINOR[[:space:]]+' "${VERSION_FILE}" | head -1 | sed -E 's/.*FAP_VERSION_MINOR[[:space:]]+([0-9]+).*/\1/')
    VERSION_PATCH=$(grep -E '^[[:space:]]*set\(FAP_VERSION_PATCH[[:space:]]+' "${VERSION_FILE}" | head -1 | sed -E 's/.*FAP_VERSION_PATCH[[:space:]]+([0-9]+).*/\1/')
    VERSION_BUILD=$(grep -E '^[[:space:]]*set\(FAP_VERSION_BUILD[[:space:]]+' "${VERSION_FILE}" | head -1 | sed -E 's/.*FAP_VERSION_BUILD[[:space:]]+([0-9]+).*/\1/')
    if [ -z "${VERSION_MAJOR}" ] || [ -z "${VERSION_MINOR}" ] || [ -z "${VERSION_PATCH}" ] || [ -z "${VERSION_BUILD}" ]; then
        echo "[ERROR] Cannot parse version from ${VERSION_FILE}"
        exit 1
    fi
    VERSION="${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}.${VERSION_BUILD}"
    VERSION_DIR="${BUILD_ROOT}"

    mkdir -p "${VERSION_DIR}/Linux/arm"
    mkdir -p "${VERSION_DIR}/Linux/x64"
    mkdir -p "${VERSION_DIR}/Windows/x64/static"
    mkdir -p "${VERSION_DIR}/Windows/x64/shared"
    mkdir -p "${VERSION_DIR}/Windows/x86/static"
    mkdir -p "${VERSION_DIR}/Windows/x86/shared"
    mkdir -p "${VERSION_DIR}/Android/arm64-v8a"
    mkdir -p "${VERSION_DIR}/Android/armeabi-v7a"

    if [ -n "$DEMO_ANDROID" ]; then
        mkdir -p "${DEMO_ANDROID}/arm64-v8a"
        mkdir -p "${DEMO_ANDROID}/armeabi-v7a"
    fi
    if [ -n "$DEMO_QT" ]; then
        mkdir -p "${DEMO_QT}/arm"
        mkdir -p "${DEMO_QT}/x64"
    fi
    if [ -n "$DEMO_WIN" ]; then
        mkdir -p "${DEMO_WIN}/shared/libx64"
        mkdir -p "${DEMO_WIN}/shared/libx86"
        mkdir -p "${DEMO_WIN}/static/libx64"
        mkdir -p "${DEMO_WIN}/static/libx86"
    fi

    echo "Parsed SDK Version: ${VERSION}"
    echo "Output root: ${VERSION_DIR}"
}

build_platform_linux()
{
    local PLATFORM="$1"
    local C_COMPILER="$2"
    local CXX_COMPILER="$3"
    local OUT_PLATFORM_DIR="$4"
    local EXPECTED_ARCH="$5"
    CURRENT_BUILD="${PLATFORM}"
    echo
    echo "============================================================"
    echo "${PLATFORM}"
    echo "============================================================"

    export CCACHE_DIR="${BUILD_ROOT}/.ccache/${PLATFORM}"
    mkdir -p "${CCACHE_DIR}"
    export CCACHE_MAXSIZE=10G
    ccache --set-config=max_size="${CCACHE_MAXSIZE}"

    local TYPE STATIC LIB_NAME BUILD_DIR OUTPUT_DIR LIB_PATH
    for TYPE in "${BUILD_TYPES[@]}"; do
        if [ "${TYPE}" = "static" ]; then
            STATIC=ON
            LIB_NAME="lib${LIB_BASE_NAME}.a"
        else
            STATIC=OFF
            LIB_NAME="lib${LIB_BASE_NAME}.so"
        fi
        BUILD_DIR="${HOME}/build_tmp/${PLATFORM}/${TYPE}/cmake-build"
        OUTPUT_DIR="${VERSION_DIR}/Linux/${OUT_PLATFORM_DIR}"
        rm -rf "${BUILD_DIR}"
        mkdir -p "${BUILD_DIR}"
        echo "Build dir: ${BUILD_DIR}"
        echo "Output dir: ${OUTPUT_DIR}"

        local CMAKE_ARGS=(
            -S "${SRC_DIR}"
            -B "${BUILD_DIR}"
            -G Ninja
            -DCMAKE_BUILD_TYPE=Release
            -DBUILD_STATIC_LIBS="${STATIC}"
            -DCMAKE_C_COMPILER="${C_COMPILER}"
            -DCMAKE_CXX_COMPILER="${CXX_COMPILER}"
            -DCMAKE_C_COMPILER_LAUNCHER=ccache
            -DCMAKE_CXX_COMPILER_LAUNCHER=ccache
            -DTHIRD_PARTY_DIR="${THIRD_PARTY_DIR}"
        )
        if [ "${OUT_PLATFORM_DIR}" = "arm" ]; then
            CMAKE_ARGS+=( -DCMAKE_TOOLCHAIN_FILE="${AARCH64_TOOLCHAIN_FILE}" )
        fi
        cmake "${CMAKE_ARGS[@]}"
        cmake --build "${BUILD_DIR}" --parallel "${BUILD_JOBS}"

        LIB_PATH=$(find "${BUILD_DIR}" -type f -name "${LIB_NAME}" -print -quit)
        if [ -z "${LIB_PATH}" ]; then
            echo "[ERROR] ${LIB_NAME} not found in build dir"
            exit 1
        fi
        cp -f "${LIB_PATH}" "${OUTPUT_DIR}/${LIB_NAME}"
        check_library_arch "${OUTPUT_DIR}/${LIB_NAME}" "${EXPECTED_ARCH}"
        echo "[SUCCESS] ${OUTPUT_DIR}/${LIB_NAME}"
    done
    ccache -s
}

build_linux_arm64()
{
    echo "===== Build Linux ARM64 ====="
    build_platform_linux "Linux-ARM64" "${AARCH64_GCC}" "${AARCH64_GXX}" "arm" "arm64"
}

build_linux_x64()
{
    echo "===== Build Linux x64 ====="
    build_platform_linux "Linux-x64" "${LOCAL_GCC}" "${LOCAL_GXX}" "x64" "x86_64"
}

main()
{
    echo "Checking environment..."
    if [ ! -d "${SRC_DIR}" ];then echo "[ERROR] Source dir not found ${SRC_DIR}"; exit 1; fi
    if [ ! -f "${SRC_DIR}/CMakeLists.txt" ];then echo "[ERROR] CMakeLists.txt missing"; exit 1; fi
    if [ ! -d "${THIRD_PARTY_DIR}" ];then echo "[ERROR] 3rd dir missing ${THIRD_PARTY_DIR}"; exit 1; fi

    check_command cmake
    check_command ninja
    check_command ccache
    check_command file
    check_command ar
    check_command readelf

    if [ ! -x "${AARCH64_GCC}" ] || [ ! -x "${AARCH64_GXX}" ]; then echo "[ERROR] AArch64 cross compiler missing"; exit 1; fi
    if [ ! -f "${AARCH64_TOOLCHAIN_FILE}" ];then echo "[ERROR] aarch64-gcc9.3.cmake missing"; exit 1; fi
    if [ ! -x "${LOCAL_GCC}" ] || [ ! -x "${LOCAL_GXX}" ]; then echo "[ERROR] local gcc-9.3 missing"; exit 1; fi

    read_version

    echo "============================================================"
    echo "Start building all targets"
    echo "Version: ${VERSION}"
    echo "Build output: ${VERSION_DIR}"
    echo "Build types: ${BUILD_TYPES[*]}"
    if [ "${BUILD_STATIC}" != "true" ]; then
        echo "[INFO] Static libraries disabled (--build-static false), building shared only."
    fi
    echo "============================================================"

    BUILD_START=$(date +%s)
    build_linux_arm64
    build_linux_x64
    BUILD_END=$(date +%s)
    DURATION=$((BUILD_END - BUILD_START))

    echo
    echo "============================================================"
    echo "BUILD FINISHED"
    echo "Version: ${VERSION}"
    echo "Output root: ${VERSION_DIR}"
    echo "Total seconds: ${DURATION}"
    echo "============================================================"
}

main "$@"
