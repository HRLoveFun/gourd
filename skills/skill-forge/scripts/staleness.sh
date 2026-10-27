#!/usr/bin/env bash
# staleness.sh — skill 时效体检：锚点扫描 + TTL 兜底
#
# 用法：
#   ./skills/skill-forge/scripts/staleness.sh              # 体检全仓
#   ./skills/skill-forge/scripts/staleness.sh <name> ...   # 体检指定技能
#   ./skills/skill-forge/scripts/staleness.sh --all --network   # 额外探测 URL
#
# 退出码：0 全绿 / 1 有 WARN / 2 有 STALE / 3 无技能可检 / 64 用法错误
# CI 用法：--all 时退出码非 0 即失败。0 之外的每种码都需要人看一眼。
#
# 读的是 skills/<name>/references/SOURCES.md 里的 healthcheck 代码块。

set -u

NETWORK=0
TARGETS=""
ROOT=""

for arg in "$@"; do
  case "$arg" in
    --all) TARGETS="__ALL__" ;;
    --network|--net) NETWORK=1 ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    -*) echo "未知参数：$arg" >&2; exit 64 ;;
    *) TARGETS="${TARGETS}${arg} " ;;
  esac
done
[ -z "$TARGETS" ] && TARGETS="__ALL__"

# 仓库根：优先 git，其次脚本位置往上三级
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
[ -d "$SKILLS_DIR" ] || { echo "找不到 skills/ 目录：$SKILLS_DIR" >&2; exit 64; }

TOTAL_FAIL=0
TOTAL_WARN=0
NOW=$(date +%s)

# 跨平台转 epoch：先试 BSD，再试 GNU
to_epoch() {
  local d="$1" e=""
  e=$(date -j -f "%Y-%m-%d" "$d" +%s 2>/dev/null) || true
  if [ -z "$e" ]; then
    e=$(date -d "$d" +%s 2>/dev/null) || true
  fi
  printf '%s' "$e"
}

# 提取 healthcheck 块（```yaml 之后到 ``` 之前）
extract_block() {
  awk '
    /^```yaml/ {inb=1; next}
    inb && /^```/ {inb=0; next}
    inb {print}
  ' "$1"
}

# 取某个键的全部值（同一键可多次出现）
get_vals() {
  awk -v k="$2" '
    index($0, k":")==1 {
      v=substr($0, length(k)+2)
      sub(/^[ \t]+/, "", v); sub(/[ \t]+#.*$/, "", v); sub(/[ \t]+$/, "", v)
      if (v != "") print v
    }
  ' "$1"
}

check_skill() {
  local name="$1"
  local dir="$SKILLS_DIR/$name"
  local src="$dir/references/SOURCES.md"
  local fail=0 warn=0

  echo ""
  echo "▶ $name"

  if [ ! -d "$dir" ]; then
    echo "  STALE 技能目录不存在：skills/$name"
    TOTAL_FAIL=$((TOTAL_FAIL+1)); return
  fi
  if [ ! -f "$src" ]; then
    echo "  WARN  无 references/SOURCES.md，缺少 healthcheck 块，无法体检"
    TOTAL_WARN=$((TOTAL_WARN+1)); return
  fi

  local block; block=$(mktemp); extract_block "$src" > "$block"
  if [ ! -s "$block" ]; then
    echo "  WARN  未找到 healthcheck 代码块（\`\`\`yaml ... \`\`\`）"
    TOTAL_WARN=$((TOTAL_WARN+1)); rm -f "$block"; return
  fi

  local ver; ver=$(get_vals "$block" version | head -1)
  local reviewed; reviewed=$(get_vals "$block" last_reviewed | head -1)
  local every; every=$(get_vals "$block" review_every_days | head -1)
  [ -n "$ver" ] && echo "  version       $ver"
  [ -n "$reviewed" ] && echo "  last_reviewed $reviewed"

  # ---- 第一层：锚点扫描 ----
  # 逐行读，不用 for + 命令替换：路径或命令含空格会被拆碎
  local list; list=$(mktemp)

  get_vals "$block" anchor_path > "$list"
  while IFS= read -r p; do
    [ -z "${p}" ] && continue
    if [ -e "${ROOT}/${p}" ]; then
      echo "  OK     路径  ${p}"
    else
      echo "  STALE  路径  ${p} 已不存在（被引用方改了名或删了）"
      fail=$((fail+1))
    fi
  done < "$list"

  get_vals "$block" anchor_cmd > "$list"
  while IFS= read -r c; do
    [ -z "${c}" ] && continue
    # 锚点命令必须代表"仓库环境是否可用"，与调用方 cwd 无关。
    # 否则从别处（或软链）调用时，git 类命令会因 cwd 不是仓库而假性 STALE。
    if ( cd "${ROOT}" && eval "${c}" ) >/dev/null 2>&1; then
      echo "  OK     命令  ${c}"
    else
      echo "  STALE  命令  ${c} 执行失败（依赖缺失或参数已变）"
      fail=$((fail+1))
    fi
  done < "$list"

  get_vals "$block" anchor_url > "$list"
  while IFS= read -r u; do
    [ -z "${u}" ] && continue
    if [ "${NETWORK}" -eq 0 ]; then
      echo "  SKIP   链接  ${u} （未加 --network）"
    else
      local code
      code=$(curl -sIL --max-time 8 -o /dev/null -w '%{http_code}' "${u}" 2>/dev/null)
      case "${code}" in
        2*|3*) echo "  OK     链接  ${u} (${code})" ;;
        ""|000) echo "  WARN   链接  ${u} 无法连通（网络受限时属预期）"; warn=$((warn+1)) ;;
        *) echo "  STALE  链接  ${u} 返回 ${code}"; fail=$((fail+1)) ;;
      esac
    fi
  done < "$list"

  rm -f "$list"

  # ---- 第四层：TTL 兜底 ----
  if [ -n "$reviewed" ] && [ -n "$every" ]; then
    local re te days
    re=$(to_epoch "$reviewed")
    if [ -z "$re" ]; then
      echo "  WARN  last_reviewed 格式无法解析：${reviewed}（应为 YYYY-MM-DD）"
      warn=$((warn+1))
    else
      te=$(( (NOW - re) / 86400 ))
      days=$(( every - te ))
      # 提前告警线：周期的 15%，至少 1 天。
      # 硬编码 14 天在周期 <= 14 天时会永久告警，把 CI 拖成常态红灯。
      lead=$(( every * 15 / 100 ))
      [ "$lead" -lt 1 ] && lead=1
      if [ "$te" -gt "$every" ]; then
        echo "  STALE TTL   已 $te 天未复核（阈值 ${every}，超期 $((te-every)) 天）"
        fail=$((fail+1))
      elif [ "$days" -le "$lead" ]; then
        echo "  WARN  TTL   距下次复核还有 $days 天（$reviewed 起 ${every} 天，提前告警线 ${lead} 天）"
        warn=$((warn+1))
      else
        echo "  OK     TTL   $te/${every} 天，还有 $days 天"
      fi
    fi
  fi

  # ---- 第三层：触发记账的阈值提醒 ----
  local events
  events=$(awk '/^## 使用事件/{f=1;next} f&&/^## /{f=0} f&&/^\| 20/{print}' "$src" | wc -l | tr -d ' ')
  if [ "${events:-0}" -ge 3 ]; then
    echo "  WARN  事件  已记 $events 条使用事件，达到阈值 → 考虑 L3 重构"
    warn=$((warn+1))
  elif [ "${events:-0}" -gt 0 ]; then
    echo "  OK    事件  已记 $events 条使用事件（阈值 3）"
  fi

  # ---- 无锚点视为不可体检：不能报 OK ----
  local nanchors
  nanchors=$(get_vals "$block" anchor_path | grep -c . 2>/dev/null || true)
  local ncmd nurl
  ncmd=$(get_vals "$block" anchor_cmd | grep -c . 2>/dev/null || true)
  nurl=$(get_vals "$block" anchor_url | grep -c . 2>/dev/null || true)
  local total_anchors=$(( ${nanchors:-0} + ${ncmd:-0} + ${nurl:-0} ))
  if [ "${total_anchors}" -eq 0 ]; then
    echo "  WARN  锚点  一个都没有：事实层面的过时完全检测不到，只剩 TTL 兜底"
    warn=$((warn+1))
  fi

  # ---- 第二层：探针问题 ----
  local probes; probes=$(get_vals "$block" probe)
  if [ -n "$probes" ]; then
    echo "  ---- 探针问题（需人工核对，任一为否即前提已变）----"
    echo "$probes" | nl -ba | while IFS= read -r line; do
      echo "   $(echo "$line" | sed 's/^ *//')"
    done
  else
    echo "  WARN  探针  未声明 probe：判断层面的过时无人负责"
    warn=$((warn+1))
  fi

  rm -f "$block"
  TOTAL_FAIL=$((TOTAL_FAIL+fail))
  TOTAL_WARN=$((TOTAL_WARN+warn))
  if [ "$fail" -gt 0 ]; then
    echo "  → 结论：STALE，触发 L2 修订（改了 description 则走 L3）"
  elif [ "$warn" -gt 0 ]; then
    echo "  → 结论：WARN，可继续使用，下次复核时一并处理"
  elif [ "${total_anchors}" -eq 0 ]; then
    echo "  → 结论：无可检测项（未声明锚点，不代表没有过时）"
  else
    echo "  → 结论：OK（${total_anchors} 个锚点全部通过）"
  fi
}

if [ "$TARGETS" = "__ALL__" ]; then
  found=0
  for d in "$SKILLS_DIR"/*/; do
    [ -d "$d" ] || continue
    n=$(basename "$d")
    case "$n" in .*) continue ;; esac
    found=1
    check_skill "$n"
  done
  if [ "$found" -eq 0 ]; then
    # 空仓不等于健康：CI 里必须失败，否则删光技能反而全绿
    echo "skills/ 下没有任何技能目录。这不是通过，是没东西可检。"
    exit 3
  fi
else
  for n in $TARGETS; do check_skill "$n"; done
fi

echo ""
echo "—— 汇总：$TOTAL_FAIL 项 STALE，$TOTAL_WARN 项 WARN ——"
if [ "$TOTAL_FAIL" -gt 0 ]; then exit 2; fi
if [ "$TOTAL_WARN" -gt 0 ]; then exit 1; fi
exit 0
