#!/usr/bin/python
# encoding:utf-8
import os
import re
import shutil

from utils.fileUtils import copy_files_by_suffix, remove_dir, safe_mkdir


# ------------------------------------------------------------
# 目录名约定（与 ps 一致，不要随意加版本后缀）：
#   Windows exe/dll : win_X86Demo / win_X64Demo
#   Windows 源码    : simpleWin
#   Android 源码    : simpleAndroid
#   Qt Linux 源码   : simpleLinux
# ------------------------------------------------------------


# ------------------------------------------------------------
# 库源目录解析（构建产物布局有多种形态）
#   ① CLion / 手工 cmake ：<SdkDir>\cmake-build-release-vs2019_<arch>\Release\FAP.dll
#                          <SdkDir>\cmake-build-release-<abi>\libFAP.so
#   ② 早期工程           ：<build>\libFAP\Release\FAP.dll（libFAP 还是子目录时的位置）
#   ③ 一键构建脚本       ：<SdkParent>\build_temp\win\win_<arch>_<OFF|ON>\Release\FAP.dll
#                          <SdkParent>\build_temp\android\android_<abi>_<OFF|ON>\libFAP.so
#   判定标准是"目录里真的存在主库文件"，避免选中空目录后误报"已拷贝"。
#   对应 ps/copyUtils.ps1 的 Get-LibBuildDirs / Resolve-LibSourceDir / Find-LibSource。
# ------------------------------------------------------------
def get_lib_build_dirs(sdk_dir: str, kind: str, arch: str):
    """
    给出该架构"可能存在的构建目录"列表（按优先级）。

    构建入口不同 → 产物落点不同，只认 cmake-build-* 会让"一键构建后自动打包"
    整条链路拿不到库（buildOXiAll.ps1 走的是 build_temp\\...）。
    """
    parent = os.path.dirname(sdk_dir.rstrip("\\/"))
    if kind == "win":
        # 顺序即优先级：一键构建脚本的 build_temp（BuildWin 刚落下的**整组**：主库 + FAPAlgo +
        # opencv/onnx，同批构建、内容一定自洽）→ IDE 的 cmake-build-release-vs2019_<arch>。
        # 反过来（IDE 优先）会让 SDK 源仓里开发者随手编的目录胜出，而那份目录经常只有主库
        # 被刷新过，FAPAlgo / opencv 还是几个月前的旧货（2026-10-23 旧 FAPAlgo.dll 回灌）。
        return [
            os.path.join(parent, "build_temp", "win", f"win_{arch}_OFF"),
            os.path.join(parent, "build_temp", "win", f"win_{arch}_ON"),
            os.path.join(sdk_dir, f"cmake-build-release-vs2019_{arch}"),
        ]
    # 官方构建输出 <sdk父>/build/<prefix><version>/Android/<abi>：BuildAndroid.ps1 把主库 +
    # 算法库整组落在那里，是"这次发布"最该用的源；IDE 的 cmake-build-* 常常是旧产物或未 strip
    # 的调试版。目录名带版本号，用通配按新到旧展开，不依赖调用方传 version。
    official = []
    build_root = os.path.join(parent, "build")
    if os.path.isdir(build_root):
        dirs = []
        for name in os.listdir(build_root):
            full = os.path.join(build_root, name)
            if os.path.isdir(full):
                try:
                    dirs.append((os.path.getmtime(full), full))
                except OSError:
                    pass
        for _, full in sorted(dirs, reverse=True):
            cand = os.path.join(full, "Android", arch)
            if os.path.isdir(cand):
                official.append(cand)
    # 顺序即优先级：官方输出 → 一键构建脚本的 build_temp → IDE 的 cmake-build。
    # IDE 目录排在最后，是因为它是开发者本地随手构建的，可能没 strip、也可能比发布版本旧。
    return official + [
        os.path.join(parent, "build_temp", "android", f"android_{arch}_OFF"),
        os.path.join(parent, "build_temp", "android", f"android_{arch}_ON"),
        os.path.join(sdk_dir, f"cmake-build-release-{arch}"),
    ]


def resolve_lib_source_dir(build_dir: str, sub_dirs, must_contain: str = None):
    """
    按优先级在 build_dir 下挑出真的含有 must_contain 的那个子目录。

    sub_dirs 里的空串表示"构建目录顶层"（Android 的 .so 就落在 <build>\\ 下）——
    对应 ps 侧 [AllowEmptyString()] 那个分支。
    返回命中的目录字符串；都不命中时返回 None。
    """
    for sub in sub_dirs:
        d = build_dir if not sub else os.path.join(build_dir, sub)
        if not os.path.isdir(d):
            continue
        if must_contain and not os.path.isfile(os.path.join(d, must_contain)):
            continue
        return d
    return None


def find_lib_source(sdk_dir: str, kind: str, arch: str, sub_dirs, must_contain: str = None):
    """
    在 get_lib_build_dirs 给出的所有构建目录里找真正含主库的那一个。

    must_contain 不传时改为"目录里至少有一个 .dll/.so"。
    返回 (库所在目录, 命中的构建目录) 元组；都没命中返回 (None, None)。
    （依赖解析 get_android_runtime_deps 要用构建目录，不能用库目录）
    """
    suffix = ".dll" if kind == "win" else ".so"
    # 顺序优先：get_lib_build_dirs 已经把"官方构建输出"排在 IDE 的 cmake-build-* 之前，
    # 不能按 mtime 择优 —— 官方目录里的库是拷过来的，mtime 还留着构建时间，会输给
    # 开发者后来随手用 IDE 编的那一份（未 strip、体积翻倍）。
    for bd in get_lib_build_dirs(sdk_dir, kind, arch):
        src = resolve_lib_source_dir(bd, sub_dirs, must_contain)
        if not src:
            continue
        if not must_contain:
            # 没指定主库名时，用一个"真含动态库"的判定，避免选中空目录后误报已拷贝
            if not any(n.lower().endswith(suffix) for n in os.listdir(src)):
                continue
        return src, bd
    return None, None


def get_static_build_dirs(sdk_dir: str, kind: str, arch: str):
    """
    给出"静态产物优先"的构建目录列表（.lib / .a）。

    静态库只在 BUILD_STATIC_LIBS=ON 那一次构建里产出（win_<arch>_ON / android_<abi>_ON）。
    get_lib_build_dirs 的默认顺序是"官方 → OFF → ON"，直接拿它找 .lib/.a 会命中 OFF 那套
    （那里的 FAP.lib 只是 12 KB 的导入库，不是 16 MB 的静态库）或 IDE 的旧产物。
    这里把 *_ON 提到最前，其余按原顺序兜底。对应 ps 的 Get-StaticBuildDirs。
    """
    all_dirs = list(get_lib_build_dirs(sdk_dir, kind, arch))
    pref = [d for d in all_dirs if d.rstrip("\\/").lower().endswith("_on")]
    return pref + [d for d in all_dirs if d not in pref]


def find_static_lib_source(sdk_dir: str, kind: str, arch: str, file_name: str, sub_dirs):
    """
    找真正含静态库（FAP.lib / libFAP.a）的那个构建目录。

    file_name 与动态库同名时靠它区分形态（.lib / .a 后缀）。
    返回 (库所在目录, 命中的构建目录) 元组；都没命中返回 (None, None)。
    对应 ps 的 Find-StaticLibSource。
    """
    for bd in get_static_build_dirs(sdk_dir, kind, arch):
        src = resolve_lib_source_dir(bd, sub_dirs, file_name)
        if src:
            return src, bd
    return None, None


def copy_lib_files(src_dir: str, dst_dir: str, kind: str, extra_files=()) -> int:
    """
    把一组动态库整批拷进目标目录（算法库 + 运行时依赖与主库同目录部署）。

    FAP 运行期由 OXiAlgoLoader 从"自身所在目录"加载 FAPAlgo，FAPAlgo 又依赖 opencv /
    onnxruntime（Android 还要 libusb / libuvc）—— 少任何一个，客户机上就跑不起来，
    所以整组一起走：目录里的全部 .dll/.so 一把拷，不按名字挑。
    对应 ps/copyUtils.ps1 的 Copy-LibFiles。

    :param kind        "dll"（Windows）或 "so"（Android/Linux）
    :param extra_files 目录外解析出来的依赖绝对路径（如 Android 从链接行取到的 .so）
    :return 实际拷贝的文件数
    """
    safe_mkdir(dst_dir)
    suffix = "." + kind
    copied = 0

    # 1) 库目录里的全部动态库（主库 + 算法库 + opencv + onnx + usb/uvc）
    if os.path.isdir(src_dir):
        for name in sorted(os.listdir(src_dir)):
            src = os.path.join(src_dir, name)
            if not os.path.isfile(src) or not name.lower().endswith(suffix):
                continue
            shutil.copy2(src, dst_dir)
            copied += 1

    # 2) 目录外的依赖（同名文件已在上一步拷过则跳过：目录里的版本才是这次构建真正产出的）
    for f in extra_files or ():
        if not f or not str(f).strip():
            continue
        if not os.path.isfile(f):
            print(f"[缺失] 运行时依赖不存在: {f}")
            continue
        leaf = os.path.basename(f)
        if os.path.exists(os.path.join(dst_dir, leaf)):
            continue
        shutil.copy2(f, dst_dir)
        copied += 1

    return copied


def resolve_dep_build_dir(sdk_dir: str, kind: str, arch: str, preferred: str = None):
    """
    给出"能解析链接期依赖"的构建目录（必须带 build.ninja 或 FAPAlgo 的 link.txt）。

    get_lib_build_dirs 的第一位是官方输出目录 <sdk父>/build/<ver>/Android/<abi>，
    那里只有库、没有构建元数据 —— 拿它去解析 opencv / onnxruntime 会一无所获
    （表现为包里少 libopencv_java4.so / libonnxruntime.so）。
    优先用 preferred（若它带元数据），否则在候选里挑第一个带元数据的。
    """

    def has_meta(d):
        if not d:
            return False
        return os.path.isfile(os.path.join(d, "build.ninja")) or os.path.isfile(
            os.path.join(d, "CMakeFiles", "FAPAlgo.dir", "link.txt")
        )

    if has_meta(preferred):
        return preferred
    for bd in get_lib_build_dirs(sdk_dir, kind, arch):
        if has_meta(bd):
            return bd
    return preferred


def get_android_runtime_deps(build_dir: str):
    """
    从构建目录的链接行里解析 FAPAlgo 依赖的绝对路径 .so（opencv / onnxruntime）。

    Android 的算法库以动态方式依赖 libopencv_java4.so / libonnxruntime.so，而构建目录里
    只有 FAP/FAPAlgo 自身，运行时依赖散落在 THIRD_PARTY_DIR。版本（OpenCV4.6 /
    onnxruntime-1.12.1 …）只有链接行知道，所以这里直接读链接命令：
      ninja : <build>\\build.ninja 里 `build libFAPAlgo.so …` 那条
      make  : <build>\\CMakeFiles\\FAPAlgo.dir\\link.txt
    对应 ps/copyUtils.ps1 的 Get-AndroidRuntimeDeps。

    返回绝对路径列表；解析不出来时为空（调用方会打 [缺失] 提示）。
    """
    if not build_dir:
        return []
    ninja = os.path.join(build_dir, "build.ninja")
    link_txt = os.path.join(build_dir, "CMakeFiles", "FAPAlgo.dir", "link.txt")
    text = None
    for p in (ninja, link_txt):
        if os.path.isfile(p):
            try:
                with open(p, "r", encoding="utf-8", errors="replace") as f:
                    text = f.read()
            except OSError:
                text = None
            if text:
                break
    if not text:
        return []

    out = []
    # 盘符在 ninja 里写作 D$:（冒号要转义），别的生成器写 D: —— 两种都要认，
    # 只写 [A-Za-z]: 会漏掉 ninja 的全部绝对路径（依赖就全丢了）。
    for m in re.finditer(r"[A-Za-z]\$?:[/\\][^ \"'\r\n]+\.so", text):
        p = m.group(0).replace("$:", ":")   # ninja 的 D$: -> D:
        leaf = os.path.basename(p)
        # 自身产物与 demo 侧的 usb/uvc（另有来源）不需要从链接行带
        if leaf.startswith("libFAP") or leaf.startswith("libusb") or leaf.startswith("libuvc"):
            continue
        if p not in out:
            out.append(p)
    return out


# ------------------------------------------------------------
# Linux 库目录（各 SDK 的 *_qt 工程约定并不统一，三套都要认）
#   A910_qt       : simpleLinux\arm | x64              （架构目录直接在 simpleLinux 下）
#   部分工程       : simpleLinux\linux\aarch64 | x64
#   oxiscansdk_qt : simpleLinux\shared\Linux\aarch64 | X64（注意 X64 大写）
# 判定方式 = 目录真实存在 + 子目录名能归一化成 aarch64 / x64 / arm
# ------------------------------------------------------------
_LINUX_ARCH_RE = (
    ("aarch64", re.compile(r"^(aarch64|arm64)$", re.I)),
    ("x64", re.compile(r"^(x64|x86_64)$", re.I)),
    ("arm", re.compile(r"^arm$", re.I)),
)


def get_linux_arch_dirs(root: str):
    """
    在 simpleLinux（或 *_qt 源码树）下探测 {架构: 库目录}。

    对应 ps/copyUtils.ps1 的 Get-LinuxArchDirs；探测不到返回空 dict。
    """
    result = {}
    if not os.path.isdir(root):
        return result
    for sub in ("", "linux", os.path.join("shared", "Linux"),
                os.path.join("shared", "linux"), "Linux"):
        parent = os.path.join(root, sub) if sub else root
        if not os.path.isdir(parent):
            continue
        for name in sorted(os.listdir(parent)):
            d = os.path.join(parent, name)
            if not os.path.isdir(d):
                continue
            for key, pat in _LINUX_ARCH_RE:
                if pat.match(name):
                    result.setdefault(key, d)
                    break
    return result


def get_linux_build_dirs(sdk_dir: str, version: str, arch: str, prefix: str = ""):
    """
    给出某架构 Linux 构建产物的候选目录（按优先级）。

    ① shell/buildOXiAll.sh 的官方落点：<Sdk父>\\build\\<prefix+version>\\Linux\\<arch>
    ② WSL 原始构建目录兜底：<Sdk父>\\build_temp\\linux\\<Platform>\\<shared|static>\\cmake-build
    对应 ps/copyUtils.ps1 的 Get-LinuxBuildDirs。
    """
    parent = os.path.dirname(os.path.abspath(sdk_dir.rstrip("/\\")))
    out = []

    ver_dir_name = (prefix + version) if prefix else version
    linux_root = os.path.join(parent, "build", ver_dir_name, "Linux")
    if os.path.isdir(linux_root):
        for name in sorted(os.listdir(linux_root)):
            d = os.path.join(linux_root, name)
            if not os.path.isdir(d):
                continue
            low = name.lower()
            match = (low == arch.lower()
                     or (arch == "aarch64" and low in ("arm", "arm64"))
                     or (arch == "x64" and low == "x86_64"))
            if match:
                out.append(d)

    platform = "Linux-x64" if arch == "x64" else "Linux-ARM64"
    for build_type in ("shared", "static"):
        out.append(os.path.join(parent, "build_temp", "linux",
                                platform, build_type, "cmake-build"))
    return out


def copy_linux_lib_files(src_dir: str, dst_dir: str) -> int:
    """
    把 Linux 构建目录里的整组动态库（主库 + *Algo* + onnx/opencv）拷进目标目录。

    WSL 下建的 .so 多为符号链接（libonnxruntime.so → libonnxruntime.so.1），
    必须逐文件 copy2（跟随链接取真实内容），不能整目录 copytree。
    对应 ps/copyUtils.ps1 的 Copy-LinuxLibFiles。
    """
    if not os.path.isdir(src_dir):
        return 0
    os.makedirs(dst_dir, exist_ok=True)
    copied = 0
    for name in sorted(os.listdir(src_dir)):
        src = os.path.join(src_dir, name)
        if not os.path.isfile(src) or not re.search(r"\.so(\.\d+)*$", name):
            continue
        try:
            shutil.copy2(src, os.path.join(dst_dir, name), follow_symlinks=True)
            copied += 1
        except OSError as exc:
            print(f"[Linux 库] 复制失败: {name} ({exc})")
    return copied


def find_third_party_dir(sdk_dir: str) -> str:
    """
    从 SDK 源目录向上找同级的 3rd 目录（第三方库根）。

    <root>\\A910\\A910 → <root>\\3rd 这种布局；找不到返回空串。
    对应 ps/copyUtils.ps1 的 Find-ThirdPartyDir。
    """
    cur = os.path.abspath(sdk_dir.rstrip("/\\"))
    while cur:
        cand = os.path.join(cur, "3rd")
        if os.path.isdir(cand):
            return cand
        parent = os.path.dirname(cur)
        if parent == cur:
            break
        cur = parent
    return ""


def _wsl_to_win_path(p: str) -> str:
    """/mnt/d/git/3rd/x.so -> D:\\git\\3rd\\x.so；非 /mnt 形态只做分隔符归一。"""
    m = re.match(r"^/mnt/([A-Za-z])/(.*)$", p)
    if m:
        return f"{m.group(1).upper()}:\\" + m.group(2).replace("/", "\\")
    return p.replace("/", "\\")


def get_linux_runtime_deps(build_dir: str, arch: str = None, third_party_dir: str = None):
    """
    从 Linux 构建目录的链接行里解析 FAPAlgo 依赖的绝对路径 .so（opencv / onnxruntime）。

    构建目录里只有 libFAP.so / libFAPAlgo.so 自身；opencv_world 与 onnxruntime 是链接期依赖，
    构建完不会落到构建目录，只在链接命令里留了绝对路径。这两条路径由 WSL 侧 CMake 写出，
    形如 /mnt/d/git/3rd/onnxruntime-1.12.1/lib/Linux/aarch64/libonnxruntime.so。

    解析失败时按 THIRD_PARTY_DIR 的常规布局回退，且**每种库只取一份**（否则
    onnxruntime-1.12/1.25 会混装）。对应 ps/copyUtils.ps1 的 Get-LinuxRuntimeDeps。
    """
    ninja = os.path.join(build_dir, "build.ninja")
    link_txt = os.path.join(build_dir, "CMakeFiles", "FAPAlgo.dir", "link.txt")
    text = None
    for p in (ninja, link_txt):
        if os.path.isfile(p):
            try:
                with open(p, "r", encoding="utf-8", errors="ignore") as fh:
                    text = fh.read()
                break
            except OSError:
                continue

    out = []
    if text:
        # WSL 路径（/mnt/d/...）与 Windows 路径（D:/ 或 ninja 的 D$:/）两种都要认
        for m in re.finditer(r"(?:/mnt/[A-Za-z]|[A-Za-z]\$?:)[/\\][^ \"'\r\n]+\.so", text):
            p = _wsl_to_win_path(m.group(0).replace("$:", ":"))
            leaf = os.path.basename(p)
            # 自身产物与 demo 侧另有来源的 usb/uvc 从链接行带过来没意义
            if leaf.startswith(("libFAP", "libusb", "libuvc")):
                continue
            if os.path.isfile(p) and p not in out:
                out.append(p)

    if not out and third_party_dir and os.path.isdir(third_party_dir) and arch:
        # 先取目录、再逐个列文件：直接对带 * 的目录 glob 再过滤文件名会漏
        lib_dirs = []
        for sub in (os.path.join("lib", "Linux", arch),
                    os.path.join("lib", "linux", arch),
                    os.path.join("lib", arch)):
            for name in sorted(os.listdir(third_party_dir)):
                d = os.path.join(third_party_dir, name, sub)
                if os.path.isdir(d):
                    lib_dirs.append(d)
        # Linux 工程用单体库 opencv_world（拆分的 opencv_core/imgproc 是旧布局，不掺和）
        for pat in (r"^libonnxruntime.*\.so", r"^libopencv_world.*\.so"):
            rx = re.compile(pat)
            for d in sorted(lib_dirs, reverse=True):
                files = [n for n in sorted(os.listdir(d)) if rx.match(n)]
                if not files:
                    continue
                print(f"  [回退] {pat} 取自第三方目录: {d}")
                for n in files:
                    p = os.path.join(d, n)
                    if os.path.isfile(p) and p not in out:
                        out.append(p)
                break   # 该种类已找到，换下一种
    return out


def copy_linux_runtime_deps(build_dir: str, dst_dir: str, arch: str = None,
                            third_party_dir: str = None) -> int:
    """
    把 Linux 构建目录解析出的运行时依赖（opencv / onnxruntime）补进目标目录。

    onnxruntime 的 SONAME 依赖 libonnxruntime.so.1（如 1.12），所以同一个库的
    libX.so 与 libX.so.N 都要带上，否则客户机 dlopen 失败。
    对应 ps/copyUtils.ps1 的 Copy-LinuxRuntimeDeps。
    """
    deps = get_linux_runtime_deps(build_dir, arch, third_party_dir)
    if not deps:
        return 0
    os.makedirs(dst_dir, exist_ok=True)
    copied = 0
    for p in deps:
        src_dir = os.path.dirname(p)
        leaf = os.path.basename(p)
        names = [leaf]
        if leaf.endswith(".so"):
            names += [n for n in sorted(os.listdir(src_dir))
                      if n.startswith(leaf + ".") and os.path.isfile(os.path.join(src_dir, n))]
        for n in names:
            src = os.path.join(src_dir, n)
            if not os.path.isfile(src):
                continue
            try:
                shutil.copy2(src, os.path.join(dst_dir, n), follow_symlinks=True)
                copied += 1
            except OSError as exc:
                print(f"[Linux 依赖] 复制失败: {n} ({exc})")
    return copied


def copy_win_exe(src_dir: str, tg_root: str, sdk_dir: str = None):
    """
    复制 Windows x86/x64 exe dll。

    exe/dll 的落点有两种工程形态（A910_win、oxiscansdk_win_mut 这类只有 CMake 产物），
    所以必须走 resolve_win_demo_dir 回退，不能只看 Release / x64\\Release。

    sdk_dir 传了就把 SDK 构建产物里的运行时库（算法库 + opencv / onnxruntime）补进 demo 目录：
    demo 是 VS 工程，产物目录里只有 exe + FAP.dll，算法库独立成 DLL 后必须同目录部署，
    否则 demo 一跑就加载失败。对应 ps/copyUtils.ps1 的 Copy-WinExe。
    """
    for arch in ("x86", "x64"):
        dst = os.path.join(tg_root, "win_X64Demo" if arch == "x64" else "win_X86Demo")
        src = resolve_win_demo_dir(src_dir, arch)

        if not src:
            tried = "  |  ".join(get_win_demo_candidate_dirs(src_dir, arch))
            print(f"[跳过] {arch} 未找到含 .exe 的输出目录，已尝试: {tried}")
            continue

        print(f"[{arch} 产物目录] {src}")
        copy_files_by_suffix(src, dst, [".exe", ".dll"])

        if sdk_dir:
            # 构建入口不同 → 产物落点不同（cmake-build-* / build_temp\win\win_<arch>_*），逐个探测
            lib_src, _build_dir = find_lib_source(
                sdk_dir, "win", arch,
                ("Release", os.path.join("libFAP", "Release")),
            )
            if lib_src:
                n = copy_lib_files(lib_src, dst, "dll")
                print(f"  [{arch}] demo 运行时库 {n} 个 -> {dst}")
            else:
                print(f"[提示] {arch} 未找到 SDK 构建产物目录，demo 只带 demo 目录里原有的 dll")


def copy_android_apk(src_dir: str, target_dir: str):
    """复制Android debug APK"""
    src_apk_root = os.path.join(src_dir, "app", "build", "outputs", "apk", "debug")
    copy_files_by_suffix(src_apk_root, target_dir, [".apk"])


# ------------------------------------------------------------
# Windows 产物目录解析
#   同一套 demo 代码有两种工程形态，exe/dll 落点不同：
#     VS 工程   : <SrcDir>\Release                    / <SrcDir>\x64\Release
#     CMake 工程: <SrcDir>\cmake-build-release-vs2019_x86\Release
#                 <SrcDir>\cmake-build-release-vs2019_x64\Release
#   （A910_win、oxiscansdk_win_mut 这类只有 CMake 产物）
# ------------------------------------------------------------
def get_win_demo_candidate_dirs(src_dir: str, arch: str):
    """按优先级给出该架构的候选输出目录（VS 优先，其次 CMake）。对应 ps 的 Get-WinDemoCandidateDirs。"""
    if arch == "x64":
        vs_sub = os.path.join("x64", "Release")
        cmake_sub = os.path.join("cmake-build-release-vs2019_x64", "Release")
    else:
        vs_sub = "Release"
        cmake_sub = os.path.join("cmake-build-release-vs2019_x86", "Release")

    return [os.path.join(src_dir, vs_sub), os.path.join(src_dir, cmake_sub)]


def resolve_win_demo_dir(src_dir: str, arch: str):
    """
    按优先级挑出该架构下真正含有 .exe 的输出目录：
    先看 VS 的 Release / x64\\Release，里面没有 .exe（或目录不存在）时，
    回退到 CMake 的 cmake-build-release-vs2019_<arch>\\Release。

    写死 VS 路径会让包里缺 demo 目录（真实案例 D:/GSerSDKLib/A910/G6SDKv1.0.51.83）。
    返回命中的目录字符串；候选目录都没有 .exe 时返回 None。
    """
    for d in get_win_demo_candidate_dirs(src_dir, arch):
        if not os.path.isdir(d):
            continue
        for root, _dirs, files in os.walk(d):
            if any(f.lower().endswith(".exe") for f in files):
                return d
    return None


# ------------------------------------------------------------
# Qt Linux 预编译库
#   <QtDir>\linux 是源码树之外的预编译产物（按架构分子目录，如 aarch64/x64/arm）。
#   WSL 下建的 .so 多为符号链接，整棵树一把梭拷容易拷成 0 字节甚至卡住，
#   这里按文件逐个拷（copy2 跟随链接取真实内容），并统计各架构文件数。
#   对应 ps/OXi.ps1 的 Find-QtLinuxLibDir / Copy-QtLinuxLibs。
# ------------------------------------------------------------
def find_qt_linux_lib_dir(qt_dir: str):
    """在 Qt 工程目录下找预编译库目录：<QtDir>\\linux（大小写不敏感，实际多为 Linux）。找不到返回 None。"""
    if not os.path.isdir(qt_dir):
        return None

    for name in sorted(os.listdir(qt_dir)):
        p = os.path.join(qt_dir, name)
        if os.path.isdir(p) and name.lower() == "linux":
            return p
    return None


def copy_qt_linux_libs(qt_dir: str, dst_dir: str) -> bool:
    """
    把 <QtDir>\\linux 下的预编译库整份拷进 <dst_dir>\\<原名>。**只拷贝，不做任何构建。**

    返回是否真的复制到了文件。
    """
    lib_dir = find_qt_linux_lib_dir(qt_dir)
    if not lib_dir:
        print(f"[提示] {qt_dir} 下没有独立 linux/ 预编译目录（shared\\Linux\\<arch> 约定的机型由 copy_linux_build_libs 处理）")
        return False

    dst_lib = os.path.join(dst_dir, os.path.basename(lib_dir))
    if os.path.exists(dst_lib):
        remove_dir(dst_lib)
    safe_mkdir(dst_lib)

    copied = 0
    failed = 0
    for root, dirs, files in os.walk(lib_dir):
        # .workbuddy 之类的工程元数据目录剪掉（该目录理论上只有库文件，做个兜底）
        dirs[:] = [d for d in dirs if d != ".workbuddy"]
        for name in files:
            src = os.path.join(root, name)
            rel = os.path.relpath(src, lib_dir)
            dst_file = os.path.join(dst_lib, rel)
            safe_mkdir(os.path.dirname(dst_file))
            try:
                shutil.copy2(src, dst_file)
                copied += 1
            except Exception as e:
                failed += 1
                print(f"[Qt Linux库] 复制失败: {rel} ({e})")

    archs = []
    for name in sorted(os.listdir(dst_lib)):
        p = os.path.join(dst_lib, name)
        if os.path.isdir(p):
            n = sum(len(fs) for _r, _d, fs in os.walk(p))
            archs.append(f"{name}({n})")

    summary = f"复制 {copied} 个文件"
    if failed:
        summary += f"，失败 {failed} 个"
    if archs:
        summary += "（" + ", ".join(archs) + "）"
    print(f"[Qt Linux库] {os.path.basename(lib_dir)}: {summary}")

    return copied > 0


# ============================================================
# 打包忽略目录（ps 侧一一对应：ps/copyUtils.ps1 的 Get-PackIgnoreDirs）
# 统一在这里定义，别在各处复制粘贴 —— 新增一类要忽略的目录只改这一处。
#   * .workbuddy / .git / .idea / .vs 是编辑器或工具目录，任何一份 SDK 都不该带
#   * cmake-build* 用前缀匹配（不能写精确名）：真实目录名是
#     cmake-build-release-vs2019_x64 / cmake-build-debug 之类
#   * "cmake"（无横线）不在列表里 —— A910_qt/cmake 下是 toolchain-*.cmake 源码
# ============================================================
PACK_IGNORE_DIRS = {
    # simpleWin（Windows 源码树）
    "win": ("Release", "x64", ".vs", ".vscode", ".git", ".idea", ".workbuddy", "CMakeFiles"),
    # simpleAndroid（Android 源码树）
    "android": (".gradle", ".git", ".idea", ".workbuddy", ".cxx", ".artifacts", "build", "build-static"),
    # simpleLinux（Qt 源码树）
    "qt": (".git", ".idea", ".vs", ".vscode", ".workbuddy", "build", "build-static", ".cxx", "CMakeFiles"),
    # doc（文档目录）
    "doc": (".git", ".workbuddy"),
}


def make_pack_ignore(kind: str, extra_dirs=()):
    """
    生成 shutil.copytree 的 ignore 回调：按 kind 排除 PACK_IGNORE_DIRS 里的目录，
    外加所有 cmake-build*（前缀匹配）与调用方额外指定的 extra_dirs。

    extra_dirs 供 Copy-QtSimpleLinux 用：把 linux 预编译库目录从源码树那趟拷贝里摘出来，
    再交给 copy_qt_linux_libs 单独逐文件拷（见 ps 侧同名逻辑）。
    """
    dirs = tuple(PACK_IGNORE_DIRS[kind]) + tuple(extra_dirs)

    def _ignore(src_dir, names):
        return [
            n for n in names
            if os.path.isdir(os.path.join(src_dir, n))
            and (n in dirs or n.startswith("cmake-build"))
        ]

    return _ignore


# 与 ps/copyUtils.ps1 的 Copy-WinSourceCode / Copy-AndroidSourceCode /
# Copy-QtSimpleLinux / Copy-Doc 一一对应
ignore_win_code = make_pack_ignore("win")
ignore_android_code = make_pack_ignore("android")
ignore_qt_simple_linux = make_pack_ignore("qt")
ignore_doc = make_pack_ignore("doc")


def _copy_source_tree(src_dir: str, dst_dir: str, ignore, label: str) -> bool:
    """
    源码树整体复制：源不存在只提示（对应 ps 的 Copy-DirectoryFiltered），
    目标已存在先删掉再建（shutil.copytree 目标存在会直接抛 FileExistsError）。
    """
    if not os.path.isdir(src_dir):
        print(f"[跳过] {label} 源目录不存在: {src_dir}")
        return False

    if os.path.exists(dst_dir):
        remove_dir(dst_dir)
    safe_mkdir(os.path.dirname(dst_dir))

    shutil.copytree(src_dir, dst_dir, ignore=ignore)
    print(f"[复制{label}] {src_dir} -> {dst_dir}")
    return True


def copy_win_source_code(src_dir: str, target_root: str) -> bool:
    """simpleWin：排除 IDE/构建中间目录 + 工程元数据（对应 ps 的 Copy-WinSourceCode）"""
    dst_code = os.path.join(target_root, "simpleWin")
    return _copy_source_tree(src_dir, dst_code, ignore_win_code, "Windows源码")


def copy_android_source_code(src_dir: str, target_root: str) -> bool:
    """simpleAndroid：同样排除 .gradle / build / .cxx 等（对应 ps 的 Copy-AndroidSourceCode）"""
    dst_code = os.path.join(target_root, "simpleAndroid")
    return _copy_source_tree(src_dir, dst_code, ignore_android_code, "Android源码")
