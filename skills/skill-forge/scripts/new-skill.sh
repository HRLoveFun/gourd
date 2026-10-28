#!/usr/bin/env bash
# new-skill.sh — 从 template/ 起一个合规的技能骨架（阶段八）
#
# 用法：
#   ./skills/skill-forge/scripts/new-skill.sh <name> "<一句话用途>"
#
# 做四件事：复制骨架 → 填 name/description → 生成带 healthcheck 的 SOURCES.md
#           → 在 CATALOG.md 加一行（状态 草稿）。
# 不覆盖已存在的目录；不提交 git（交给人确认后自己提交）。

set -eu

if [ $# -lt 2 ]; then
  echo "用法：$0 <skill-name> \"<一句话用途>\"" >&2
  exit 64
fi

NAME="$1"
PURPOSE="$2"

case "$NAME" in
  *[!a-z0-9-]*) echo "目录名只允许英文小写字母、数字、连字符：$NAME" >&2; exit 64 ;;
  -*|*-)        echo "目录名不能以连字符开头或结尾：$NAME" >&2; exit 64 ;;
esac

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

# 仍找不到仓库标志时，说明脚本被放到了无关目录，直接报错而不是猜
if [ ! -d "$ROOT/skills" ]; then
  echo "找不到仓库根（未发现 .git 或 CATALOG.md+skills/）：$ROOT" >&2
  echo "请从 gourd 仓库内调用，或确认软链指向正确。" >&2
  exit 64
fi

TEMPLATE="$ROOT/template"
DEST="$ROOT/skills/$NAME"
TODAY=$(date +%Y-%m-%d)

[ -d "$TEMPLATE" ] || { echo "找不到模板：$TEMPLATE" >&2; exit 64; }
if [ -e "$DEST" ]; then
  echo "已存在：skills/${NAME}（不覆盖，请换名或先手动迁移）" >&2
  exit 65
fi

mkdir -p "$ROOT/skills"
cp -R "$TEMPLATE" "$DEST"
rm -f "$DEST/references/.gitkeep" "$DEST/assets/.gitkeep"

# --- 填 SKILL.md：frontmatter、正文标题、目录树里的目录名 ---
SKILL="$DEST/SKILL.md"
awk -v name="$NAME" -v desc="$PURPOSE" '
  # frontmatter 里的 name / description 只在前 10 行内替换
  NR<=10 && /^name:/        { print "name: " name; next }
  NR<=10 && /^description:/ { print "description: " desc; next }
  # 正文 H1 与目录树里的占位名
  /^# your-skill-name$/     { print "# " name; next }
  /^your-skill-name\/$/    { print name "/"; next }
  { print }
' "$SKILL" > "$SKILL.tmp" && mv "$SKILL.tmp" "$SKILL"

# 删掉模板顶部的两行提示（第二行是紧随其后的目录名提醒），以及它后面残留的空行
awk '
  /^> 这是 `template\/` 的模板/ { skip=1; next }
  skip && /^> 目录名与上面的/    { skip=0; next }
  { print }
' "$SKILL" > "$SKILL.tmp" && mv "$SKILL.tmp" "$SKILL"

# 折叠连续空行，避免提示块删除后留下三连空行
awk 'BEGIN{blank=0} /^[[:space:]]*$/{blank++; if(blank>1) next} !/^[[:space:]]*$/{blank=0} {print}' \
  "$SKILL" > "$SKILL.tmp" && mv "$SKILL.tmp" "$SKILL"

# 空目录保留占位，供后续填充（产物本来就是空目录）
for d in assets references scripts; do
  mkdir -p "$DEST/$d"
  [ -z "$(find "$DEST/$d" -type f ! -name .gitkeep 2>/dev/null)" ] && : > "$DEST/$d/.gitkeep"
done

# --- 生成带 healthcheck 的 SOURCES.md ---
cat > "$DEST/references/SOURCES.md" <<EOF
# 资料来源（MLA 格式）

本技能参考过的资料，只记**引用与链接**，不放原文。

## 本技能用到的资料

- 待填：按 MLA 格式补上实际参考过的资料；没真正用到的不要列。

## 使用事件

只记三类异常（漏触发 / 误触发 / 卡壳），一行一次。同类累计 3 次触发 L3 重构；单次导致错误产出立即 L2。判据见 \`skills/skill-forge/SKILL.md\` 阶段九。

| 日期 | 类型 | 说明 |
| --- | --- | --- |
| （暂无） | - | 新建，尚无事件 |

## healthcheck

\`skills/skill-forge/scripts/staleness.sh\` 读这个块。\`anchor_path\` 相对**仓库根目录**；日期一律 \`YYYY-MM-DD\`。

> 只锚**本技能依赖的外部前提**，不要锚本技能自己的产物（否则永远自洽，等于没检查）。

\`\`\`yaml
# 周期按"多久会变"选：每周会改 5-7；移植或按版本发版 30；长期不改 30-60
review_every_days: 5
last_reviewed: $TODAY
version: 0.1.0

# 本技能引用的仓库内文件或外部路径（全路径，相对仓库根）
# anchor_path: template/SKILL.md

# 本技能依赖的命令（只放版本无关的探测）
# anchor_cmd: bash --version

# 本技能依赖的规范或文档链接（staleness.sh 加 --network 才探测）
# anchor_url: https://example.com/spec

# 每条一个能被"是/否"回答的前提核对题；任一为否即前提已变
# probe: 该规范是否仍然要求 X
\`\`\`

> 上面带 \`#\` 的行只是示例，**请替换成本技能真实依赖**。全是注释时，TTL 兜底会成为唯一检测手段。
EOF

# --- CATALOG 登记：插在表格最后一行之后，不动表下的说明 ---
CATALOG="$ROOT/CATALOG.md"
if [ -f "$CATALOG" ] && ! grep -q "| ${NAME} " "$CATALOG"; then
  awk -v row="| ${NAME} | ${PURPOSE} | [skills/${NAME}/](skills/${NAME}/) | 草稿 |" '
    # 占位行整行删掉
    /^\| （暂无）/ { next }
    { lines[NR]=$0 }
    END {
      last=0
      for (i=1; i<=NR; i++) if (lines[i] ~ /^\|/) last=i
      for (i=1; i<=NR; i++) {
        print lines[i]
        if (i==last) print row
      }
    }
  ' "$CATALOG" > "$CATALOG.tmp" && mv "$CATALOG.tmp" "$CATALOG"
fi

chmod +x "$DEST"/scripts/*.sh 2>/dev/null || true

echo "已创建 skills/$NAME/"
echo ""
echo "接下来："
echo "  1. 补 frontmatter 的 description：做什么 + 什么时候用（用户真实说法）+ 不适用于什么"
echo "  2. 逐节替换 SKILL.md 正文，删掉与本技能无关的小节"
echo "  3. 填 references/SOURCES.md 的 MLA 引用与 healthcheck 锚点、探针"
echo "  4. 跑闸门 C：./skills/skill-forge/scripts/lint-skill.sh $NAME"
echo "  5. 通过后：git add -A && git commit -m \"add: $NAME\""
