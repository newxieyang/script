#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
apiDiff.py —— libFAP 对外 API 头文件差异看板

背景
----
A910 / MIAXIS / Thales / huantian 只是同一个 libFAP 仓库的不同分支（一位客户一条分支），
它们的对外 API 头文件（*ScanAPI.h / *ScanUltimate.h / *ScanUltimateApi_err.h）本应同源，
实际却各自漂移，导致「同名函数在每个项目里签名都不一样」。

头文件一共有四层拷贝，每层都可能独立漂移：
  1. libFAP.git              —— 真源，但一条客机一条分支，源本身就分叉
  2. <项目>/libFAP           —— submodule，各 pin 一条分支
  3. <项目>_Android/libFAP   —— submodule 内（同源）
  4. <项目>_win / <项目>_qt  —— 手工拷贝（最容易漂）

本脚本只读不改，做四件事：
  branches   列出 libFAP 全部分支上三个头文件的版本（哈希 + 行数），看有多少份不同
  contracts  按「导出函数指纹」把分支聚成 API 契约组 —— 这就是划分版本线/tag 的依据
  functions  提取各项目的导出函数签名，列出「同名但签名不同」的清单
  copies     检查各项目 _win / _qt / _Android 里的副本与 libFAP 主本是否同源

用法
----
  python apiDiff.py                      # 全部小节，结果打到控制台
  python apiDiff.py -o report.md         # 同时写出 markdown 报告
  python apiDiff.py -s branches,copies   # 只跑指定小节
  python apiDiff.py --libfap <path>      # 手工指定 libFAP 仓库（默认自动探测）
  python apiDiff.py --focus A910,MIAXIS  # 只对指定项目做函数对比（默认全部）
"""

import argparse
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

# --------------------------------------------------------------------------
# 常量
# --------------------------------------------------------------------------

# (小节名, 文件名后缀) —— 用后缀匹配，这样 OXiScanAPI.h 和 ScanAPI.h 都能命中
API_KINDS = [
    ("ScanAPI", "ScanAPI.h"),
    ("ScanUltimate", "ScanUltimate.h"),
    ("ScanUltimateApi_err", "ScanUltimateApi_err.h"),
]

# 函数声明行：以 OXISCAN_API / SCAN_API 开头，到分号结束（本仓库的头都是单行声明）
FUNC_DECL_RE = re.compile(r"^[ \t]*(?:OXISCAN_API|OXiScanAPI|SCAN_API)\b[^;{}]*;", re.MULTILINE)
FUNC_NAME_RE = re.compile(r"\b([A-Za-z_]\w*)\s*\(")

# demo 目录里可能有头文件的相对位置（按优先级）
DEMO_HEADER_SUBDIRS = ["", "include", "libFAP/include", "libFAP/src/main/cpp/include"]

# 项目里"对外 API 头"所在目录的候选位置（按优先级）
API_INCLUDE_CANDIDATES = [
    "libFAP/include",
    "libFAP/src/main/cpp/include",
    "base/export",
    "include",
]

HERE = Path(__file__).resolve().parent
REPO_ROOT = HERE.parent
CONFIG_PATH = HERE.parent / "config" / "api_config.json"

ALL_SECTIONS = ["branches", "contracts", "functions", "copies"]


# --------------------------------------------------------------------------
# 基础工具
# --------------------------------------------------------------------------

def git(repo, *args, binary=False):
    """执行 git 命令。失败返回 None（不抛异常）。"""
    try:
        p = subprocess.run(
            ["git", "-C", str(repo), *args],
            capture_output=True, timeout=120,
        )
    except Exception:
        return None
    if p.returncode != 0:
        return None
    if binary:
        return p.stdout
    return p.stdout.decode("utf-8", errors="replace")


def md5(text):
    if isinstance(text, str):
        text = text.encode("utf-8", errors="replace")
    return hashlib.md5(text).hexdigest()[:8]


def count_diff_lines(a, b):
    """粗略统计两个文本的差异行数（不调 diff 命令，够用且快）。"""
    la, lb = a.splitlines(), b.splitlines()
    import difflib
    n = 0
    for line in difflib.unified_diff(la, lb, n=0):
        if line[:1] in "+-" and not line.startswith(("+++", "---")):
            n += 1
    return n


def norm_line(s):
    """归一化：压掉多余空白，便于跨文件比较签名。"""
    return re.sub(r"\s+", " ", s).strip()


def _rank_name(name, suffix):
    """同一后缀的多个候选怎么排优先级：规范名 > OXi 前缀 > 其它前缀 > 更短的名字。

    现实里同一个目录可能同时躺着 `ScanAPI.h`、`OXiScanAPI.h`、`HTScanAPI.h`，
    必须以规范名为准，否则会拿客户自制的那份去比。
    """
    if name == suffix:
        return (0, len(name), name)
    if name == "OXi" + suffix:
        return (1, len(name), name)
    return (2, len(name), name)


def pick_file(paths, suffix):
    """从候选 Path 里挑一个头文件（按 _rank_name 优先级）。"""
    paths = [p for p in paths if p is not None]
    if not paths:
        return None
    return sorted(paths, key=lambda p: _rank_name(p.name, suffix))[0]


def canon(sig):
    """比较用的签名规范形式：压空白 + 统一指针星号两侧的空格。

    只用于判定「是否同一个签名」，展示时仍用原始文本。
    （`void* p` 和 `void *p` 是同一个签名，不该算差异。）
    """
    s = re.sub(r"\s+", " ", sig)
    s = re.sub(r"\s*\*\s*", "*", s)
    return s.strip()


# --------------------------------------------------------------------------
# 配置 / 探测
# --------------------------------------------------------------------------

def load_projects():
    if not CONFIG_PATH.is_file():
        return []
    with open(CONFIG_PATH, encoding="utf-8") as f:
        cfg = json.load(f)
    out = []
    for key, v in cfg.items():
        sdk_dir = Path(v["sdk_dir"].replace("\\", "/"))
        out.append({
            "key": key,
            "name": v.get("name", ""),
            "sdk_dir": sdk_dir,
            "keyword": v.get("keyword", "OXISCAN_API"),
            "fun_key": v.get("funKey", "OXi_"),
        })
    return out


def find_libfap(projects, override=None):
    if override:
        p = Path(override)
        return p if (p / ".git").exists() else None
    for prj in projects:
        cand = prj["sdk_dir"] / "libFAP"
        if (cand / ".git").exists():
            return cand
    return None


def list_remote_branches(repo):
    """返回远程分支名列表（去重、排序）。"""
    out = git(repo, "branch", "-r", "--format=%(refname:short)")
    if out is None:
        out = git(repo, "branch", "-a", "--format=%(refname:short)")
    if not out:
        return []
    names = set()
    for line in out.splitlines():
        line = line.strip()
        if not line or line.endswith("/HEAD"):
            continue
        if line.startswith("origin/"):
            line = line[len("origin/"):]
        elif "/" in line:
            line = line.split("/", 1)[1]
        names.add(line)
    return sorted(names)


def tree_files(repo, ref, cache):
    """某个 ref 下的全部文件路径（带缓存）。"""
    if ref in cache:
        return cache[ref]
    out = git(repo, "ls-tree", "-r", ref, "--name-only") or ""
    files = [l.strip() for l in out.splitlines() if l.strip()]
    cache[ref] = files
    return files


def find_header_in_tree(files, suffix):
    """在 git 文件列表里按后缀找头文件，返回路径。

    深度优先（浅的优先），同深度按 _rank_name 挑规范名。
    """
    hits = [f for f in files if f.endswith(suffix)]
    if not hits:
        return None
    def rank(p):
        return (p.count("/"),) + _rank_name(p.rsplit("/", 1)[-1], suffix)
    hits.sort(key=rank)
    return hits[0]


def show(repo, ref, path):
    out = git(repo, "show", f"{ref}:{path}", binary=True)
    if out is None:
        return None
    return out.decode("utf-8", errors="replace")


def find_demo_dirs(sdk_dir):
    """按 {basename}_win / _qt / _Android 约定找同级 demo 目录。"""
    base, parent = sdk_dir.name, sdk_dir.parent
    found = []
    if not parent.is_dir():
        return found
    siblings = {c.name.lower(): c for c in parent.iterdir() if c.is_dir()}
    for suf in ("_win", "_qt", "_android"):
        cand = siblings.get(f"{base}{suf}".lower())
        if cand:
            found.append((suf, cand))
    return found


def find_demo_header_locations(demo_dir, cache):
    """在 demo 目录的已知位置里找三个头文件。

    返回 {相对位置: {文件名后缀: [候选 Path, ...]}} —— 保留全部候选，
    因为同一个目录下可能同时有 `ScanAPI.h` 和 `HTScanAPI.h` 这种「两套并存」的情况。
    不做全树递归 —— demo 目录动辄几百 MB。
    """
    key = str(demo_dir)
    if key in cache:
        return cache[key]
    found = {}
    for sub in DEMO_HEADER_SUBDIRS:
        d = demo_dir / sub if sub else demo_dir
        if not d.is_dir():
            continue
        for _kind, fname in API_KINDS:
            cands = [f for f in sorted(d.iterdir())
                     if f.is_file() and f.name.endswith(fname)]
            if cands:
                found.setdefault(sub or "根目录", {})[fname] = cands
    cache[key] = found
    return found


def extract_funcs(text, fun_key="OXi_"):
    """
    提取导出函数 -> {函数名: 归一化签名}。
    只保留函数名里含 fun_key 的（过滤掉宏定义里的 __declspec 之类）。
    """
    funcs = {}
    for m in FUNC_DECL_RE.finditer(text):
        decl = norm_line(m.group(0))
        nm = FUNC_NAME_RE.search(decl)
        if not nm:
            continue
        name = nm.group(1)
        if fun_key and fun_key not in name:
            continue
        funcs[name] = decl.rstrip(";").strip()
    return funcs


# --------------------------------------------------------------------------
# 各小节
# --------------------------------------------------------------------------

def sect_branches(repo, branches, cache, lines, idx):
    lines.append(f"## {idx}. 分支版本矩阵")
    lines.append("")
    lines.append("libFAP 每条分支上三个头文件的版本。哈希相同 = 内容逐字节相同。")
    lines.append("")
    header = "| 分支 |" + "".join(f" {k} | 行 |" for k, _ in API_KINDS)
    lines.append(header)
    lines.append("|---" * (1 + 2 * len(API_KINDS)) + "|")

    stats = {k: {} for k, _ in API_KINDS}
    for br in branches:
        files = tree_files(repo, f"origin/{br}", cache) or tree_files(repo, br, cache)
        row = [f"`{br}`"]
        for kind, suffix in API_KINDS:
            p = find_header_in_tree(files, suffix)
            if not p:
                row += ["—", "—"]
                continue
            content = show(repo, f"origin/{br}", p) or show(repo, br, p)
            if content is None:
                row += ["—", "—"]
                continue
            h = md5(content)
            n = len(content.splitlines())
            row += [f"`{h}`", str(n)]
            stats[kind].setdefault(h, []).append(br)
        lines.append("| " + " | ".join(row) + " |")

    lines.append("")
    lines.append("**小计**")
    lines.append("")
    lines.append("| 头文件 | 分支数 | 不同版本数 | 只出现在单条分支上的版本 |")
    lines.append("|---|---|---|---|")
    for kind, _ in API_KINDS:
        d = stats[kind]
        total = sum(len(v) for v in d.values())
        uniq = len(d)
        lonely = sum(1 for v in d.values() if len(v) == 1)
        lines.append(f"| {kind} | {total} | **{uniq}** | {lonely} |")
    lines.append("")
    return stats


def sect_contracts(repo, branches, cache, lines, idx):
    lines.append(f"## {idx}. API 契约分组（按 ScanAPI 导出函数指纹聚类）")
    lines.append("")
    lines.append("把每条分支的 ScanAPI 导出函数集合+签名做指纹，指纹相同的分支 = 同一份对外契约。")
    lines.append("分组结果就是「版本化路线」里该打几个 tag 的依据：同组可以共用一个版本号。")
    lines.append("")

    groups = {}
    for br in branches:
        files = tree_files(repo, f"origin/{br}", cache) or tree_files(repo, br, cache)
        p = find_header_in_tree(files, "ScanAPI.h")
        if not p:
            groups.setdefault("(无 ScanAPI)", []).append(br)
            continue
        content = show(repo, f"origin/{br}", p) or show(repo, br, p)
        if content is None:
            continue
        funcs = extract_funcs(content, fun_key="")
        fp = md5("\n".join(f"{k}={v}" for k, v in sorted(funcs.items())))
        groups.setdefault(fp, []).append((br, len(funcs), next(iter(sorted(funcs)), "—")))

    lines.append("| 契约指纹 | 分支数 | 导出函数数 | 函数命名样本 | 分支 |")
    lines.append("|---|---|---|---|---|")
    for fp, members in sorted(groups.items(), key=lambda kv: -len(kv[1])):
        if fp == "(无 ScanAPI)":
            lines.append(f"| — | {len(members)} | — | — | {', '.join('`'+m+'`' for m in members)} |")
            continue
        nfuncs = members[0][1]
        sample = members[0][2]
        names = ", ".join(f"`{m}`" for m, _, _ in members)
        lines.append(f"| `{fp}` | {len(members)} | {nfuncs} | `{sample}` | {names} |")
    lines.append("")
    return groups


def resolve_api_include(prj):
    """定位一个项目的对外 API 头目录。"""
    for sub in API_INCLUDE_CANDIDATES:
        d = prj["sdk_dir"] / sub
        if d.is_dir() and any(f.is_file() and f.suffix == ".h" for f in d.iterdir()):
            return d
    return None


def collect_api_text(inc_dir):
    """收拢某目录下的 API 头文本，返回 (文本, 用到的文件名列表)。

    先按 API_KINDS 的三个后缀找；一个都没命中就退化成「该目录全部 .h」，
    这样命名体系不同的项目（如 GSER 的 OXiScan_Api.h）也能纳入对比。
    """
    used, text = [], ""
    if not inc_dir or not inc_dir.is_dir():
        return text, used
    for _kind, suffix in API_KINDS:
        cands = [f for f in sorted(inc_dir.iterdir()) if f.is_file() and f.name.endswith(suffix)]
        f = pick_file(cands, suffix)
        if f is not None:
            text += f.read_text(encoding="utf-8", errors="replace") + "\n"
            used.append(f.name)
    if not used:
        for f in sorted(inc_dir.glob("*.h")):
            text += f.read_text(encoding="utf-8", errors="replace") + "\n"
            used.append(f.name)
    return text, used


def sect_functions(projects, focus, lines, idx):
    lines.append(f"## {idx}. 同名函数签名差异")
    lines.append("")
    lines.append("按项目实际编译时会吃进去的那份头文件对比。只列出「同名但签名不一致」的函数。")
    lines.append("**注意**：如果某项目给函数改了名（例如 `GetVersionInfo` vs `OXi_getVersion`），")
    lines.append("工具无法自动判定它们是同一个函数，会落到下面的「独有函数」清单里，需人工确认。")
    lines.append("")

    picked = [p for p in projects if not focus or p["key"] in focus]
    data, sources = {}, []
    for prj in picked:
        inc = resolve_api_include(prj)
        text, used = collect_api_text(inc)
        rel = inc.relative_to(prj["sdk_dir"]) if inc else None
        sources.append((prj["key"], str(rel) if rel else "**未找到**",
                        ", ".join(used) if used else "—"))
        if text.strip():
            data[prj["key"]] = extract_funcs(text, fun_key="")

    lines.append("| 项目 | 头文件目录 | 用到的文件 | 提取函数数 |")
    lines.append("|---|---|---|---|")
    for key, rel, used in sources:
        lines.append(f"| `{key}` | `{rel}` | {used} | {len(data.get(key, {}))} |")
    lines.append("")

    if not data:
        lines.append("_没有可比对的项目。_")
        lines.append("")
        return

    cols = list(data.keys())
    all_names = sorted({n for f in data.values() for n in f})

    diffs = []
    for name in all_names:
        variants = {}   # canon 形式 -> [原始签名, [项目...]]
        for c in cols:
            sig = data[c].get(name)
            if not sig:
                continue
            k = canon(sig)
            if k not in variants:
                variants[k] = [sig, []]
            variants[k][1].append(c)
        if len(variants) > 1:
            diffs.append((name, variants))

    lines.append(f"共 {len(all_names)} 个导出函数，其中 **{len(diffs)} 个**在不同项目里签名不一致。")
    lines.append("")
    if diffs:
        lines.append("| 函数 | 变体数 | " + " | ".join(cols) + " |")
        lines.append("|" + "---|" * (2 + len(cols)))
        for name, variants in diffs:
            lookup = {}
            for i, (_raw, owners) in enumerate(variants.values(), 1):
                for o in owners:
                    lookup[o] = f"v{i}"
            row = [f"`{name}`", str(len(variants))] + [lookup.get(c, "—") for c in cols]
            lines.append("| " + " | ".join(row) + " |")
        lines.append("")
        lines.append("各变体的完整签名：")
        lines.append("")
        for name, variants in diffs:
            lines.append(f"**`{name}`**")
            lines.append("")
            for i, (raw, owners) in enumerate(variants.values(), 1):
                lines.append(f"- `v{i}` ({', '.join(owners)}) ： `{raw}`")
            lines.append("")

    # 「独有」= 只在这个项目里出现，其它项目一个都没有
    only_in = {}
    for c in cols:
        others = set()
        for k, d in data.items():
            if k != c:
                others |= set(d)
        only_in[c] = sorted(set(data[c]) - others)
    if any(only_in.values()):
        lines.append("**某项目独有的导出函数**（其它项目完全没有同名函数）")
        lines.append("")
        for c, names in only_in.items():
            if names:
                lines.append(f"- `{c}` （{len(names)} 个）： {', '.join('`'+n+'`' for n in names)}")
        lines.append("")
    return diffs


def sect_copies(projects, lines, idx):
    lines.append(f"## {idx}. 拷贝层一致性")
    lines.append("")
    lines.append("主本 = 各项目的 API 头目录（G6 机型是 `libFAP/include`，来自 submodule）。")
    lines.append("同一个 demo 目录下可能**存在多处副本**（根目录 / `include/` / `libFAP/…`），")
    lines.append("它们的同步状态可能各不相同，所以逐处列出。")
    lines.append("")
    lines.append("| 项目 | 副本位置 | ScanAPI | ScanUltimate | Api_err |")
    lines.append("|---|---|---|---|---|")

    cache = {}
    problems = []
    extras = []      # 同一目录下「另有多份同后缀头文件」的情况
    for prj in projects:
        main_inc = resolve_api_include(prj)
        if main_inc is None:
            continue
        main_files = {}
        for _kind, fname in API_KINDS:
            cands = [f for f in sorted(main_inc.iterdir())
                     if f.is_file() and f.name.endswith(fname)]
            main_files[fname] = pick_file(cands, fname)
        demos = find_demo_dirs(prj["sdk_dir"])
        if not demos:
            continue
        for _suf, demo in demos:
            locations = find_demo_header_locations(demo, cache)
            if not locations:
                continue
            for sub, files in sorted(locations.items()):
                row = [f"`{prj['key']}`", f"`{demo.name}` / {sub}"]
                for _kind, fname in API_KINDS:
                    main_f = main_files.get(fname)
                    cands = files.get(fname) or []
                    copy_f = pick_file(cands, fname)
                    if len(cands) > 1:
                        others = [f.name for f in cands if f is not copy_f]
                        extras.append((prj["key"], demo.name, sub, fname,
                                       copy_f.name if copy_f else "—", others))
                    if main_f is None:
                        row.append("主本缺失")
                    elif copy_f is None:
                        row.append("—")
                    elif main_f.read_text(encoding="utf-8", errors="replace") == \
                            copy_f.read_text(encoding="utf-8", errors="replace"):
                        row.append("同源")
                    else:
                        a = main_f.read_text(encoding="utf-8", errors="replace")
                        b = copy_f.read_text(encoding="utf-8", errors="replace")
                        n = count_diff_lines(a, b)
                        row.append(f"**漂移 {n} 行**")
                        problems.append((prj["key"], demo.name, sub, _kind, n, str(copy_f)))
                lines.append("| " + " | ".join(row) + " |")
    lines.append("")
    if extras:
        lines.append("**同目录下并存多份同后缀头文件**（比较时取了规范名，其余需人工确认是否是废弃副本）：")
        lines.append("")
        for key, demo, sub, fname, used, others in extras:
            lines.append(f"- `{key}` / `{demo}` / {sub} —— 取 `{used}`，另有 "
                         + ", ".join(f"`{o}`" for o in others))
        lines.append("")
    if problems:
        lines.append(f"**需要处理的漂移（{len(problems)} 处）：**")
        lines.append("")
        for key, demo, sub, kind, n, path in sorted(problems, key=lambda t: -t[4]):
            lines.append(f"- `{key}` / `{demo}` / {sub} / {kind} —— 差 {n} 行")
            lines.append(f"  - `{path}`")
        lines.append("")
    elif not extras:
        lines.append("所有拷贝层与主本一致。")
        lines.append("")
    return problems


# --------------------------------------------------------------------------
# main
# --------------------------------------------------------------------------

def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")

    ap = argparse.ArgumentParser(
        description="libFAP 对外 API 头文件差异看板（只读，不修改任何文件）")
    ap.add_argument("-o", "--out", help="同时写出 markdown 报告到指定文件")
    ap.add_argument("-s", "--sections", default="all",
                    help=f"要跑的小节，逗号分隔。可选：{','.join(ALL_SECTIONS)}，或 all")
    ap.add_argument("--libfap", help="libFAP 仓库路径（默认从 api_config.json 的项目里探测）")
    ap.add_argument("--focus", help="只对指定项目做函数对比，逗号分隔（默认全部）")
    args = ap.parse_args()

    if args.sections.strip().lower() == "all":
        sections = list(ALL_SECTIONS)
    else:
        sections = [s.strip() for s in args.sections.split(",") if s.strip()]
        bad = [s for s in sections if s not in ALL_SECTIONS]
        if bad:
            print(f"[错误] 未知小节：{', '.join(bad)}；可选 {', '.join(ALL_SECTIONS)}")
            return 2

    projects = load_projects()
    focus = {s.strip() for s in args.focus.split(",")} if args.focus else set()

    head = []
    head.append("# libFAP 对外 API 头文件差异看板")
    head.append("")
    head.append(f"- 项目配置：`{CONFIG_PATH}`（{len(projects)} 个：{', '.join(p['key'] for p in projects)}）")

    libfap = find_libfap(projects, args.libfap)
    branches = []
    cache = {}
    if libfap:
        branches = list_remote_branches(libfap)
        head.append(f"- libFAP 仓库：`{libfap}`")
        head.append(f"- 远程分支：**{len(branches)}** 条")
    else:
        head.append("- libFAP 仓库：**未找到**（分支相关小节将跳过，可用 --libfap 指定）")
    head.append("")

    body = []
    n = 0
    if "branches" in sections and libfap:
        n += 1
        sect_branches(libfap, branches, cache, body, n)
    if "contracts" in sections and libfap:
        n += 1
        sect_contracts(libfap, branches, cache, body, n)
    if "functions" in sections:
        n += 1
        sect_functions(projects, focus, body, n)
    if "copies" in sections:
        n += 1
        problems = sect_copies(projects, body, n)
        head.append(f"- 拷贝层漂移：**{len(problems)}** 处（详见最后一节）")
        head.append("")

    head.append("> 本报告由 `py/apiDiff.py` 生成，只读、不修改任何文件。")
    head.append("")

    lines = head + body
    text = "\n".join(lines)
    print(text)
    if args.out:
        out = Path(args.out)
        out.write_text(text, encoding="utf-8")
        print(f"\n[已写出] {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
