# encoding:utf-8
"""
路径一致性检查 / 同步工具 —— 守住「paths.json 是唯一真源」这条约定。

背景：script 仓库里 cmake / ninja / NDK / 交叉编译器这些路径原来散落在
ps、py、shell、bat 四端的十来个脚本里，版本还漂过（NDK 25.2 / 26.3 / 28.2 各写一份）。
现在统一收敛到仓库根 paths.json，本工具负责防止它再退化：

  1) 扫描四端脚本，报告残留的机器相关绝对路径（D:/apps/...、/opt/gcc-9.3.0、/mnt/d/... 等）
  2) 校验 cmake-presets/sdk-presets.json 里的机器相关路径与 paths.json 一致
     （preset 要能被 CLion 独立使用，所以不能改成 $env{} 宏，只能靠本工具同步）
  3) 校验 paths.json 仍符合 shell 端简易解析（sed/grep）所要求的格式

用法：
    python py/checkPaths.py              # 只检查，有问题退出码 1
    python py/checkPaths.py --write      # 把 paths.json 的值回写到 preset
    python py/checkPaths.py --quiet      # 只输出结论

给某一行加白名单（确实需要写死的地方）：
    $x = "D:/apps/..."   # paths-ok: 说明为什么这里必须写死
"""
import argparse
import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
PATHS_FILE = REPO / "paths.json"
PRESET_FILE = REPO / "cmake-presets" / "sdk-presets.json"

# 扫描范围：四端脚本目录
SCAN_DIRS = ["ps", "py", "shell", "bat"]
SCAN_SUFFIXES = {".ps1", ".py", ".sh", ".bat"}
# 读取器自身要引用字段名和做派生拼接，但不应出现完整绝对路径；如出现仍需报告，故不整体跳过。
# 本工具含用于匹配的模式串，必须跳过。
SKIP_FILES = {"py/checkPaths.py"}

# 机器相关绝对路径的特征
PATTERNS = [
    (r"[A-Za-z]:[\\/]+apps[\\/]", "Windows 工具绝对路径（应写进 paths.json）"),
    (r"[A-Za-z]:[\\/]+git[\\/]+script(?![A-Za-z])", "仓库自身的 Windows 绝对路径（应用 $PSScriptRoot / REPO）"),
    (r"/opt/(?:gcc-9\.3\.0|aarch64-gcc9\.3)", "WSL 编译器根（应在 paths.json 的 wsl 段）"),
    (r"/mnt/[a-z]/[^\s\"'`)]*git/script", "仓库自身的 WSL 绝对路径（应用 SCRIPT_REPO_WSL）"),
    (r"ndk[\\/]\d+\.\d+\.\d+", "NDK 具体版本路径（应由 paths.json 的 android_ndk 派生）"),
    (r"CLion\s*[\d.]+", "CLion 安装路径（应在 paths.json 的 ninja 里）"),
]
WHITELIST_MARK = "paths-ok"


def load_paths():
    with open(PATHS_FILE, encoding="utf-8") as f:
        return json.load(f)


# ---------------------------------------------------------------
# 1. 脚本里的残留硬编码
# ---------------------------------------------------------------
def scan_hardcoded():
    hits = []
    for d in SCAN_DIRS:
        for path in sorted((REPO / d).rglob("*")):
            if not path.is_file() or path.suffix not in SCAN_SUFFIXES:
                continue
            rel = path.relative_to(REPO).as_posix()
            if rel in SKIP_FILES:
                continue
            try:
                text = path.read_text(encoding="utf-8")
            except UnicodeDecodeError:
                # 非 UTF-8（例如历史遗留的 GBK 脚本）：按字节粗查 ASCII 特征
                text = path.read_bytes().decode("latin-1")
            for lineno, line in enumerate(text.splitlines(), 1):
                if WHITELIST_MARK in line:
                    continue
                for pattern, why in PATTERNS:
                    m = re.search(pattern, line)
                    if m:
                        hits.append((rel, lineno, m.group(0), why, line.strip()))
                        break
    return hits


# ---------------------------------------------------------------
# 2. preset 与 paths.json 的一致性
# ---------------------------------------------------------------
def expectations(cfg):
    win = cfg["windows"]
    wsl = cfg["wsl"]
    android = cfg["android"]
    ndk = win["android_ndk"]
    gcc_x64 = wsl["gcc_x64_root"]
    gcc_arm = wsl["gcc_aarch64_root"]
    return [
        ("android-common", "cacheVariables", "CMAKE_MAKE_PROGRAM", win["ninja"]),
        ("android-common", "cacheVariables", "CMAKE_TOOLCHAIN_FILE",
         "%s/build/cmake/android.toolchain.cmake" % ndk),
        ("android-common", "cacheVariables", "ANDROID_PLATFORM", android["platform"]),
        ("linux-common", "cacheVariables", "CMAKE_C_COMPILER", "%s/bin/gcc" % gcc_x64),
        ("linux-common", "cacheVariables", "CMAKE_CXX_COMPILER", "%s/bin/g++" % gcc_x64),
        ("linux-aarch64-common", None, "toolchainFile", "%s/cmake/aarch64-gcc9.3.cmake" % gcc_arm),
        ("linux-aarch64-common", "cacheVariables", "CMAKE_C_COMPILER",
         "%s/bin/aarch64-linux-gnu-gcc" % gcc_arm),
        ("linux-aarch64-common", "cacheVariables", "CMAKE_CXX_COMPILER",
         "%s/bin/aarch64-linux-gnu-g++" % gcc_arm),
    ]


def preset_container(preset, where):
    return preset["cacheVariables"] if where else preset


def check_preset(cfg, write=False):
    with open(PRESET_FILE, encoding="utf-8") as f:
        data = json.load(f)
    presets = {p["name"]: p for p in data.get("configurePresets", [])}
    diffs = []
    for preset_name, where, key, want in expectations(cfg):
        preset = presets.get(preset_name)
        if preset is None:
            diffs.append((preset_name, key, "<preset 缺失>", want))
            continue
        container = preset_container(preset, where)
        have = container.get(key)
        if have != want:
            diffs.append((preset_name, key, have, want))
            if write:
                container[key] = want
    if write and diffs:
        text = json.dumps(data, indent=2, ensure_ascii=False) + "\n"
        PRESET_FILE.write_text(text, encoding="utf-8", newline="\n")
    return diffs


# ---------------------------------------------------------------
# 3. paths.json 的格式约束（shell 端 sed/grep 解析要求）
# ---------------------------------------------------------------
def check_paths_format(cfg):
    problems = []
    for section, value in cfg.items():
        if section.startswith("_"):
            continue
        if not isinstance(value, dict):
            problems.append("顶层段 %r 必须是对象（shell 端靠缩进定位）" % section)
            continue
        for key, val in value.items():
            if not isinstance(val, str):
                problems.append("%s.%s 的值必须是字符串（当前 %s），"
                                "shell/env_paths.sh 用 sed 取值，无法解析多行/数字" % (section, key, type(val).__name__))
    return problems


def main():
    ap = argparse.ArgumentParser(description="paths.json 唯一真源一致性检查")
    ap.add_argument("--write", action="store_true", help="把 paths.json 的值回写到 cmake-presets/sdk-presets.json")
    ap.add_argument("--quiet", action="store_true", help="只输出结论")
    args = ap.parse_args()

    cfg = load_paths()
    failed = False

    hits = scan_hardcoded()
    if hits:
        failed = True
        print("[FAIL] 脚本里仍有机器相关绝对路径（%d 处）：" % len(hits))
        for rel, lineno, text, why, line in hits:
            print("  %s:%d  %s\n      %s\n      %s" % (rel, lineno, text, why, line))
            if not args.quiet:
                print()
    else:
        print("[OK] 四端脚本里没有残留的机器相关绝对路径")

    diffs = check_preset(cfg, write=args.write)
    if diffs:
        if args.write:
            print("[FIXED] 已把 %d 处 preset 路径同步为 paths.json 的值：" % len(diffs))
            for preset_name, key, have, want in diffs:
                print("  %s.%s: %s -> %s" % (preset_name, key, have, want))
        else:
            failed = True
            print("[FAIL] preset 与 paths.json 不一致（%d 处，可用 --write 同步）：" % len(diffs))
            for preset_name, key, have, want in diffs:
                print("  %s.%s" % (preset_name, key))
                print("       preset    : %s" % have)
                print("       paths.json: %s" % want)
    else:
        print("[OK] cmake-presets/sdk-presets.json 与 paths.json 一致")

    problems = check_paths_format(cfg)
    if problems:
        failed = True
        print("[FAIL] paths.json 格式不符合 shell 端解析约定：")
        for p in problems:
            print("  - %s" % p)
    else:
        print("[OK] paths.json 格式可被 shell 端 sed/grep 解析")

    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
