import os
import struct
import subprocess
from pathlib import Path
from fastmcp import FastMCP

# 初始化MCP服务
mcp = FastMCP("dev‑tool‑server")


def run_cmd(cmd: list[str]) -> str:
    try:
        res = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=8
        )
        out = res.stdout.strip() or res.stderr.strip()
        if res.returncode == 0:
            return f"✅ 已安装\n{out}"
        else:
            return "❌ 未找到该程序"
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return "❌ 未找到该程序"


@mcp.tool()
async def check_env_all() -> str:
    """一键检查编译环境：cmake、git、ninja、python、adb"""
    info = []
    info.append("==== CMake ====")
    info.append(run_cmd(["cmake", "--version"]))
    info.append("\n==== Git ====")
    info.append(run_cmd(["git", "--version"]))
    info.append("\n==== Ninja ====")
    info.append(run_cmd(["ninja", "--version"]))
    info.append("\n==== Python ====")
    info.append(run_cmd(["python", "--version"]))
    info.append("\n==== ADB ====")
    info.append(run_cmd(["adb", "version"]))
    return "\n".join(info)


@mcp.tool()
async def check_cmake() -> str:
    """查看CMake版本"""
    return run_cmd(["cmake", "--version"])


@mcp.tool()
async def find_ndk_path() -> str:
    """自动扫描系统环境变量，查找Android‑NDK路径、校验工具链、读取版本"""
    ndk_root = None
    info_lines = []
    env1 = os.environ.get("ANDROID_NDK_ROOT")
    env2 = os.environ.get("ANDROID_NDK_HOME")
    sdk_root = os.environ.get("ANDROID_HOME") or os.environ.get("ANDROID_SDK_ROOT")

    if env1 and Path(env1).exists():
        ndk_root = Path(env1)
        info_lines.append(f"✅ ANDROID_NDK_ROOT：{ndk_root}")
    elif env2 and Path(env2).exists():
        ndk_root = Path(env2)
        info_lines.append(f"✅ ANDROID_NDK_HOME：{ndk_root}")
    elif sdk_root:
        ndk_parent = Path(sdk_root) / "ndk"
        if ndk_parent.exists():
            subdirs = sorted([x for x in ndk_parent.iterdir() if x.is_dir()], reverse=True)
            if subdirs:
                ndk_root = subdirs[0]
                info_lines.append(f"✅ 自动识别NDK：{ndk_root}")

    if not ndk_root:
        info_lines.append("❌ 未检测到Android‑NDK")
        return "\n".join(info_lines)

    toolchain = ndk_root / "build" / "cmake" / "android.toolchain.cmake"
    info_lines.append("✅ 工具链文件正常" if toolchain.exists() else "❌ 缺失android.toolchain.cmake")
    release_file = ndk_root / "source.properties"
    if release_file.exists():
        info_lines.append("\n" + release_file.read_text(encoding="utf‑8", errors="ignore"))
    return "\n".join(info_lines)


@mcp.tool()
async def check_so_page_align(so_file: str, page_size: int = 16384) -> str:
    """
    校验Android so库ELF页对齐
    :param so_file: so文件完整路径
    :param page_size: 对齐字节，4096 / 16384
    """
    path = Path(so_file)
    if not path.exists():
        return f"文件不存在 {so_file}"
    with open(path, "rb") as f:
        f.seek(28)
        ph_offset = struct.unpack("<Q", f.read(8))[0]
        f.seek(ph_offset + 8)
        align = struct.unpack("<Q", f.read(8))[0]
    if align >= page_size:
        return f"对齐通过:{align} byte，满足{page_size}字节对齐"
    else:
        return f"对齐失败:{align} byte，需要≥{page_size}字节对齐"


if __name__ == "__main__":
    mcp.run()