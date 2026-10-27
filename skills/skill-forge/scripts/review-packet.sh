#!/usr/bin/env bash
# review-packet.sh — 生成"复核包"正文（Markdown），供开 Issue 或本地查看
#
# 用法：
#   ./skills/skill-forge/scripts/review-packet.sh            # 全仓，输出全部到复核的
#   ./skills/skill-forge/scripts/review-packet.sh <name>     # 指定技能
#   ... --force-due      # 忽略日期强制当做到期（验证正文）
#   ... --dry-run        # 标注为预览
#
# 退出码：0 = 有到期项且已输出正文 / 1 = 今日无到期项 / 64 = 用法错误
# 调用方按退出码判断是否开 Issue，不要靠输出是否为空来判断
# （空正文 = 不需要开 Issue，调用方据此判断）。
#
# 设计要点：
#   - 只推"内容"，不推"时间到了"。正文含 description、接口摘要、探针清单、期间改动
#   - 关闭 Issue 即视为复核完成（时间戳可审计），不需要手工改日期才算数

set -u

DRY=0
FORCE=0
TARGETS=""
for arg in "$@"; do
  case "$arg" in
    --dry-run)   DRY=1 ;;      # 仅本地打印，不改变退出码语义
    --force-due) FORCE=1 ;;    # 忽略日期，强制当做到期（验证正文用）
    -h|--help)   sed -n '2,14p' "$0"; exit 0 ;;
    -*)          echo "未知参数：${arg}" >&2; exit 64 ;;
    *)           TARGETS="${TARGETS}${arg} " ;;
  esac
done
[ -z "$TARGETS" ] && TARGETS="__ALL__"
TARGETS="${TARGETS% }"

# ---- 定位仓库根 ----
# 难点：脚本可能被符号链接到仓库外（如 ~/.agents/skills/），
# 此时 dirname "$0" 得到的是链接所在目录，不是真实位置。
# 做法：先穿透符号链接还原真实路径，再从该目录向上找仓库标志，
# 找不到才退回 git / cwd。这样软链与直接调用行为一致。
resolve_root() {
  local src="$1" dir i=0
  while [ -L "$src" ]; do
    dir=$(cd -P "$(dirname "$src")" 2>/dev/null && pwd) || break
    src=$(readlink "$src")
    case "$src" in
      /*) ;;
      *) src="$dir/$src" ;;
    esac
  done
  dir=$(cd -P "$(dirname "$src")" 2>/dev/null && pwd) || return 1
  ROOT="$dir"
  while [ "$i" -lt 6 ]; do
    # 仓库标志：有 .git，或有 CATALOG.md 与 skills/
    if [ -d "$ROOT/.git" ] || { [ -f "$ROOT/CATALOG.md" ] && [ -d "$ROOT/skills" ]; }; then
      return 0
    fi
    ROOT=$(dirname "$ROOT")
    i=$((i+1))
  done
  return 1
}

if ! resolve_root "$0"; then
  if ROOT=$(git rev-parse --show-toplevel 2>/dev/null); then
    :
  else
    ROOT=$(pwd)
  fi
fi

SKILLS_DIR="$ROOT/skills"
[ -d "$SKILLS_DIR" ] || { echo "找不到 skills/ 目录" >&2; exit 64; }

NOW=$(date +%Y-%m-%d)
TOTAL_EPOCH=$(date +%s)

to_epoch() {
  local d="$1" e=""
  e=$(date -j -f "%Y-%m-%d" "$d" +%s 2>/dev/null) || true
  [ -z "$e" ] && e=$(date -d "$d" +%s 2>/dev/null) || true
  printf '%s' "$e"
}

# val/vals 接收 SOURCES.md 路径，内部只在实际的 yaml 块里查找
val() {
  awk -v k="$2" '
    /^```yaml/ {i=1;next} i&&/^```/ {i=0;next}
    i && index($0,k":")==1 {
      v=substr($0,length(k)+2); sub(/^[ \t]+/,"",v); sub(/[ \t]+#.*$/,"",v); sub(/[ \t]+$/,"",v)
      if(v!=""){print v;exit}
    }' "$1"
}
vals() {
  awk -v k="$2" '
    /^```yaml/ {i=1;next} i&&/^```/ {i=0;next}
    i && index($0,k":")==1 {
      v=substr($0,length(k)+2); sub(/^[ \t]+/,"",v); sub(/[ \t]+#.*$/,"",v); sub(/[ \t]+$/,"",v)
      if(v!="")print v
    }' "$1"
}
fm() {     # 取 frontmatter 字段
  awk -v k="$2" 'NR==1&&$0=="---"{s=1;next} s&&$0=="---"{exit} s&&index($0,k":")==1{v=substr($0,length(k)+2);sub(/^[ \t]+/,"",v);sub(/[ \t]+$/,"",v);print v;exit}' "$1"
}

# 收集到期技能
DUE=""
if [ "$TARGETS" = "__ALL__" ]; then
  for d in "$SKILLS_DIR"/*/; do
    [ -d "$d" ] || continue
    n=$(basename "$d"); case "$n" in .*) continue ;; esac
    src="$d/references/SOURCES.md"; [ -f "$src" ] || continue
    lr=$(val "$src" last_reviewed); ev=$(val "$src" review_every_days)
    [ -n "$lr" ] && [ -n "$ev" ] || continue
    le=$(to_epoch "$lr"); [ -n "$le" ] || continue
    te=$(( (TOTAL_EPOCH - le) / 86400 ))
    if [ "$FORCE" -eq 1 ] || [ "$te" -ge "$ev" ]; then DUE="$DUE$n "; fi
  done
else
  DUE="$TARGETS "
fi

if [ -z "$DUE" ]; then
  exit 1     # 1 = 今日无到期项（不是错误）
fi

# ---- 拼正文 ----
[ "$DRY" -eq 1 ] && echo "> **DRY-RUN**：以下为预览，未提交到 GitHub。"
[ "$DRY" -eq 1 ] && echo ""
echo "## 复核到期"
echo ""
echo "> 这是自动推送的**复核内容**，不是时间提醒。逐条核对下列前提是否仍成立；"
echo "> 全部为「是」→ 更新 \`last_reviewed\` 后**关闭本 Issue**（关闭时间即复核记录）。"
echo "> 任一条为「否」→ 前提已变，按 \`skills/skill-forge/SKILL.md\` 阶段九走 L2（改流程）或 L3（改 description）。"
echo ""

for n in $DUE; do
  d="$SKILLS_DIR/$n"; sk="$d/SKILL.md"; src="$d/references/SOURCES.md"
  [ -f "$sk" ] || continue
  lr=$(val "$src" last_reviewed); ev=$(val "$src" review_every_days)
  te=$(( (TOTAL_EPOCH - $(to_epoch "$lr")) / 86400 ))

  echo "---"
  echo ""
  echo "### \`$n\` — 距上次复核 $te 天（阈值 ${ev}）"
  echo ""
  echo "**接口**（这两处说的事必须一致）："
  echo ""
  echo '```'
  echo "description: $(fm "$sk" description)"
  echo ""
  grep -m1 '^\*\*接口摘要\*\*' "$sk" 2>/dev/null || echo "接口摘要：（缺失）"
  echo '```'
  echo ""

  probes=$(vals "$src" probe)
  if [ -n "$probes" ]; then
    echo "**请逐条核对**（任一为「否」即前提已变）："
    echo ""
    echo "$probes" | while IFS= read -r p; do
      [ -n "$p" ] && printf -- '- [ ] %s\n' "$p"
    done
  else
    echo "**探针缺失**：该技能未声明 \`probe:\`，判断层面的过时无人负责。"
  fi
  echo ""

  # 期间改动：这是判断"要不要顺便复核"的关键信息
  echo "**上次复核后的改动**："
  echo ""
  chg=$(git -C "$ROOT" log --since="$lr 00:00:00" --oneline -- "skills/$n/" 2>/dev/null | head -10)
  if [ -z "$chg" ]; then
    echo "- 无改动（说明上限仍是原值，可快速确认后关闭）"
  else
    echo "$chg" | while IFS= read -r line; do echo "- $line"; done
  fi
  echo ""
done

echo "---"
echo ""
echo "**核对完成后**：把每个技能的 \`references/SOURCES.md\` 中 \`last_reviewed\` 改为 \`$NOW\`，提交，再关闭本 Issue。"
echo ""
echo "<sub>由 \`skills/skill-forge/scripts/review-packet.sh\` 生成于 $NOW</sub>"
