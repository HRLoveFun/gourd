#!/usr/bin/env bash
# probe.sh — 采集审查前的原始事实。只读；不判四值，不输出命中 / 未命中 / 分数。
#
# 用法（从仓库根执行）：
#   ./skills/ai-engineering-audit/scripts/probe.sh [目标目录] [--base <ref>] [--limit <N>]
#
#   --base <ref>  只看 <ref>..HEAD 这一段历史（tag / commit / 分支）
#   --limit <N>   每张列表最多显示 N 条，默认 20
#
# 输出全部是事实：每条都允许人工否决。数方向反转、判跳数、评证据强度仍由人做。

set -u

usage() {
  cat <<'USAGE'
用法：probe.sh [目标目录] [--base <ref>] [--limit <N>]
  --base <ref>  只看 <ref>..HEAD 这一段历史（tag / commit / 分支）
  --limit <N>   每张列表最多显示 N 条，默认 20
只读；不判四值；不输出命中 / 未命中 / 分数。
USAGE
  exit 64
}

TARGET="."
BASE=""
LIMIT=20

while [ $# -gt 0 ]; do
  case "$1" in
    --base)
      [ $# -ge 2 ] || usage
      BASE="$2"
      shift 2
      ;;
    --limit)
      [ $# -ge 2 ] || usage
      case "$2" in
        ''|*[!0-9]*) echo "--limit 需要正整数" >&2; exit 64 ;;
      esac
      [ "$2" -ge 1 ] || { echo "--limit 需要正整数" >&2; exit 64; }
      LIMIT="$2"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    -*)
      echo "未知参数：$1" >&2
      usage
      ;;
    *)
      [ "$TARGET" = "." ] || { echo "只接受一个目标目录" >&2; exit 64; }
      TARGET="$1"
      shift
      ;;
  esac
done

[ -d "$TARGET" ] || { echo "不是目录：$TARGET" >&2; exit 64; }
cd "$TARGET" || exit 64

IS_GIT=0
if git rev-parse --git-dir >/dev/null 2>&1; then
  IS_GIT=1
fi

if [ -n "$BASE" ] && [ "$IS_GIT" -eq 0 ]; then
  echo "--base 需要 git 仓库，当前目录没有 .git" >&2
  exit 64
fi
if [ -n "$BASE" ] && ! git rev-parse --verify "$BASE" >/dev/null 2>&1; then
  echo "--base 不是可解析的 ref：$BASE" >&2
  exit 64
fi

# 被扫描的文件清单：git 仓库走索引，否则走 find 并打印排除项
list_files() {
  if [ "$IS_GIT" -eq 1 ]; then
    git ls-files 2>/dev/null
  else
    find . -type f \
      ! -path './.git/*' ! -path '*/node_modules/*' ! -path '*/vendor/*' \
      ! -path '*/dist/*' ! -path '*/build/*' ! -path '*/.venv/*' \
      2>/dev/null | sed 's|^\./||'
  fi
}

echo "# 原始事实，判定仍在人。以下不含命中 / 未命中 / 分数。"
echo "# 目标：$(pwd)"
echo "# 日期：$(date '+%Y-%m-%d')"
echo

echo "## 仓库"
if [ "$IS_GIT" -eq 1 ]; then
  GITDIR=$(git rev-parse --git-dir 2>/dev/null)
  echo "git: yes"
  echo "head: $(git rev-parse --short HEAD 2>/dev/null || echo '无提交')"
  echo "branch: $(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
  echo "commits: $(git rev-list --count HEAD 2>/dev/null || echo 0)"
  echo "first_commit: $(git log --reverse --date=short --format=%ad 2>/dev/null | head -n 1)"
  echo "last_commit: $(git log -1 --date=short --format=%ad 2>/dev/null)"
  if [ -f "$GITDIR/shallow" ]; then
    echo "shallow: yes（历史不完整，反转可能判不了）"
  else
    echo "shallow: no"
  fi
else
  echo "git: no（无 .git，历史不可读）"
  echo "扫描排除：.git node_modules vendor dist build .venv"
fi
echo

echo "## 规模"
echo "files: $(list_files | wc -l | tr -d ' ')"
echo "max_path_depth: $(list_files | awk -F/ 'NF>m{m=NF} END{print m+0}')"
echo

echo "## 测试文件（按命名约定，事实）"
TESTS=$(list_files | grep -Ei '(^|/)(tests?|__tests__|specs?)(/|$)|[._-](test|spec)s?\.[a-z0-9]+$|(Test|Tests|Spec)\.(java|kt|cs|scala|php)$')
if [ -n "$TESTS" ]; then
  TEST_COUNT=$(printf '%s\n' "$TESTS" | wc -l | tr -d ' ')
  echo "count: $TEST_COUNT"
  printf '%s\n' "$TESTS" | head -n "$LIMIT"
  if [ "$TEST_COUNT" -gt "$LIMIT" ]; then
    echo "…（共 $TEST_COUNT 条，只列前 $LIMIT 条）"
  fi
else
  echo "count: 0（没有按命名约定识别出的测试文件，不代表没有测试）"
fi
echo

echo "## 入口候选（按文件名，事实；需人工确认）"
ENTRIES=$(list_files | grep -E '(^|/)(main|index|app|server|cli|bootstrap|entry)\.[a-z0-9]+$|^(cmd|api|src)/[^/]+\.(go|rs|py|ts|js)$')
if [ -n "$ENTRIES" ]; then
  ENTRY_COUNT=$(printf '%s\n' "$ENTRIES" | wc -l | tr -d ' ')
  echo "count: $ENTRY_COUNT"
  printf '%s\n' "$ENTRIES" | head -n "$LIMIT"
  if [ "$ENTRY_COUNT" -gt "$LIMIT" ]; then
    echo "…（共 $ENTRY_COUNT 条，只列前 $LIMIT 条）"
  fi
else
  echo "count: 0"
fi
echo

if [ "$IS_GIT" -eq 1 ]; then
  RANGE="HEAD"
  [ -n "$BASE" ] && RANGE="$BASE..HEAD"

  CN=$(git rev-list --count "$RANGE" 2>/dev/null)
  CN=${CN:-0}

  echo "## 历史（范围 ${RANGE}，事实）"
  echo "commits_in_range: $CN"
  echo
  echo "### 改动最多的文件（top ${LIMIT}；热点是事实，是否震荡要人判）"
  git log "$RANGE" --format= --name-only 2>/dev/null \
    | grep -v '^$' | sort | uniq -c | sort -rn | head -n "$LIMIT"
  echo
  echo "### 提交序列（最近的先；供人数方向反转，不是反转计数）"
  git log "$RANGE" --date=short --format='%h %ad %s' 2>/dev/null | head -n "$LIMIT"
  if [ "$CN" -gt "$LIMIT" ]; then
    echo "…（共 $CN 条，只列最近 $LIMIT 条；反转计数由人做）"
  fi
  echo
  echo "# 以上均为原始事实。四值、跳数、反转次数、证据强度一律人工判定。"
else
  echo "## 历史"
  echo "跳过：没有 .git。B 轴按「反转判定不了」分支走。"
  echo
  echo "# 以上均为原始事实。四值、跳数、反转次数、证据强度一律人工判定。"
fi
