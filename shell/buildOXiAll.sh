#!/bin/bash
set -Eeuo pipefail

# 公共路径配置（真源：仓库根 paths.json）—— 提供 LOCAL_GCC_ROOT / AARCH64_GCC_ROOT /
# WSL_CMAKE / WSL_NINJA / ANDROID_PLATFORM 等，别在本脚本里再写死 /opt/... 路径。
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env_paths.sh"

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
    echo "  --linux-only          (Optional) Flag to indicate linux-only build"
    echo "  --build-static BOOL   (Optional) Build static libraries: true|false (default: true)"
    exit 1
}

# Default values
SRC_DIR=""
BUILD_ROOT=""
THIRD_PARTY_DIR=""
LIB_BASE_NAME="FAP"
BUILD_STATIC="true"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --src-dir) SRC_DIR="$2"; shift 2 ;;
        --build-root) BUILD_ROOT="$2"; shift 2 ;;
        --third-party) THIRD_PARTY_DIR="$2"; shift 2 ;;
        --lib-name) LIB_BASE_NAME="$2"; shift 2 ;;
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

# Compiler Roots —— 来自 shell/env_paths.sh（真源仓库根 paths.json 的 wsl 段）
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

# 判断某个 configure preset 在当前环境能不能用。
# 拿 `cmake --list-presets` 当探针：它不需要工具链就能跑通，能读通说明源目录的
# CMakePresets.json（含 include 到仓库根的 cmake-presets/sdk-presets.json 的引用链）
# 有效；而且 CMake 会按当前平台过滤掉生成器不可用的 preset（Linux 下列不出 VS2019 那些），
# 所以命中即代表本机真的能用它构建。任一环节不满足就返回非 0，调用方回退手工参数。
# 构建配置的真源只有一份：仓库根的 cmake-presets/sdk-presets.json。
preset_available()
{
    local src="$1"
    local name="$2"
    if [ ! -f "${src}/CMakePresets.json" ] && [ ! -f "${src}/CMakeUserPresets.json" ]; then
        return 1
    fi
    local list
    list="$(cmake --list-presets -S "${src}" 2>/dev/null)" || return 1
    case "${list}" in
        *"\"${name}\""*) return 0 ;;
        *) return 1 ;;
    esac
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

    mkdir -p "${VERSION_DIR}/Linux/aarch64"
    mkdir -p "${VERSION_DIR}/Linux/x64"
    mkdir -p "${VERSION_DIR}/Windows/x64/static"
    mkdir -p "${VERSION_DIR}/Windows/x64/shared"
    mkdir -p "${VERSION_DIR}/Windows/x86/static"
    mkdir -p "${VERSION_DIR}/Windows/x86/shared"
    mkdir -p "${VERSION_DIR}/Android/arm64-v8a"
    mkdir -p "${VERSION_DIR}/Android/armeabi-v7a"

    # 本脚本只负责把产物落到 ${VERSION_DIR}（= --build-root）。
    # Demo 工程目录（simpleWin / simpleAndroid / *_qt 下的库目录）由打包侧
    # （ps/OXi.ps1、py/OXi.py）在真正复制时按需创建——各 SDK 的目录约定并不统一
    # （A910_qt 是 Linux/{aarch64,x64}，oxiscansdk_qt 是 {arm,x64}），
    # 在这里硬编码 mkdir 只会往源码树里塞空目录。

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
        BUILD_DIR="$(dirname "$SRC_DIR")/build_temp/linux/${PLATFORM}/${TYPE}/cmake-build"
        OUTPUT_DIR="${VERSION_DIR}/Linux/${OUT_PLATFORM_DIR}"
        rm -rf "${BUILD_DIR}"
        mkdir -p "${BUILD_DIR}"
        echo "Build dir: ${BUILD_DIR}"
        echo "Output dir: ${OUTPUT_DIR}"

        # 生成器/编译器/ccache/静态开关交给 preset（真源仓库根的 cmake-presets/sdk-presets.json，
        # 源目录里只有一个 include 它的 CMakePresets.json）。-B 仍由本脚本指定，
        # 因为 --preset 之外的 -B 会覆盖 preset 的 binaryDir。
        local PRESET="linux-${OUT_PLATFORM_DIR}-${TYPE}"
        local CMAKE_ARGS
        if preset_available "${SRC_DIR}" "${PRESET}"; then
            echo "[preset] ${PRESET}  (生成器/编译器/ccache 由 preset 提供，build 目录仍由脚本指定)"
            CMAKE_ARGS=(
                --preset "${PRESET}"
                -S "${SRC_DIR}"
                -B "${BUILD_DIR}"
                -DTHIRD_PARTY_DIR="${THIRD_PARTY_DIR}"
            )
        else
            echo "[WARN] preset ${PRESET} 不可用，回退到手工参数（源目录没有有效的 CMakePresets.json）"
            CMAKE_ARGS=(
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
            if [ "${OUT_PLATFORM_DIR}" = "aarch64" ]; then
                CMAKE_ARGS+=( -DCMAKE_TOOLCHAIN_FILE="${AARCH64_TOOLCHAIN_FILE}" )
            fi
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
    build_platform_linux "Linux-ARM64" "${AARCH64_GCC}" "${AARCH64_GXX}" "aarch64" "arm64"
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
