#!/usr/bin/env bash
# doc-check.sh — 文档地图与文件的对账（六项）
#
# 用法：
#   bash doc-check.sh [--root <项目根>] [--strict]
#
# 退出码：0 通过（可能有 WARN） / 1 有 FAIL（或 --strict 下有 WARN） / 64 用法错或找不到 AGENTS.md
#
# 只查能对账的部分：结构、路径、枚举值、链接。
# 不查内容质量，不判"写得对不对"——那会成为打分器。

set -u

ROOT="."
STRICT=0

while [ $# -gt 0 ]; do
  case "$1" in
    --root)
      shift
      [ $# -gt 0 ] || { echo "--root 需要一个目录参数" >&2; exit 64; }
      ROOT="$1"
      ;;
    --root=*) ROOT="${1#--root=}" ;;
    --strict) STRICT=1 ;;
    -h|--help)
      sed -n '2,12p' "$0"
      exit 0
      ;;
    *) echo "未知参数：$1" >&2; exit 64 ;;
  esac
  shift
done

[ -d "$ROOT" ] || { echo "目录不存在：$ROOT" >&2; exit 64; }
ROOT=$(cd "$ROOT" && pwd -P) || { echo "无法进入目录：$ROOT" >&2; exit 64; }

AGENTS="$ROOT/AGENTS.md"
[ -f "$AGENTS" ] || {
  echo "找不到 AGENTS.md：$AGENTS" >&2
  echo "本脚本只认 AGENTS.md 作为 L0；没有就先按 SKILL.md 第 4 步建立。" >&2
  exit 64
}

TMPROWS=$(mktemp -t doccheck.rows) || exit 64
TMPIDX=$(mktemp -t doccheck.idx) || exit 64
TMPFILES=$(mktemp -t doccheck.files) || exit 64
TMPEXCL=$(mktemp -t doccheck.excl) || exit 64
trap 'rm -f "$TMPROWS" "$TMPIDX" "$TMPFILES" "$TMPEXCL"' EXIT

FAIL=0
WARN=0

ok()    { printf '  OK    %s\n' "$1"; }
bad()   { printf '  FAIL  %s\n' "$1"; FAIL=$((FAIL+1)); }
warnf() { printf '  WARN  %s\n' "$1"; WARN=$((WARN+1)); }

# 表格首列的清洗：去空白、去反引号、把 [文字](路径) 还原成路径
clean() {
  printf '%s' "$1" | sed \
    -e 's/^[[:space:]]*//' \
    -e 's/[[:space:]]*$//' \
    -e 's/^`//' -e 's/`$//' \
    -e 's/^\[\([^]]*\)\](\([^)]*\))$/\2/'
}

echo "▶ doc-check | 根目录：$ROOT"

# ---------- 检查 1：docmap 块存在且可解析 ----------
awk '
  /<!--[ \t]*docmap:begin[ \t]*-->/ { inb=1; next }
  /<!--[ \t]*docmap:end[ \t]*-->/   { inb=0; next }
  inb { print }
' "$AGENTS" > "$TMPROWS"

awk -F'|' '
  /^[ \t]*\|/ {
    p=$2; gsub(/^[ \t]+|[ \t]+$/,"",p)
    if (p=="" || p=="路径") next
    if (p ~ /^[-: ]+$/) next
    n++
  }
  END { print n+0 }
' "$TMPROWS" > "$TMPROWS.n"

ROWCOUNT=$(cat "$TMPROWS.n")
rm -f "$TMPROWS.n"

if [ "$ROWCOUNT" -eq 0 ]; then
  bad "检查 1：AGENTS.md 里没有可解析的 docmap 块（或块内没有数据行）"
  echo ""
  echo "—— 汇总：$FAIL 项 FAIL，$WARN 项 WARN ——"
  exit 1
fi
ok "检查 1：docmap 块可解析（$ROWCOUNT 行）"

# 取每行路径，输出到 TMPROWS（一行一个）
awk -F'|' '
  /^[ \t]*\|/ {
    p=$2; gsub(/^[ \t]+|[ \t]+$/,"",p)
    if (p=="" || p=="路径") next
    if (p ~ /^[-: ]+$/) next
    print p
  }
' "$TMPROWS" > "$TMPROWS.p"
mv "$TMPROWS.p" "$TMPROWS"

# ---------- 检查 2：地图里的路径都存在 ----------
: > "$TMPIDX"
MISSING=0
while IFS= read -r raw; do
  p=$(clean "$raw")
  [ -n "$p" ] || continue
  case "$p" in
    *'*'*) continue ;;   # 通配行不做存在性判断
  esac
  q=${p%/}
  printf '%s\n' "$q" >> "$TMPIDX"
  if [ ! -e "$ROOT/$q" ]; then
    bad "检查 2：地图路径不存在：$p"
    MISSING=$((MISSING+1))
  fi
done < "$TMPROWS"
if [ "$MISSING" -eq 0 ]; then
  ok "检查 2：地图路径全部存在（$ROWCOUNT 行）"
fi

# ---------- 检查 3：仓库内 .md 都被地图覆盖或已豁免 ----------
# 豁免块：<!-- docmap:exclude:begin --> ... <!-- docmap:exclude:end -->
awk '
  /<!--[ \t]*docmap:exclude:begin[ \t]*-->/ { inb=1; next }
  /<!--[ \t]*docmap:exclude:end[ \t]*-->/   { inb=0; next }
  inb { print }
' "$AGENTS" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | grep -v '^$' | grep -v '^#' > "$TMPEXCL"

find "$ROOT" \
  \( -name .git -o -name node_modules -o -name vendor -o -name dist -o -name build -o -name .venv -o -name __pycache__ \) -prune -o \
  -type f -name '*.md' -print > "$TMPFILES"

ORPHAN=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  rel=${f#"$ROOT"/}

  skip=0
  while IFS= read -r pat; do
    [ -n "$pat" ] || continue
    # 豁免模式允许通配（如 docs/archive/*），此处刻意按 glob 匹配而非字面量
    # shellcheck disable=SC2254
    case "$rel" in $pat) skip=1; break ;; esac
  done < "$TMPEXCL"
  [ "$skip" -eq 1 ] && continue

  covered=0
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    if [ "$rel" = "$p" ]; then covered=1; break; fi
    case "$rel" in "$p"/*) covered=1; break ;; esac
  done < "$TMPIDX"

  if [ "$covered" -eq 0 ]; then
    if [ "$ORPHAN" -lt 5 ]; then
      bad "检查 3：未被地图覆盖：$rel"
    fi
    ORPHAN=$((ORPHAN+1))
  fi
done < "$TMPFILES"
if [ "$ORPHAN" -eq 0 ]; then
  ok "检查 3：所有 .md 都在地图内或已豁免"
else
  [ "$ORPHAN" -gt 5 ] && bad "检查 3：另有 $((ORPHAN-5)) 份未被覆盖（只列前 5 份）"
fi

# ---------- 检查 4：被索引的文档有元信息头 ----------
HEAD_MISS=0
while IFS= read -r p; do
  [ -n "$p" ] || continue
  case "$p" in *.md) ;; *) continue ;; esac
  [ "$p" = "AGENTS.md" ] && continue
  f="$ROOT/$p"
  [ -f "$f" ] || continue
  if awk 'NR>15{exit} index($0,"> L")==1 && index($0,"| 权威：")>0 && index($0,"不权威：")>0 {f=1} END{exit (f?0:1)}' "$f"; then
    :
  else
    if [ "$HEAD_MISS" -lt 5 ]; then
      warnf "检查 4：缺元信息头：${p}（应为 > Lx | 权威：… | 不权威：…）"
    fi
    HEAD_MISS=$((HEAD_MISS+1))
  fi
done < "$TMPIDX"
if [ "$HEAD_MISS" -eq 0 ]; then
  ok "检查 4：被索引文档都有元信息头"
elif [ "$HEAD_MISS" -gt 5 ]; then
  warnf "检查 4：另有 $((HEAD_MISS-5)) 份缺元信息头（只列前 5 份）"
fi

# ---------- 检查 5：STATUS 的状态枚举与证据列 ----------
STATUS=""
while IFS= read -r p; do
  case "$p" in *STATUS.md|*status.md) STATUS="$ROOT/$p"; break ;; esac
done < "$TMPIDX"

if [ -z "$STATUS" ] || [ ! -f "$STATUS" ]; then
  warnf "检查 5：地图里没有 STATUS.md，进度无法机检"
else
  BADST=0
  while IFS=$'	' read -r b st ev; do
    [ -n "$b" ] || continue
    case "$st" in
      未开始*|进行中*|已完成*|受阻*|已取消*) ;;
      *) bad "检查 5：状态值非法「${st}」（批次 ${b}）；只允许 未开始/进行中/已完成/受阻/已取消"
         BADST=$((BADST+1)) ;;
    esac
    case "$st" in
      已完成*)
        case "$ev" in
          ""|"-"|"—"|"待补"|"见上文"|"已测")
            bad "检查 5：批次 $b 标了已完成但证据列为空或空指代"
            BADST=$((BADST+1)) ;;
        esac ;;
    esac
  done <<EOF
$(awk -F'|' '
  /^[ \t]*\|/ {
    b=$2; gsub(/^[ \t]+|[ \t]+$/,"",b)
    if (b=="" || b=="批次") next
    if (b ~ /^[-: ]+$/) next
    st=$4; gsub(/^[ \t]+|[ \t]+$/,"",st); gsub(/`/,"",st)
    ev=$5; gsub(/^[ \t]+|[ \t]+$/,"",ev)
    print b "\t" st "\t" ev
  }' "$STATUS")
EOF
  [ "$BADST" -eq 0 ] && ok "检查 5：STATUS 状态与证据列合规"
fi

# ---------- 检查 6：文档内相对链接的目标存在 ----------
LINKBAD=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  dir=$(dirname "$f")
  grep -oE '\]\([^)]+\)' "$f" 2>/dev/null | sed -e 's/^](//' -e 's/)$//' > "$TMPROWS.l"
  while IFS= read -r t; do
    [ -n "$t" ] || continue
    case "$t" in
      http://*|https://*|mailto:*|\#*|/*) continue ;;
      *'%'*) continue ;;
    esac
    t=${t%%#*}
    [ -n "$t" ] || continue
    if [ ! -e "$dir/$t" ] && [ ! -e "$ROOT/$t" ]; then
      if [ "$LINKBAD" -lt 5 ]; then
        warnf "检查 6：死链 ${f#"$ROOT"/} → $t"
      fi
      LINKBAD=$((LINKBAD+1))
    fi
  done < "$TMPROWS.l"
done < "$TMPFILES"
rm -f "$TMPROWS.l"
if [ "$LINKBAD" -eq 0 ]; then
  ok "检查 6：文档内相对链接均可解析"
elif [ "$LINKBAD" -gt 5 ]; then
  warnf "检查 6：另有 $((LINKBAD-5)) 处死链（只列前 5 处）"
fi

# ---------- 汇总 ----------
echo ""
echo "—— 汇总：$FAIL 项 FAIL，$WARN 项 WARN ——"

if [ "$FAIL" -gt 0 ]; then exit 1; fi
if [ "$STRICT" -eq 1 ] && [ "$WARN" -gt 0 ]; then
  echo "（--strict：WARN 也算失败）"
  exit 1
fi
exit 0
