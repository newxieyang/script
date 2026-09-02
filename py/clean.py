import os
from pathlib import Path

def clean_directory(root_dir: str):
    """
    递归遍历目录：
    1. 删除所有非 .raw 文件
    2. 删除空文件夹（从最深层开始删）
    """
    root = Path(root_dir)

    if not root.exists() or not root.is_dir():
        print(f"目录不存在或不是文件夹: {root}")
        return

    # 1. 先删除所有非 .raw 文件（递归）
    for path in root.rglob("*"):
        if path.is_file():
            if path.suffix.lower() != ".raw":
                try:
                    path.unlink()
                    print(f"删除文件: {path}")
                except Exception as e:
                    print(f"删除文件失败 {path}: {e}")

    # 2. 再删除空文件夹（从最深层开始）
    # 用 topdown=False，先处理子目录
    for dirpath, dirnames, filenames in os.walk(root, topdown=False):
        # 如果当前目录已经没有任何文件和子目录，就删除
        if not dirnames and not filenames:
            try:
                os.rmdir(dirpath)
                print(f"删除空文件夹: {dirpath}")
            except Exception as e:
                print(f"删除文件夹失败 {dirpath}: {e}")


if __name__ == "__main__":
    # 修改成你要清理的目录
    target_dir = r"D:\cache\Plain"
    clean_directory(target_dir)
    print("清理完成")