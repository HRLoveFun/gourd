#!/usr/bin/env bash
# auto-flow.sh — 提交 → 增量编译 → 合并 → 分支清理，一条命令完成
#
# 用法：
#   ./skills/git-auto-flow/scripts/auto-flow.sh -m "<提交信息>" [选项]
#   ./skills/git-auto-flow/scripts/auto-flow.sh --status
#
# 选项：
#   -m, --message <msg>   提交信息，首行须符合 <前缀>: <说明>
#       --target <name>   合并目标分支（默认 main）
#       --remote <name>   远端名（默认 origin）
#       --compile <cmd>   增量编译命令（默认 ic）
#       --path <path>     只提交指定路径，可重复；默认 git add -A
#       --staged          只提交已暂存内容，不再自动 add
#       --apply           真正执行；不加只演练
#       --keep-branch     合并后保留工作分支（本地与远端）
#       --keep-remote     只清理本地，不删除远端已合并分支
#       --no-push         不推送目标分支，并跳过远端清理
#       --status          只读查看状态与清理候选
#   -h, --help            显示本帮助
#
# 退出码：0 成功 / 1 运行期失败 / 2 预检不通过 / 3 编译失败
#         4 合并冲突 / 5 合并成功但清理未完成 / 64 用法错误

set -euo pipefail

MESSAGE=""
TARGET="main"
REMOTE="origin"
COMPILE_CMD="ic"
APPLY=0
KEEP_BRANCH=0
KEEP_REMOTE=0
DO_PUSH=1
STATUS_ONLY=0
STAGED=0

PATHS=()
ROOT=""
GITDIR=""
WORK_BRANCH=""
STEP=0
TOTAL=6
START=$SECONDS
NEW_COMMIT=0
COMMIT_SHA=""
MERGE_SHA=""
COMPILE_STATE="未执行"
LOCAL_DONE=0
REMOTE_DONE=0
PLANNED=0
CLEAN_FAIL=0

usage() {
  awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next} {exit}' "$0"
}

usage_error() {
  printf '参数错误：%s\n\n' "$1" >&2
  usage >&2
  exit 64
}

step() {
  STEP=$((STEP + 1))
  printf '\n[%d/%d] %s\n' "$STEP" "$TOTAL" "$1"
}

ok()   { printf '  OK    %s\n' "$1"; }
skip() { printf '  SKIP  %s\n' "$1"; }
plan() { printf '  PLAN  %s\n' "$1"; }
warn() { printf '  WARN  %s\n' "$1"; }
bad()  { printf '  FAIL  %s\n' "$1"; }

is_protected() {
  case "$1" in
    main|master|trunk|develop|release/*|hotfix/*|backup/*) return 0 ;;
    *) return 1 ;;
  esac
}

check_repo() {
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    printf '不是 git 仓库：%s\n' "$PWD" >&2
    exit 2
  fi
  ROOT=$(git rev-parse --show-toplevel)
  cd "$ROOT"
  GITDIR=$(git rev-parse --absolute-git-dir 2>/dev/null || git rev-parse --git-dir)
}

check_interrupted() {
  local f
  for f in MERGE_HEAD CHERRY_PICK_HEAD REVERT_HEAD rebase-merge rebase-apply; do
    if [ -e "$GITDIR/$f" ]; then
      bad "仓库处于中断态（${f}），先收尾再执行"
      return 1
    fi
  done
  return 0
}

check_message() {
  local first len
  if [ -z "$MESSAGE" ]; then
    bad "缺少 -m/--message"
    return 1
  fi
  first=${MESSAGE%%$'\n'*}
  len=${#first}
  if [ "$len" -gt 100 ]; then
    bad "提交信息首行 ${len} 字符，超过 100"
    return 1
  fi
  if ! printf '%s' "$first" | grep -Eq '^(add|fix|docs|chore|test|refactor|perf|style|build|ci|revert|merge|L3): .{4,}'; then
    bad "提交信息不符规范：$first"
    printf '        应为 <前缀>: <说明>，前缀限 add/fix/docs/chore/test/refactor/perf/style/build/ci/revert/merge/L3\n' >&2
    return 1
  fi
  case "$first" in
    *。) bad "提交信息首行不以句号结尾：$first"; return 1 ;;
  esac
  return 0
}

check_compile_cmd() {
  local bin
  bin=${COMPILE_CMD%% *}
  if [ -z "$bin" ]; then
    bad "编译命令为空"
    return 1
  fi
  if ! command -v "$bin" >/dev/null 2>&1; then
    bad "编译命令不存在：$bin"
    printf '        用 --compile 指定完整命令，或确认 PATH；脚本不会把未运行的编译记为通过\n' >&2
    return 1
  fi
  return 0
}

check_target() {
  if git show-ref --verify --quiet "refs/heads/$TARGET"; then
    return 0
  fi
  if git show-ref --verify --quiet "refs/remotes/$REMOTE/$TARGET"; then
    return 0
  fi
  if [ "$APPLY" -eq 1 ] && git ls-remote --exit-code --heads "$REMOTE" "$TARGET" >/dev/null 2>&1; then
    return 0
  fi
  bad "目标分支不存在：$REMOTE/$TARGET"
  printf '        先 git fetch %s，或用 --target 指定已有分支\n' "$REMOTE" >&2
  return 1
}

preflight() {
  local changes changes_count ahead

  step "预检"
  check_repo
  ok "仓库 $ROOT"

  if ! check_interrupted; then
    exit 2
  fi
  ok "无未收尾的 merge/rebase/cherry-pick"

  WORK_BRANCH=$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)
  if [ -z "$WORK_BRANCH" ]; then
    bad "detached HEAD：先检出工作分支"
    exit 2
  fi
  ok "工作分支 $WORK_BRANCH"

  if is_protected "$WORK_BRANCH"; then
    bad "$WORK_BRANCH 是保护分支，不能作为提交分支"
    exit 2
  fi
  if [ "$WORK_BRANCH" = "$TARGET" ]; then
    bad "工作分支与目标分支相同（${TARGET}），无可合并内容"
    exit 2
  fi
  ok "工作分支不是保护分支，且不同于目标分支"

  if ! check_message; then
    exit 2
  fi
  ok "提交信息符合规范"

  if ! check_compile_cmd; then
    exit 2
  fi
  ok "编译命令 $COMPILE_CMD 可用"

  if ! check_target; then
    exit 2
  fi
  ok "目标分支 $REMOTE/$TARGET 存在"

  if [ "$STAGED" -eq 1 ]; then
    changes=$(git diff --cached --name-only)
  else
    changes=$(git status --porcelain)
  fi
  changes_count=$(printf '%s\n' "$changes" | grep -c . || true)
  ahead=$(git rev-list --count "$TARGET..$WORK_BRANCH" 2>/dev/null || true)
  ahead=${ahead:-0}

  if [ "$changes_count" -eq 0 ]; then
    if [ "$STAGED" -eq 1 ]; then
      ok "暂存区无待提交改动"
    else
      ok "工作区无待提交改动"
    fi
  else
    ok "待提交 $changes_count 项"
  fi
  ok "相对 $TARGET 有 $ahead 个未合并提交"

  if [ "$changes_count" -eq 0 ] && [ "$ahead" -eq 0 ]; then
    printf '\n无事可做：工作区干净，且 %s 已全部包含在 %s 中。\n' "$WORK_BRANCH" "$TARGET"
    exit 0
  fi
}

show_status() {
  local changes changes_count ahead b ref name

  check_repo
  WORK_BRANCH=$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)
  [ -n "$WORK_BRANCH" ] || { printf 'detached HEAD，无法判定工作分支\n' >&2; exit 2; }

  printf '== git-auto-flow 状态 ==\n'
  printf '仓库     %s\n' "$ROOT"
  printf '当前分支 %s\n' "$WORK_BRANCH"
  printf '目标分支 %s/%s\n' "$REMOTE" "$TARGET"

  changes=$(git status --porcelain)
  changes_count=$(printf '%s\n' "$changes" | grep -c . || true)
  ahead=$(git rev-list --count "$TARGET..$WORK_BRANCH" 2>/dev/null || true)
  ahead=${ahead:-0}
  printf '待提交   %s 项\n' "$changes_count"
  printf '未合并   %s 个提交\n' "$ahead"

  printf '\n本地可清理分支：\n'
  while IFS= read -r b; do
    [ -z "$b" ] && continue
    [ "$b" = "$TARGET" ] && continue
    [ "$b" = "$WORK_BRANCH" ] && continue
    is_protected "$b" && continue
    if git merge-base --is-ancestor "$b" "$TARGET" 2>/dev/null; then
      printf '  %s\n' "$b"
    fi
  done < <(git for-each-ref --format='%(refname:short)' refs/heads)

  printf '\n远端可清理分支：\n'
  while IFS= read -r ref; do
    [ -z "$ref" ] && continue
    name=${ref#refs/remotes/${REMOTE}/}
    [ "$name" = "HEAD" ] && continue
    [ "$name" = "$TARGET" ] && continue
    [ "$name" = "$WORK_BRANCH" ] && continue
    is_protected "$name" && continue
    if git merge-base --is-ancestor "$ref" "$TARGET" 2>/dev/null; then
      printf '  %s\n' "$name"
    fi
  done < <(git for-each-ref --format='%(refname)' "refs/remotes/${REMOTE}")

  printf '\n失效追踪引用（只读探测，需要网络）：\n'
  git remote prune "$REMOTE" --dry-run 2>/dev/null | sed 's/^/  /' || printf '  （远端不可达，跳过）\n'
}

rollback_commit() {
  if [ "$NEW_COMMIT" -eq 1 ]; then
    git reset --soft HEAD~1
    NEW_COMMIT=0
    printf '  已回滚本次提交（reset --soft），改动保留在暂存区；工作分支未合并。\n'
  else
    printf '  本次未产生新提交，未回滚既有提交。\n'
  fi
}

do_commit() {
  local changes changes_count out
  step "提交"

  if [ "$STAGED" -eq 1 ]; then
    changes=$(git diff --cached --name-only)
  else
    changes=$(git status --porcelain)
  fi
  changes_count=$(printf '%s\n' "$changes" | grep -c . || true)

  if [ "$changes_count" -eq 0 ]; then
    skip "无待提交改动，跳过提交"
    return 0
  fi

  if [ "$APPLY" -eq 0 ]; then
    if [ "$STAGED" -eq 1 ]; then
      plan "git commit -m \"$MESSAGE\"（只提交暂存区 $changes_count 项）"
    elif [ "${#PATHS[@]}" -gt 0 ]; then
      plan "git add -- ${PATHS[*]} && git commit -m \"$MESSAGE\""
    else
      plan "git add -A && git commit -m \"$MESSAGE\""
    fi
    return 0
  fi

  if [ "$STAGED" -eq 0 ]; then
    if [ "${#PATHS[@]}" -gt 0 ]; then
      if ! out=$(git add -- "${PATHS[@]}" 2>&1); then
        bad "git add 失败"
        printf '%s\n' "$out" | sed 's/^/  | /'
        exit 1
      fi
    else
      if ! out=$(git add -A 2>&1); then
        bad "git add -A 失败"
        printf '%s\n' "$out" | sed 's/^/  | /'
        exit 1
      fi
    fi
  fi

  if ! out=$(git commit -m "$MESSAGE" 2>&1); then
    bad "提交失败"
    printf '%s\n' "$out" | sed 's/^/  | /'
    exit 1
  fi

  NEW_COMMIT=1
  COMMIT_SHA=$(git rev-parse --short HEAD)
  ok "已提交 $COMMIT_SHA"
}

do_compile() {
  local log rc start elapsed before after
  step "增量编译"

  if [ "$APPLY" -eq 0 ]; then
    plan "$COMPILE_CMD"
    COMPILE_STATE="演练未执行"
    return 0
  fi

  before=$(git status --porcelain | LC_ALL=C sort)

  log=$(mktemp "${TMPDIR:-/tmp}/auto-flow-compile.XXXXXX")
  start=$SECONDS

  set +e
  ( cd "$ROOT" && bash -c "$COMPILE_CMD" ) >"$log" 2>&1
  rc=$?
  set -e

  elapsed=$((SECONDS - start))

  if [ "$rc" -ne 0 ]; then
    bad "编译失败：退出码 ${rc}，耗时 ${elapsed}s"
    printf '  ---- 日志末尾 ----\n'
    tail -n 40 "$log" | sed 's/^/  | /'
    rollback_commit
    printf '  完整日志：%s\n' "$log"
    exit 3
  fi

  rm -f "$log"
  after=$(git status --porcelain | LC_ALL=C sort)
  if [ "$before" != "$after" ]; then
    bad "编译改变了工作区（新增或修改了未提交内容），中止合并"
    diff <(printf '%s\n' "$before") <(printf '%s\n' "$after") | grep '^>' | sed 's/^> /  | /' || true
    rollback_commit
    printf '  先确认产物该提交还是该忽略，再重跑。\n'
    exit 3
  fi

  COMPILE_STATE="OK（${elapsed}s）"
  ok "编译通过，耗时 ${elapsed}s"
}

do_merge() {
  local out merge_msg
  step "合并"

  if [ "$APPLY" -eq 0 ]; then
    plan "git fetch --prune $REMOTE"
    plan "git checkout $TARGET && git pull --ff-only $REMOTE $TARGET"
    plan "git merge --no-ff $WORK_BRANCH -m \"merge: $WORK_BRANCH 合入 $TARGET\""
    return 0
  fi

  if ! out=$(git fetch --prune "$REMOTE" 2>&1); then
    bad "git fetch 失败"
    printf '%s\n' "$out" | sed 's/^/  | /'
    exit 1
  fi
  ok "已 fetch 并清理失效追踪引用"

  if git show-ref --verify --quiet "refs/heads/$TARGET"; then
    if ! out=$(git checkout "$TARGET" 2>&1); then
      bad "切到 $TARGET 失败"
      printf '%s\n' "$out" | sed 's/^/  | /'
      exit 1
    fi
  else
    if ! out=$(git checkout -b "$TARGET" "$REMOTE/$TARGET" 2>&1); then
      bad "创建本地 $TARGET 失败"
      printf '%s\n' "$out" | sed 's/^/  | /'
      exit 1
    fi
  fi

  if ! out=$(git pull --ff-only "$REMOTE" "$TARGET" 2>&1); then
    bad "拉取 $REMOTE/$TARGET 失败（可能需要手动处理分叉）"
    printf '%s\n' "$out" | sed 's/^/  | /'
    git checkout "$WORK_BRANCH" 2>/dev/null || true
    exit 1
  fi
  ok "本地 $TARGET 已快进到 $REMOTE/$TARGET"

  merge_msg="merge: $WORK_BRANCH 合入 $TARGET"
  if ! out=$(git merge --no-ff "$WORK_BRANCH" -m "$merge_msg" 2>&1); then
    bad "合并冲突，已中止"
    printf '%s\n' "$out" | sed 's/^/  | /'
    git merge --abort 2>/dev/null || true
    git checkout "$WORK_BRANCH" 2>/dev/null || true
    printf '  已执行 merge --abort 并切回 %s；未推送任何内容。\n' "$WORK_BRANCH"
    printf '  手动解决冲突后，重跑同一条命令即可。\n'
    exit 4
  fi

  MERGE_SHA=$(git rev-parse --short HEAD)
  ok "已生成合并提交 $MERGE_SHA"
}

do_push() {
  local out
  step "推送"

  if [ "$DO_PUSH" -eq 0 ]; then
    skip "--no-push：不推送，同时跳过远端清理"
    return 0
  fi

  if [ "$APPLY" -eq 0 ]; then
    plan "git push $REMOTE $TARGET"
    return 0
  fi

  if ! out=$(git push "$REMOTE" "$TARGET" 2>&1); then
    bad "推送失败"
    printf '%s\n' "$out" | sed 's/^/  | /'
    printf '  本地合并已保留。回滚命令：git reset --hard ORIG_HEAD\n'
    exit 1
  fi
  ok "已推送 $REMOTE/$TARGET"
}

do_cleanup() {
  local b ref name out
  step "清理"

  if [ "$APPLY" -eq 0 ]; then
    if [ "$DO_PUSH" -eq 0 ]; then
      plan "跳过远端清理（--no-push）"
    fi
    while IFS= read -r b; do
      [ -z "$b" ] && continue
      [ "$b" = "$TARGET" ] && continue
      is_protected "$b" && continue
      if [ "$b" = "$WORK_BRANCH" ] && [ "$KEEP_BRANCH" -eq 1 ]; then
        plan "保留工作分支 ${b}（--keep-branch）"
        continue
      fi
      if git merge-base --is-ancestor "$b" "$TARGET" 2>/dev/null; then
        plan "本地待删 $b"
        PLANNED=$((PLANNED + 1))
      fi
    done < <(git for-each-ref --format='%(refname:short)' refs/heads)

    if [ "$DO_PUSH" -eq 1 ] && [ "$KEEP_REMOTE" -eq 0 ]; then
      while IFS= read -r ref; do
        [ -z "$ref" ] && continue
        name=${ref#refs/remotes/${REMOTE}/}
        [ "$name" = "HEAD" ] && continue
        [ "$name" = "$TARGET" ] && continue
        is_protected "$name" && continue
        if [ "$name" = "$WORK_BRANCH" ] && [ "$KEEP_BRANCH" -eq 1 ]; then
          continue
        fi
        if git merge-base --is-ancestor "$ref" "$TARGET" 2>/dev/null; then
          plan "远端待删 $name"
          PLANNED=$((PLANNED + 1))
        fi
      done < <(git for-each-ref --format='%(refname)' "refs/remotes/${REMOTE}")
    fi
    return 0
  fi

  if ! out=$(git fetch --prune "$REMOTE" 2>&1); then
    warn "fetch --prune 失败：$out"
    CLEAN_FAIL=$((CLEAN_FAIL + 1))
  fi

  while IFS= read -r b; do
    [ -z "$b" ] && continue
    [ "$b" = "$TARGET" ] && continue
    is_protected "$b" && continue
    if [ "$b" = "$WORK_BRANCH" ] && [ "$KEEP_BRANCH" -eq 1 ]; then
      skip "保留工作分支 ${b}（--keep-branch）"
      continue
    fi
    git merge-base --is-ancestor "$b" "$TARGET" 2>/dev/null || continue
    if out=$(git branch -d "$b" 2>&1); then
      ok "本地删除 $b"
      LOCAL_DONE=$((LOCAL_DONE + 1))
    else
      warn "本地未删除 ${b}：$out"
      CLEAN_FAIL=$((CLEAN_FAIL + 1))
    fi
  done < <(git for-each-ref --format='%(refname:short)' refs/heads)

  if [ "$DO_PUSH" -eq 0 ]; then
    skip "跳过远端清理（--no-push）"
  elif [ "$KEEP_REMOTE" -eq 1 ]; then
    skip "跳过远端清理（--keep-remote）"
  else
    while IFS= read -r ref; do
      [ -z "$ref" ] && continue
      name=${ref#refs/remotes/${REMOTE}/}
      [ "$name" = "HEAD" ] && continue
      [ "$name" = "$TARGET" ] && continue
      is_protected "$name" && continue
      if [ "$name" = "$WORK_BRANCH" ] && [ "$KEEP_BRANCH" -eq 1 ]; then
        skip "保留远端 ${name}（--keep-branch）"
        continue
      fi
      git merge-base --is-ancestor "$ref" "$TARGET" 2>/dev/null || continue
      if out=$(git push "$REMOTE" --delete "$name" 2>&1); then
        ok "远端删除 $name"
        REMOTE_DONE=$((REMOTE_DONE + 1))
      else
        warn "远端未删除 ${name}：$out"
        CLEAN_FAIL=$((CLEAN_FAIL + 1))
      fi
    done < <(git for-each-ref --format='%(refname)' "refs/remotes/${REMOTE}")
  fi
}

summary() {
  printf '\n== 汇总 ==\n'
  printf '模式   %s\n' "$([ "$APPLY" -eq 1 ] && echo 执行 || echo 演练)"
  printf '分支   %s -> %s\n' "$WORK_BRANCH" "$TARGET"
  printf '提交   %s\n' "${COMMIT_SHA:-（无新提交）}"
  printf '编译   %s\n' "$COMPILE_STATE"
  printf '合并   %s\n' "${MERGE_SHA:-（未执行）}"
  printf '清理   本地 %d 个 / 远端 %d 个' "$LOCAL_DONE" "$REMOTE_DONE"
  if [ "$PLANNED" -gt 0 ]; then
    printf ' / 计划 %d 个' "$PLANNED"
  fi
  printf '\n耗时   %ss\n' "$((SECONDS - START))"

  if [ "$CLEAN_FAIL" -gt 0 ]; then
    printf '结果   合并成功，%d 项清理未完成\n' "$CLEAN_FAIL"
  else
    printf '结果   %s\n' "$([ "$APPLY" -eq 1 ] && echo 成功 || echo "演练完成，未改动任何内容")"
  fi
}

# ---- 参数 ----
while [ "$#" -gt 0 ]; do
  case "$1" in
    -m|--message) MESSAGE="${2:-}"; shift 2 || true ;;
    --target) TARGET="${2:-}"; shift 2 || true ;;
    --remote) REMOTE="${2:-}"; shift 2 || true ;;
    --compile) COMPILE_CMD="${2:-}"; shift 2 || true ;;
    --path) PATHS+=("${2:-}"); shift 2 || true ;;
    --staged) STAGED=1; shift ;;
    --apply) APPLY=1; shift ;;
    --keep-branch) KEEP_BRANCH=1; shift ;;
    --keep-remote) KEEP_REMOTE=1; shift ;;
    --no-push) DO_PUSH=0; shift ;;
    --status) STATUS_ONLY=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage_error "未知参数：$1" ;;
  esac
done

if [ "$STAGED" -eq 1 ] && [ "${#PATHS[@]}" -gt 0 ]; then
  usage_error "--staged 与 --path 不能同时使用"
fi
[ -n "$TARGET" ] || usage_error "--target 不能为空"
[ -n "$REMOTE" ] || usage_error "--remote 不能为空"
[ -n "$COMPILE_CMD" ] || usage_error "--compile 不能为空"
if ! git check-ref-format --branch "$TARGET" >/dev/null 2>&1; then
  usage_error "非法分支名：$TARGET"
fi

if [ "$STATUS_ONLY" -eq 1 ]; then
  show_status
  exit 0
fi

printf '== git-auto-flow ==\n'

preflight

printf '\n模式   %s\n' "$([ "$APPLY" -eq 1 ] && echo 执行 || echo 演练)"

do_commit
do_compile
do_merge
do_push
do_cleanup
summary

if [ "$APPLY" -eq 0 ]; then
  printf '\n演练结束：未改动任何内容。确认无误后加 --apply 执行。\n'
  exit 0
fi

if [ "$CLEAN_FAIL" -gt 0 ]; then
  exit 5
fi
exit 0
