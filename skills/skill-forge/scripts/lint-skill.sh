#!/usr/bin/env bash
# lint-skill.sh — 仓库约定合规检查（闸门 C）
#
# 用法：
#   ./skills/skill-forge/scripts/lint-skill.sh <name> [<name> ...]
#   ./skills/skill-forge/scripts/lint-skill.sh --all
#
# 退出码：0 全过 / 1 有 FAIL（不可提交） / 64 用法错误
# WARN 不影响退出码，但需在提交说明里讲清为什么不改。

set -u

ALL=0
NAMES=""
for arg in "$@"; do
  case "$arg" in
    --all) ALL=1 ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    -*) echo "未知参数：$arg" >&2; exit 64 ;;
    *) NAMES="${NAMES}${arg} " ;;
  esac
done

if ROOT=$(git rev-parse --show-toplevel 2>/dev/null); then
  :
else
  ROOT=$(cd "$(dirname "$0")/../../.." 2>/dev/null && pwd) || ROOT=$(pwd)
fi
SKILLS_DIR="$ROOT/skills"
[ -d "$SKILLS_DIR" ] || { echo "找不到 skills/ 目录：$SKILLS_DIR" >&2; exit 64; }

if [ "$ALL" -eq 1 ] || [ -z "$NAMES" ]; then
  NAMES=""
  for d in "$SKILLS_DIR"/*/; do
    [ -d "$d" ] || continue
    n=$(basename "$d")
    case "$n" in .*) continue ;; esac
    NAMES="${NAMES}${n} "
  done
fi

TOTAL_FAIL=0
TOTAL_WARN=0

# 取 frontmatter 里某个键的值
fm_val() {
  awk -v k="$2" '
    NR==1 && $0!="---" {exit}
    NR==1 {next}
    $0=="---" {exit}
    index($0, k":")==1 {
      v=substr($0, length(k)+2); sub(/^[ \t]+/, "", v); sub(/[ \t]+$/, "", v)
      print v; exit
    }
  ' "$1"
}

# frontmatter 行数（--- 到 --- 之间）
fm_lines() {
  awk 'NR==1&&$0=="---"{s=1;next} s&&$0=="---"{print n;exit} s{n++}' "$1"
}

lint_one() {
  local name="$1"
  local dir="$SKILLS_DIR/$name"
  local skill="$dir/SKILL.md"
  local fail=0 warn=0

  echo ""
  echo "▶ $name"

  ok()   { echo "  OK    $1"; }
  bad()  { echo "  FAIL  $1"; fail=$((fail+1)); }
  warnf(){ echo "  WARN  $1"; warn=$((warn+1)); }

  # 1. 目录名规范
  case "$name" in
    *[!a-z0-9-]*) bad "目录名只允许英文小写字母、数字、连字符：$name" ;;
    -*|*-) bad "目录名不能以连字符开头或结尾：$name" ;;
    *) ok "目录名规范" ;;
  esac

  if [ ! -f "$skill" ]; then
    bad "缺少 SKILL.md"
    TOTAL_FAIL=$((TOTAL_FAIL+fail)); return
  fi

  # 2. frontmatter 存在且闭合
  if [ "$(head -1 "$skill")" != "---" ]; then
    bad "SKILL.md 首行必须是 ---（YAML frontmatter）"
    TOTAL_FAIL=$((TOTAL_FAIL+fail)); return
  fi
  if [ "$(fm_lines "$skill")" = "" ]; then
    bad "frontmatter 未闭合（缺第二个 ---）"
    TOTAL_FAIL=$((TOTAL_FAIL+fail)); return
  fi
  ok "frontmatter 闭合"

  # 3. name 与目录名一致
  local nm; nm=$(fm_val "$skill" name)
  if [ -z "$nm" ]; then
    bad "frontmatter 缺 name"
  elif [ "$nm" != "$name" ]; then
    bad "name（${nm}）与目录名（${name}）不一致"
  else
    ok "name 与目录名一致"
  fi

  # 4. description 质量
  local ds; ds=$(fm_val "$skill" description)
  if [ -z "$ds" ]; then
    bad "frontmatter 缺 description"
  else
    local len=${#ds}
    if [ "$len" -lt 30 ]; then
      bad "description 过短（${len} 字符），说不清触发场景"
    elif [ "$len" -gt 1024 ]; then
      bad "description 过长（${len} 字符），超出约 1024 字符的常见上限"
    else
      ok "description 长度 ${len} 字符"
    fi
    # 触发场景关键词
    local hit=0
    for kw in 时使用 时用 用于 适用于 当用户 使用；; do
      case "$ds" in *"$kw"*) hit=1;; esac
    done
    if [ "$hit" -eq 0 ]; then
      bad "description 未写触发场景（建议写成：做X。当用户说「…」时使用）"
    else
      ok "description 含触发场景"
    fi
    # 边界
    case "$ds" in
      *不适用*|*不用于*|*别用*|*不要用于*) ok "description 含边界说明" ;;
      *) warnf "description 未写「不适用于…」边界，易误触发" ;;
    esac
  fi

  # 5. 行数上限
  local lines; lines=$(wc -l < "$skill" | tr -d ' ')
  if [ "$lines" -gt 500 ]; then
    bad "SKILL.md ${lines} 行，超出 500 行上限 → 该把逻辑挪进 scripts/ 或 references/"
  else
    ok "SKILL.md ${lines} 行"
  fi

  # 6. 九节骨架（缺节只 WARN，因模板允许按需删节）
  for sec in 用途 文件结构 输入 输出 依赖 使用方法 注意事项 来源与许可证; do
    if grep -q "^## ${sec}" "$skill"; then :; else
      warnf "缺小节「## ${sec}」（若刻意删节，请在提交说明里讲明）"
    fi
  done

  # 7. SOURCES.md 与 healthcheck
  local src="$dir/references/SOURCES.md"
  if [ -f "$src" ]; then
    ok "有 references/SOURCES.md"
    local blk
    blk=$(awk '/^```yaml/{i=1;next} i&&/^```/{i=0;next} i{print}' "$src")
    if [ -z "$blk" ]; then
      bad "SOURCES.md 缺 healthcheck 代码块（无法体检时效）"
    else
      ok "有 healthcheck 块"
      for key in review_every_days last_reviewed version; do
        if printf '%s\n' "$blk" | grep -q "^${key}:"; then :; else
          bad "healthcheck 缺 ${key}:"
        fi
      done
      if printf '%s\n' "$blk" | grep -q '^last_reviewed:'; then
        local d; d=$(printf '%s\n' "$blk" | awk '/^last_reviewed:/{print $2}')
        if printf '%s' "$d" | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
          ok "last_reviewed 格式 ${d}"
        else
          bad "last_reviewed 须为 YYYY-MM-DD：$d"
        fi
      fi
      if printf '%s\n' "$blk" | grep -q '^anchor_'; then
        ok "已声明锚点"
      else
        warnf "healthcheck 无任何 anchor_*，TTL 兜底将是唯一检测手段"
      fi
      if printf '%s\n' "$blk" | grep -q '^probe:'; then
        ok "有探针问题"
      else
        warnf "healthcheck 无 probe:，判断层面的过时无人负责"
      fi
    fi
  else
    bad "缺 references/SOURCES.md（用于记引用与 healthcheck）"
  fi

  # 8. 目录自包含：不得指向仓库根的散文件
  local stray
  stray=$(grep -oE '\]\(\.\./\.\./[^)]+\)' "$skill" 2>/dev/null | sed 's/](\.\.\/\.\.\///;s/)$//' | sort -u)
  if [ -n "$stray" ]; then
    for f in $stray; do
      if [ -e "$ROOT/$f" ]; then
        warnf "引用仓库根文件 ${f}（跨目录引用，根文件改名会让本技能失效）"
      fi
    done
  fi

  # 9. 敏感信息
  if grep -Eqi '(api[_-]?key|secret|token|password)[[:space:]]*[:=][[:space:]]*[A-Za-z0-9_\-]{12,}' "$skill"; then
    bad "疑似包含密钥明文，禁止入库"
  else
    ok "无密钥明文"
  fi

  # 10. 大文件
  local big
  big=$(find "$dir" -type f -size +200k 2>/dev/null)
  if [ -n "$big" ]; then
    warnf "存在超 200KB 文件，除非确有必要否则改留链接：$(echo "$big" | tr '\n' ' ')"
  else
    ok "无超 200KB 文件"
  fi

  # 11. scripts/ 可执行位
  if [ -d "$dir/scripts" ]; then
    for f in "$dir"/scripts/*.sh; do
      [ -e "$f" ] || continue
      if [ -x "$f" ]; then :; else warnf "脚本无可执行位：scripts/$(basename "$f")"; fi
    done
  fi

  # 12. .gitkeep 是否还留着（有真实内容就该删）
  for k in "$dir"/assets/.gitkeep "$dir"/references/.gitkeep "$dir"/scripts/.gitkeep; do
    [ -f "$k" ] || continue
    local parent; parent=$(dirname "$k")
    local cnt; cnt=$(find "$parent" -type f ! -name .gitkeep | wc -l | tr -d ' ')
    if [ "$cnt" -gt 0 ]; then
      warnf "$(basename "$parent")/.gitkeep 可删（目录已有真实内容）"
    fi
  done

  # 13. CATALOG 是否登记
  if [ -f "$ROOT/CATALOG.md" ]; then
    if grep -q "skills/$name/" "$ROOT/CATALOG.md" 2>/dev/null || grep -q "| $name " "$ROOT/CATALOG.md"; then
      ok "CATALOG.md 已登记"
    else
      bad "CATALOG.md 未登记该技能"
    fi
  fi

  TOTAL_FAIL=$((TOTAL_FAIL+fail))
  TOTAL_WARN=$((TOTAL_WARN+warn))
  if [ "$fail" -gt 0 ]; then
    echo "  → 闸门 C：不通过（$fail 项 FAIL）"
  elif [ "$warn" -gt 0 ]; then
    echo "  → 闸门 C：通过，但有 $warn 项 WARN"
  else
    echo "  → 闸门 C：通过"
  fi
}

for n in $NAMES; do lint_one "$n"; done

echo ""
echo "—— 汇总：$TOTAL_FAIL 项 FAIL，$TOTAL_WARN 项 WARN ——"
if [ "$TOTAL_FAIL" -gt 0 ]; then exit 1; fi
exit 0
