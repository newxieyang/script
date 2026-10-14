#!/bin/bash
set -e

REPO_DIR="/data/usershare/git/mutDemo/A910"
BRANCH="A910"
REMOTE="origin"

cd "$REPO_DIR" || {
  echo "错误：目录不存在 $REPO_DIR"
  exit 1
}

echo "==== 当前目录: $(pwd) ===="
echo "==== 当前分支: $(git branch --show-current) ===="

# 1. 获取远程最新信息
echo ">>> git fetch $REMOTE ..."
git fetch "$REMOTE"

# 2. 确认远程分支存在
if ! git rev-parse --verify "$REMOTE/$BRANCH" >/dev/null 2>&1; then
  echo "错误：远程分支 $REMOTE/$BRANCH 不存在"
  exit 1
fi

# 3. 切换到 A910（没有则创建并跟踪远程）
if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
  git checkout "$BRANCH"
else
  git checkout -b "$BRANCH" "$REMOTE/$BRANCH"
fi

# 4. 比较本地与远程是否有差异
LOCAL_HASH=$(git rev-parse HEAD)
REMOTE_HASH=$(git rev-parse "$REMOTE/$BRANCH")

echo "本地: $LOCAL_HASH"
echo "远程: $REMOTE_HASH"

if [ "$LOCAL_HASH" = "$REMOTE_HASH" ]; then
  echo ">>> 本地与远程一致，无需更新"
  exit 0
fi

# 5. 有差异：远程强制覆盖本地
echo ">>> 发现差异，用远程覆盖本地 ..."
git reset --hard "$REMOTE/$BRANCH"

# 可选：清理未跟踪文件（谨慎，会删本地新增文件）
# git clean -fd

echo ">>> 更新完成"
git log -1 --oneline
