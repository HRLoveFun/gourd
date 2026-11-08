#!/usr/bin/env bash
# doc-check.test.sh — doc-check.sh 的回归测试
#
# 用法：
#   bash doc-check.test.sh
#
# 环境变量：DOC_CHECK=<路径> 换一份被测脚本，默认用同目录的 doc-check.sh。
# 退出码：0 全部通过 / 1 有失败
#
# 夹具全部现场生成，跑完即删。本文件只在技能仓库里跑，不拷进项目。
# 每条报错路径都要走到：bash 3.2 下变量紧跟中文会把字节算进变量名，
# 这种崩溃只有运行到那一行才暴露，shellcheck 查不出来。

set -u

HERE=$(cd "$(dirname "$0")" && pwd -P)
CHECK=${DOC_CHECK:-"$HERE/doc-check.sh"}
WORK=$(mktemp -d "${TMPDIR:-/tmp}/doccheck-test.XXXXXX") || exit 1
trap 'rm -rf "$WORK"' EXIT

PASS=0
FAILED=0
SEQ=0
OUT=""
CODE=0
PROJECT=""
HEAD_L1='> L1 | 权威：x | 不权威：y'
HEAD_L2='> L2 | 权威：x | 不权威：y'

# ---------- 断言 ----------

# run <项目目录> [参数...]：运行被测脚本，记下输出与退出码
run() {
  local dir=$1
  shift
  OUT=$(bash "$CHECK" --root "$dir" "$@" 2>&1)
  CODE=$?
}

report() {
  local name=$1 miss=$2
  if [ -z "$miss" ]; then
    PASS=$((PASS+1))
  else
    FAILED=$((FAILED+1))
    printf '  FAIL  %s：%s\n' "$name" "$miss"
    printf '%s\n' "$OUT" | sed 's/^/        | /'
  fi
}

# expect <用例名> <期望退出码> [输出必须包含的片段...]
expect() {
  local name=$1 want=$2 miss="" s
  shift 2
  [ "$CODE" -eq "$want" ] || miss="退出码 ${CODE}，期望 ${want}"
  for s in "$@"; do
    case "$OUT" in
      *"$s"*) ;;
      *) miss="${miss:+${miss}；}缺少「${s}」" ;;
    esac
  done
  report "$name" "$miss"
}

# refute <用例名> <输出不得包含的片段...>
refute() {
  local name=$1 miss="" s
  shift
  for s in "$@"; do
    case "$OUT" in
      *"$s"*) miss="${miss:+${miss}；}不该出现「${s}」" ;;
    esac
  done
  report "$name" "$miss"
}

# clean <用例名>：退出码 0，且没有任何 FAIL 与 WARN
clean() {
  expect "$1（退出码）" 0
  refute "$1（无告警）" 'FAIL  ' 'WARN  '
}

# ---------- 夹具 ----------

reset_vocab() {
  T_TOPIC='- 【产品】用户可见的内容：【产品-概览】
- 【流程】开发流程：【流程-入口】
- 【进度】批次与状态：【进度-批次】'
  T_READ='- 【上手项目】第一次了解
- 【开工】开始任务
- 【加功能】新增功能'
  T_WRITE='- 【结构变化】文档结构变化
- 【批次收尾】一批任务结束
- 【用法变化】对外用法变化
- 【增删模块】模块变化'
  T_EXCLUDE='# 一行一个 glob'
}

ROWS_ROOT='- `AGENTS.md` L0 — 关于【流程-入口】；在【上手项目】时读；在【结构变化】时改
- `DOC_MAP.md` L0 — 关于【流程-入口】；在【上手项目】时读；在【结构变化】时改
- `README.md` L1 — 关于【产品-概览】；在【上手项目】时读；在【用法变化】时改
- `STATUS.md` L1 — 关于【进度-批次】；在【开工】时读；在【批次收尾】时改'

# new_project [目录名]：建最小档项目，目录写入 PROJECT
new_project() {
  SEQ=$((SEQ+1))
  PROJECT="$WORK/${1:-p$SEQ}"
  mkdir -p "$PROJECT"
  reset_vocab
  printf '# 项目\n\n进度看 STATUS.md。\n' > "$PROJECT/AGENTS.md"
  printf '# 项目\n\n一句话定位。\n\n%s\n' "$HEAD_L1" > "$PROJECT/README.md"
  printf '# 状态\n\n%s\n\n| 批次 | 目标 | 状态 | 证据 | 更新日期 |\n| --- | --- | --- | --- | --- |\n| F1 | 建库 | 进行中 | - | 2026-11-08 |\n' \
    "$HEAD_L1" > "$PROJECT/STATUS.md"
}

# write_map <文档行>：按当前词表写 DOC_MAP.md
write_map() {
  {
    printf '# 文档地图\n\n> L0 | 权威：x | 不权威：y\n\n'
    printf '<!-- doctags:begin -->\n\n### 主题标签（关于）\n\n%s\n\n### 时机标签（何时读）\n\n%s\n\n### 修改事件（何时改）\n\n%s\n\n<!-- doctags:end -->\n\n' \
      "$T_TOPIC" "$T_READ" "$T_WRITE"
    printf '<!-- docmap:begin -->\n\n## 根目录\n\n%s\n\n<!-- docmap:end -->\n\n' "$1"
    printf '<!-- docmap:exclude:begin -->\n%s\n<!-- docmap:exclude:end -->\n' "$T_EXCLUDE"
  } > "$PROJECT/DOC_MAP.md"
}

# add_doc <相对路径> [头信息]：建一份带头信息的文档
add_doc() {
  mkdir -p "$(dirname "$PROJECT/$1")"
  printf '# 文档\n\n%s\n' "${2:-$HEAD_L2}" > "$PROJECT/$1"
}

# std_project：建带地图的合规项目
std_project() {
  new_project "$@"
  write_map "$ROWS_ROOT"
}

# large_project "<父级:份数> ..." [追加的词表行]：按分布生成文档与地图，根目录四行归入父级“甲”
large_project() {
  local spec p n k i=0 rows topics
  new_project
  topics='- 【甲】入口：【甲-入口】'
  rows='- `AGENTS.md` L0 — 关于【甲-入口】；在【上手项目】时读；在【结构变化】时改
- `DOC_MAP.md` L0 — 关于【甲-入口】；在【上手项目】时读；在【结构变化】时改
- `README.md` L1 — 关于【甲-入口】；在【上手项目】时读；在【用法变化】时改
- `STATUS.md` L1 — 关于【甲-入口】；在【开工】时读；在【批次收尾】时改'
  for spec in $1; do
    p=${spec%%:*}
    n=${spec##*:}
    topics="${topics}
- 【${p}】说明：【${p}-子】"
    k=0
    while [ "$k" -lt "$n" ]; do
      i=$((i+1))
      k=$((k+1))
      add_doc "docs/d${i}.md"
      rows="${rows}
- \`docs/d${i}.md\` L2 — 关于【${p}-子】；在【加功能】时读；在【增删模块】时改"
    done
  done
  T_TOPIC="${topics}${2:+
$2}"
  write_map "$rows"
}

# pad_vocab <总行数>：用空行把 doctags 块撑到指定行数
pad_vocab() {
  awk -v want="$1" '
    FNR == NR {
      if (/doctags:begin/) inb = 1
      else if (/doctags:end/) inb = 0
      else if (inb) n++
      next
    }
    /doctags:end/ { for (i = n; i < want; i++) print "" }
    { print }
  ' "$PROJECT/DOC_MAP.md" "$PROJECT/DOC_MAP.md" > "$PROJECT/DOC_MAP.tmp"
  mv "$PROJECT/DOC_MAP.tmp" "$PROJECT/DOC_MAP.md"
}

# agents_lines <行数>：把 AGENTS.md 撑到指定行数
agents_lines() {
  awk -v n="$1" 'BEGIN { for (i = 1; i <= n; i++) print "# 行" i }' > "$PROJECT/AGENTS.md"
}

# read_vocab <个数>：生成指定数量的时机标签，保留【上手项目】【开工】【加功能】
read_vocab() {
  local i=3
  T_READ='- 【上手项目】第一次了解
- 【开工】开始任务
- 【加功能】新增功能'
  while [ "$i" -lt "$1" ]; do
    i=$((i+1))
    T_READ="${T_READ}
- 【时机${i}】说明"
  done
}

# ---------- 用法 ----------

OUT=$(bash "$CHECK" --root "$WORK/不存在" 2>&1); CODE=$?
expect '根目录不存在' 64 '目录不存在'
OUT=$(bash "$CHECK" --root 2>&1); CODE=$?
expect '--root 缺参数' 64 '--root 需要'
OUT=$(bash "$CHECK" --bogus 2>&1); CODE=$?
expect '未知参数' 64 '未知参数'
OUT=$(bash "$CHECK" --help 2>&1); CODE=$?
expect '--help' 0 '用法'
new_project; rm "$PROJECT/AGENTS.md"; run "$PROJECT"
expect '缺 AGENTS.md' 64 '找不到 AGENTS.md'

# ---------- 最小档：没有 DOC_MAP.md ----------

new_project; run "$PROJECT"
clean '最小档合规'
expect '最小档有说明' 0 '最小档'

new_project; rm "$PROJECT/STATUS.md" "$PROJECT/README.md"; run "$PROJECT"
expect '只有 AGENTS.md' 0 '检查 5'

new_project; add_doc docs/x.md; run "$PROJECT"
expect '最小档多出文档' 1 '超出进门三件：docs/x.md' 'DOC_MAP.md'

new_project; for i in 1 2 3 4 5 6 7; do add_doc "docs/d$i.md"; done; run "$PROJECT"
expect '最小档多出文档时只列前 5 条' 1 '另有 2 条' '汇总：7 项 FAIL'

new_project; add_doc .codebuddy/commands/a.md; run "$PROJECT"
clean '最小档跳过隐藏目录'

new_project
printf '\n<!-- docmap:begin -->\n| 路径 | 层 |\n| --- | --- |\n| 旧.md | L1 |\n<!-- docmap:end -->\n' >> "$PROJECT/AGENTS.md"
run "$PROJECT"
clean '旧 docmap 块不再有含义'

# ---------- 检查 1–3：地图与文件 ----------

std_project; run "$PROJECT"
clean '标准档合规'

new_project
printf '# 文档地图\n\n> L0 | 权威：x | 不权威：y\n\n没有标记。\n' > "$PROJECT/DOC_MAP.md"
run "$PROJECT"
expect '检查 1 缺 docmap 块' 1 '检查 1' '没有可解析'
refute '检查 1 失败后不再往下查' '检查 2'

new_project
write_map "${ROWS_ROOT}
- \`docs/none.md\` L2 — 关于【产品-概览】；在【加功能】时读；在【增删模块】时改"
run "$PROJECT"
expect '检查 2 路径不存在' 1 '地图路径不存在：docs/none.md'

std_project; add_doc docs/x.md; run "$PROJECT"
expect '检查 3 未覆盖' 1 '未被地图覆盖：docs/x.md'

std_project; for i in 1 2 3 4 5 6 7; do add_doc "docs/d$i.md"; done; run "$PROJECT"
expect '检查 3 只列前 5 条' 1 '另有 2 条'

std_project; for i in 1 2 3 4 5 6; do add_doc "docs/d$i.md"; done; run "$PROJECT"
expect '检查 3 六条时另有 1 条' 1 '另有 1 条'

std_project; for i in 1 2 3 4 5; do add_doc "docs/d$i.md"; done; run "$PROJECT"
refute '检查 3 五条时不折叠' '另有'

new_project
T_EXCLUDE='# 注释
reports/*.md'
write_map "$ROWS_ROOT"
add_doc reports/a.md; run "$PROJECT"
clean '检查 3 豁免 glob'

new_project
write_map "${ROWS_ROOT}
- \`archive/\` L3 — 关于【产品-概览】；在【开工】时读；在【批次收尾】时改"
add_doc archive/old.md "> 没有头信息"; run "$PROJECT"
clean '检查 3 目录行覆盖'

std_project; add_doc .github/a.md; add_doc node_modules/b.md; run "$PROJECT"
clean '检查 3 跳过隐藏目录和 node_modules'

std_project; ln -s AGENTS.md "$PROJECT/CLAUDE.md"; run "$PROJECT"
clean '检查 3 跳过软链'

std_project .dotted; add_doc docs/x.md; run "$PROJECT"
expect '根目录名以点开头仍能扫描' 1 '未被地图覆盖：docs/x.md'

std_project '带 空格'; add_doc docs/x.md; run "$PROJECT"
expect '根目录含空格' 1 '未被地图覆盖：docs/x.md'

new_project
printf 'all:\n' > "$PROJECT/Makefile"
write_map "${ROWS_ROOT}
- \`Makefile\` L1 — 关于【流程-入口】；在【开工】时读；在【结构变化】时改"
run "$PROJECT"
clean '检查 2 可收录非 md 权威文件'

# ---------- 检查 4：文档头 ----------

new_project; printf '# 项目\n' > "$PROJECT/README.md"; write_map "$ROWS_ROOT"; run "$PROJECT"
expect '检查 4 缺文档头是 WARN' 0 '缺元信息头：README.md'
run "$PROJECT" --strict
expect '--strict 把 WARN 变成失败' 1 '--strict'

large_project '乙:7'
for i in 1 2 3 4 5 6 7; do printf '# 文档\n' > "$PROJECT/docs/d$i.md"; done
run "$PROJECT"
expect '检查 4 只列前 5 条，汇总按真实条数' 0 '另有 2 条' '7 项 WARN'

new_project; add_doc docs/x.md "$HEAD_L1"
write_map "${ROWS_ROOT}
- \`docs/x.md\` L2 — 关于【产品-概览】；在【加功能】时读；在【增删模块】时改"
run "$PROJECT"
expect '检查 4 层不一致' 0 '层不一致：docs/x.md' 'L2' 'L1'

new_project
{ printf '# 项目\n'; for i in 2 3 4 5 6 7 8 9 10 11 12 13 14; do printf '第 %s 行\n' "$i"; done; printf '%s\n' "$HEAD_L1"; } > "$PROJECT/README.md"
write_map "$ROWS_ROOT"; run "$PROJECT"
clean '检查 4 第 15 行的文档头有效'

new_project
{ printf '# 项目\n'; for i in 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do printf '第 %s 行\n' "$i"; done; printf '%s\n' "$HEAD_L1"; } > "$PROJECT/README.md"
write_map "$ROWS_ROOT"; run "$PROJECT"
expect '检查 4 第 16 行的文档头无效' 0 '缺元信息头：README.md'

# ---------- 检查 5：STATUS ----------

new_project
printf '| 批次 | 目标 | 状态 | 证据 | 更新日期 |\n| --- | --- | --- | --- | --- |\n| F1 | x | 基本完成 | - | 2026-11-08 |\n' >> "$PROJECT/STATUS.md"
run "$PROJECT"
expect '检查 5 状态非法' 1 '状态值非法「基本完成」' '批次 F1'

new_project
printf '| 批次 | 目标 | 状态 | 证据 | 更新日期 |\n| --- | --- | --- | --- | --- |\n| F2 | x | 已完成 | 见上文 | 2026-11-08 |\n' >> "$PROJECT/STATUS.md"
run "$PROJECT"
expect '检查 5 已完成缺证据' 1 '批次 F2 标了已完成但证据列为空或空指代'

new_project
printf '| 批次 | 目标 | 状态 | 证据 | 更新日期 |\n| --- | --- | --- | --- | --- |\n| F3 | x | 已完成（基本完成） | 见 README | 2026-11-08 |\n' >> "$PROJECT/STATUS.md"
run "$PROJECT"
expect '检查 5 已完成不许带括号说明' 1 '状态值非法「已完成（基本完成）」'

new_project
printf '| 批次 | 目标 | 状态 | 证据 | 更新日期 |\n| --- | --- | --- | --- | --- |\n| F4 | x | 进行中（待验证） | - | 2026-11-08 |\n' >> "$PROJECT/STATUS.md"
run "$PROJECT"
clean '检查 5 进行中（待验证）合法'

new_project
T_EXCLUDE='STATUS.md'
write_map '- `AGENTS.md` L0 — 关于【流程-入口】；在【上手项目】时读；在【结构变化】时改
- `DOC_MAP.md` L0 — 关于【流程-入口】；在【上手项目】时读；在【结构变化】时改
- `README.md` L1 — 关于【产品-概览】；在【上手项目】时读；在【用法变化】时改'
run "$PROJECT"
expect '检查 5 地图里没有 STATUS' 0 '找不到 STATUS.md'

# ---------- 检查 6：链接 ----------

std_project; printf '\n[坏](docs/none.md)\n' >> "$PROJECT/README.md"; run "$PROJECT"
expect '检查 6 死链' 0 '死链 README.md' 'docs/none.md'

std_project; printf '\n[a](n1.md) [b](n2.md)\n[c](n3.md)\n[d](n4.md)\n[e](n5.md)\n[f](n6.md)\n[g](n7.md)\n' >> "$PROJECT/README.md"; run "$PROJECT"
expect '检查 6 只列前 5 处' 0 '另有 2 条'

std_project; printf '\n[好](STATUS.md) [外](https://example.com)\n' >> "$PROJECT/README.md"; run "$PROJECT"
clean '检查 6 有效链接'

new_project
write_map "${ROWS_ROOT}
- \`docs/a.md\` L2 — 关于【产品-概览】；在【加功能】时读；在【增删模块】时改
- \`docs/b.md\` L2 — 关于【产品-概览】；在【加功能】时读；在【增删模块】时改"
add_doc docs/a.md; add_doc docs/b.md; printf '\n[相邻](b.md)\n' >> "$PROJECT/docs/a.md"; run "$PROJECT"
clean '检查 6 子目录文档的相对链接'

# ---------- 检查 7：地图行与词表 ----------

new_project
write_map "${ROWS_ROOT}
- \`docs/x.md\` L2 — 关于【产品-概览】；在【加功能】时读"
add_doc docs/x.md; run "$PROJECT"
expect '检查 7 缺一段' 1 '检查 7' '格式不对：docs/x.md'

new_project
write_map "${ROWS_ROOT}
- \`docs/x.md\` L2 — 关于【产品-概览】；在加功能时读；在【增删模块】时改"
add_doc docs/x.md; run "$PROJECT"
expect '检查 7 时机段没有标签' 1 '格式不对：docs/x.md'

new_project
write_map "${ROWS_ROOT}
- \`docs/x.md\` L2 — 关于产品；在【加功能】时读；在【增删模块】时改"
add_doc docs/x.md; run "$PROJECT"
expect '检查 7 主题段没有标签' 1 '格式不对：docs/x.md'

new_project
write_map "${ROWS_ROOT}
- \`docs/x.md\` L2 — 关于【产品-概览】；在【加功能】时读；在模块变化时改"
add_doc docs/x.md; run "$PROJECT"
expect '检查 7 事件段没有标签' 1 '格式不对：docs/x.md'

new_project
write_map "${ROWS_ROOT}
- \`docs/x.md\` — 关于【产品-概览】；在【加功能】时读；在【增删模块】时改"
add_doc docs/x.md; run "$PROJECT"
expect '检查 7 缺层' 1 '格式不对：docs/x.md'

new_project
write_map "${ROWS_ROOT}
- \`docs/x.md\` L2 — 关于【未知主题】；在【加功能】时读；在【增删模块】时改"
add_doc docs/x.md; run "$PROJECT"
expect '检查 7 词表外主题' 1 '词表外的主题标签【未知主题】：docs/x.md'

new_project
write_map "${ROWS_ROOT}
- \`docs/x.md\` L2 — 关于【产品-概览】；在【未知时机】时读；在【增删模块】时改"
add_doc docs/x.md; run "$PROJECT"
expect '检查 7 词表外时机' 1 '词表外的时机标签【未知时机】：docs/x.md'

new_project
write_map "${ROWS_ROOT}
- \`docs/x.md\` L2 — 关于【产品-概览】；在【加功能】时读；在【未知事件】时改"
add_doc docs/x.md; run "$PROJECT"
expect '检查 7 词表外事件' 1 '词表外的事件标签【未知事件】：docs/x.md'

new_project
write_map "${ROWS_ROOT}
- \`docs/x.md\` L2 — 关于【加功能】；在【加功能】时读；在【增删模块】时改"
add_doc docs/x.md; run "$PROJECT"
expect '检查 7 标签放错段' 1 '词表外的主题标签【加功能】：docs/x.md'

new_project
write_map "$ROWS_ROOT"
sed -e '/doctags:begin/d' -e '/doctags:end/d' "$PROJECT/DOC_MAP.md" > "$PROJECT/DOC_MAP.tmp"
mv "$PROJECT/DOC_MAP.tmp" "$PROJECT/DOC_MAP.md"
run "$PROJECT"
expect '检查 7 缺词表块' 1 '缺 doctags 词表'

new_project
write_map "${ROWS_ROOT}
- \`docs/x.md\` L2 — 关于【产品-概览】；在【加功能】时读；在【增删模块】时改；多余一段"
add_doc docs/x.md; run "$PROJECT"
expect '检查 7 多一段' 1 '格式不对：docs/x.md'

new_project
write_map "${ROWS_ROOT}
- \`docs/x.md\` L2 — 关于【产品-概览】；在【加功能】时看；在【增删模块】时改"
add_doc docs/x.md; run "$PROJECT"
expect '检查 7 缺“时读”' 1 '格式不对：docs/x.md'

new_project
write_map "${ROWS_ROOT}
- \`docs/x.md\` L2 — 讲【产品-概览】；在【加功能】时读；在【增删模块】时改"
add_doc docs/x.md; run "$PROJECT"
expect '检查 7 缺“关于”' 1 '格式不对：docs/x.md'

new_project
write_map "${ROWS_ROOT}
- \`docs/x.md\` L2 — 关于【产品-概览】；在【加功能】时读；在【增删模块】时动"
add_doc docs/x.md; run "$PROJECT"
expect '检查 7 缺“时改”' 1 '格式不对：docs/x.md'

new_project
write_map "${ROWS_ROOT}
- \`docs/x.md L2 — 关于【产品-概览】；在【加功能】时读；在【增删模块】时改"
add_doc docs/x.md; run "$PROJECT"
expect '检查 7 反引号没闭合' 1 '格式不对'

# ---------- 检查 8：跨类同名 ----------

new_project
T_READ="${T_READ}
- 【产品】重名"
write_map "$ROWS_ROOT"; run "$PROJECT"
expect '检查 8 跨类同名' 1 '检查 8' '【产品】' '主题' '时机'

# ---------- 检查 9：频率、碰撞、预算 ----------

large_project '乙:3 丙:3'; run "$PROJECT"
clean '检查 9 十份文档、父级正好 3 份'

large_project '乙:4 丙:2'; run "$PROJECT"
expect '检查 9 父级只覆盖 2 份' 0 '检查 9' '【丙】只覆盖 2 份'

large_project '乙:3 丙:2'; run "$PROJECT"
clean '检查 9 九份文档不查频率'

large_project '乙:4 丙:2' '- 【丙】补充：【丙-另一】'
sed -e 's/^\(- `docs\/d6.md` L2 — 关于【丙-子】\)；/\1和【丙-另一】；/' "$PROJECT/DOC_MAP.md" > "$PROJECT/DOC_MAP.tmp"
mv "$PROJECT/DOC_MAP.tmp" "$PROJECT/DOC_MAP.md"
run "$PROJECT"
expect '检查 9 同一文档的两个子级只算一次' 0 '【丙】只覆盖 2 份'

large_project '乙:6'; run "$PROJECT"
refute '检查 9 不超过 20 份文档不查 4 成上限' '超过 40%'

large_project '乙:9 丙:4 丁:3'; run "$PROJECT"
refute '检查 9 正好 20 份文档仍不查上限' '超过 40%'

large_project '乙:9 丙:4 丁:4'; run "$PROJECT"
expect '检查 9 21 份文档开始查上限' 0 '【乙】覆盖 9 份' '超过 40%' '共 21 份'

large_project '乙:10 丙:4 丁:4 戊:3'; run "$PROJECT"
refute '检查 9 25 份里正好 4 成不报' '超过 40%'

large_project '乙:3 丙:3' '- 【乙】补充：【乙-闲置】'; run "$PROJECT"
expect '检查 9 子级未使用' 0 '词表里未使用的主题标签【乙-闲置】'

large_project '乙:3 丙:3' '- 【己】说明：【己-子】'; run "$PROJECT"
expect '检查 9 父级未使用' 0 '词表里未使用的主题标签【己】'

large_project '乙:3 丙:2' '- 【己】说明：【己-子】'; run "$PROJECT"
refute '检查 9 九份文档不查未使用' '未使用'

new_project
T_TOPIC="${T_TOPIC}
- 【部署】运行与发布：【部署-运行】"
T_READ="${T_READ}
- 【部署发布】发布站点"
write_map "$ROWS_ROOT"; run "$PROJECT"
expect '检查 9 前缀碰撞' 0 '前缀碰撞' '【部署】' '【部署发布】'

new_project
T_TOPIC="${T_TOPIC}
- 【部署】运行与发布：【部署-运行】"
write_map "$ROWS_ROOT"; run "$PROJECT"
refute '检查 9 父子不算碰撞' '前缀碰撞'

new_project; read_vocab 12; write_map "$ROWS_ROOT"; run "$PROJECT"
clean '检查 9 时机标签 12 个'

new_project; read_vocab 13; write_map "$ROWS_ROOT"; run "$PROJECT"
expect '检查 9 时机标签 13 个' 0 '时机标签 13 个' '超过 12 个'

new_project; write_map "$ROWS_ROOT"; pad_vocab 50; run "$PROJECT"
clean '检查 9 词表 50 行'

new_project; write_map "$ROWS_ROOT"; pad_vocab 51; run "$PROJECT"
expect '检查 9 词表 51 行' 0 '词表 51 行' '超过 50 行'

new_project; agents_lines 120; run "$PROJECT"
clean '检查 9 AGENTS.md 120 行'

new_project; agents_lines 121; run "$PROJECT"
expect '检查 9 AGENTS.md 121 行' 0 'AGENTS.md 121 行' '超过 120 行'

std_project; agents_lines 121; run "$PROJECT"
expect '检查 9 有地图时也查 AGENTS.md 预算' 0 'AGENTS.md 121 行'

std_project; add_doc docs/x.md; run "$PROJECT" --strict
expect '--strict 下 FAIL 仍是退出码 1' 1 '未被地图覆盖'

std_project; run "$PROJECT" --strict
clean '--strict 下合规项目通过'

# ---------- locale：en_US.UTF-8 下 BSD awk 会把不同的中文词判成相等 ----------

run_en_us() {
  OUT=$(LC_ALL=en_US.UTF-8 bash "$CHECK" --root "$1" 2>&1)
  CODE=$?
}

large_project '乙:3 丙:3'; run_en_us "$PROJECT"
clean 'en_US 下时机标签不会被当成主题标签'

new_project
T_TOPIC="${T_TOPIC}
- 【部署】运行与发布：【部署-运行】"
T_READ="${T_READ}
- 【部署发布】发布站点"
write_map "$ROWS_ROOT"; run_en_us "$PROJECT"
expect 'en_US 下仍能发现前缀碰撞' 0 '前缀碰撞'

new_project
printf '| 批次 | 目标 | 状态 | 证据 | 更新日期 |\n| --- | --- | --- | --- | --- |\n| 阶段一 | x | 基本完成 | - | 2026-11-08 |\n' >> "$PROJECT/STATUS.md"
run_en_us "$PROJECT"
expect 'en_US 下中文批次名不会被当成表头' 1 '状态值非法「基本完成」'

# ---------- 汇总 ----------

echo ""
echo "—— doc-check 测试：通过 ${PASS}，失败 ${FAILED} ——"
if [ "$FAILED" -gt 0 ]; then exit 1; fi
exit 0
