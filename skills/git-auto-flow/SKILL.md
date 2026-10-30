---
name: git-auto-flow
description: 把一次代码改动收尾成可追溯的固定流程：按规范提交、运行增量编译（默认 ic）、成功后合并到目标分支，再清理已合并的本地与远端分支及失效追踪引用。当用户说「提交并合并」「走自动流程」「改完了收尾」「清理已合并分支」时使用。不适用于跨仓库发布、打 tag 发版、需要人工解决冲突的合并，以及在 main 等保护分支上直接开发。
metadata:
  version: "0.1.0"
---

# git-auto-flow

## 用途

**接口摘要**：接受一条符合规范的提交信息与当前工作分支，产出「提交 → 增量编译 → 合并到目标分支 → 清理已合并分支」的执行记录；默认只演练，加 `--apply` 才落地；不碰保护分支、不 force push、不自动解决冲突。

收尾动作容易漏：写完代码忘了规范提交；提交了没编译就合并；合并后本地堆着已合并分支、远端堆着已合入分支、`origin/*` 还留着已删除分支的追踪引用。每一步单独做都不难，难的是每次都做全、且失败时知道退回到哪。

本技能把这串动作压成一条命令，并把「什么条件下才允许合并」「失败时回滚到哪」写成可核对的规则，而不是靠执行者记性。

## 文件结构

```
git-auto-flow/
├── SKILL.md                  本文件：规则、触发条件、安全约束、回滚策略
├── references/SOURCES.md     MLA 引用 + healthcheck + 使用事件
└── scripts/auto-flow.sh      主流程脚本（bash 3.2，无第三方依赖，默认演练）
```

## 输入

| 项目 | 说明 | 是否必需 |
| --- | --- | --- |
| 提交信息 | 首行格式：`<前缀>: <说明>`，前缀见「提交信息规范」 | 是（`--status` 除外） |
| 工作分支 | 当前检出的分支，由 `git symbolic-ref` 取得；不能是保护分支 | 是 |
| 目标分支 | 默认 `main`，用 `--target` 改；必须已存在于远端 | 否 |
| 远端 | 默认 `origin`，用 `--remote` 改 | 否 |
| 增量编译命令 | 默认 `ic`，用 `--compile "npm run build"` 等覆盖 | 否 |
| 提交范围 | 默认 `git add -A`；`--path` 可重复指定只提交这些路径；`--staged` 只提交已暂存内容 | 否 |
| 执行模式 | 默认演练；`--apply` 才真正提交、合并、删除 | 否 |

## 输出

| 产出 | 位置 | 说明 |
| --- | --- | --- |
| 终端步骤日志 | stdout | 6 步固定编号，每步行首为 `OK` / `SKIP` / `PLAN` / `FAIL` |
| 结果汇总 | stdout 末尾 | 提交 SHA、编译耗时、合并与推送结果、清理数量 |
| 编译日志 | `$TMPDIR/auto-flow-compile.*` | 仅失败时保留，成功即删 |
| git 现场 | 仓库 | 成功时：目标分支多一个 merge commit，工作分支被删除（除非 `--keep-branch`） |

退出码：

| 码 | 含义 | 现场 |
| --- | --- | --- |
| 0 | 成功，或无事可做 | 合并已推送，清理完成 |
| 1 | 运行期失败（fetch / checkout / push） | 见「失败与回滚」 |
| 2 | 预检不通过 | 未产生任何变更 |
| 3 | 编译失败，或编译改变了工作区 | 本次提交已 `reset --soft` 撤销，改动留在工作区 |
| 4 | 合并冲突 | merge 已 abort，已切回工作分支 |
| 5 | 合并成功但清理未全部完成 | 合并已推送，逐条报告失败项 |
| 64 | 用法错误 | 未产生任何变更 |

## 依赖

- 运行时：bash 3.2+（macOS 自带版本即可）、git 2.20+
- 命令：`git` `awk` `sed` `grep` `mktemp` `date`
- 增量编译：默认 `ic`，必须在 `PATH` 中；不在 `PATH` 时脚本中止（退出码 2），不会静默跳过
- 外部服务或凭证：无脚本自带的凭证；推送沿用本机 git 凭据
- 未验证：Windows 原生 PowerShell 不适用；WSL / Git Bash 未实测；`ic` 只在模拟命令下验证过

## 长期记忆（跨会话规则）

以下规则对每次改动收尾都适用，Agent 加载本技能后不再逐次询问动作清单；规则本身只有这一份，脚本行为与之不符时以本文件为准并修脚本。

1. **收尾即执行**：一批代码改动完成、用户表示「可以提交 / 合并 / 收尾」时，按本技能的 6 步走，不拆成多轮问答。
2. **默认演练**：先跑不带 `--apply` 的一次，把计划与预检结果给用户看；只有用户明确要落地才加 `--apply`。破坏性动作（删分支、推送）不隐式发生。
3. **编译不通过不合并**：`ic` 失败即中止并回滚本次提交，不允许「先合并再修」。
4. **保护分支只做目标，不做工作分支**：`main` `master` `trunk` `develop` `release/*` `hotfix/*` `backup/*` 永不作为提交分支、永不被删除、永不被 force push。
5. **冲突交给人**：merge 冲突时只做 `merge --abort` 并切回工作分支，不尝试自动解法。
6. **清理有边界**：只删已合并到目标分支的分支；未合并、受保护、当前分支一律不动；远端已删除分支的追踪引用由 `fetch --prune` 处理。
7. **结果必须可核对**：每次执行给出 6 步日志与汇总；「完成」必须能指到退出码与汇总里的 SHA / 数量，不能只说「已处理」。
8. **规则变更走文件**：新增例外（如允许某分支保留）先改本节与「清理范围」表，再改脚本；不靠临时命令行变通。

## 使用方法

### 0. 预检（脚本自动做，失败退出码 2）

| 检查 | 判据 | 不通过时 |
| --- | --- | --- |
| 仓库 | `git rev-parse --git-dir` 成功 | 中止 |
| 中断态 | 无 `MERGE_HEAD` / `CHERRY_PICK_HEAD` / `REVERT_HEAD` / `rebase-*` | 中止，提示先收尾 |
| 分支 | 已检出且不是 detached HEAD | 中止 |
| 工作分支 | 不是保护分支，且不等于目标分支 | 中止 |
| 提交信息 | 符合下方规范 | 中止 |
| 编译命令 | 首段命令在 `PATH` 中 | 中止，提示用 `--compile` |
| 目标分支 | 本地或 `origin/<target>` 存在 | 中止 |

提交信息规范（脚本用 ERE 校验首行，长度按字符计）：

```
^(add|fix|docs|chore|test|refactor|perf|style|build|ci|revert|merge|L3): .{4,}$
```

- 首行 ≤ 100 字符，不以句号结尾
- `L3` 仅用于改技能 `description` 等接口变更，沿用仓库既有约定
- 示例：`add: git-auto-flow 技能与收尾脚本`、`fix: 编译失败时保留改动`

### 1. 演练

```bash
# 从仓库根执行；只打印计划，不改任何文件、不联网
./skills/git-auto-flow/scripts/auto-flow.sh -m "add: 本次改动说明"
```

### 2. 执行

```bash
./skills/git-auto-flow/scripts/auto-flow.sh -m "add: 本次改动说明" --apply
```

常用变体：

```bash
# 只提交指定路径，避免把无关改动卷进本次提交
... -m "fix: 修解析边界" --path skills/foo/SKILL.md --path skills/foo/scripts/run.sh --apply

# 只提交已暂存内容，不再自动 add（适合先精细挑选再收尾）
... -m "add: 本批技能" --staged --apply

# 换目标分支、换编译命令、保留工作分支
... -m "docs: 补说明" --target develop --compile "npm run build" --keep-branch --apply

# 只看状态与待清理分支，不做任何变更
... --status
```

### 3. 6 步流程

| 步 | 动作 | 失败处理 |
| --- | --- | --- |
| 1 | 预检 | 退出 2，未产生变更 |
| 2 | 提交（有改动时 `git add` + commit；无改动但有未合并提交则跳过） | 退出 1 |
| 3 | 增量编译（默认 `ic`） | `git reset --soft HEAD~1`（仅回滚本次提交），退出 3 |
| 4 | 合并（fetch → checkout 目标 → `pull --ff-only` → `merge --no-ff`） | 冲突则 `merge --abort` 并切回，退出 4 |
| 5 | 推送目标分支 | 不回滚，提示 `reset --hard ORIG_HEAD` 的命令，退出 1 |
| 6 | 清理（本地已合并分支、远端已合并分支、失效追踪引用） | 不阻断，逐条报告，退出 5 |

### 4. 核对

- 退出码 0：汇总里应有提交 SHA、编译 `OK`、合并提交 SHA、清理数量
- 退出码 3/4：工作区应完好，`git status` 里能看到改动；汇总里给出后续命令
- 需要复跑：修复后执行同一条命令即可；无新改动时脚本会跳过提交，继续编译与合并

## 安全约束

| 约束 | 实现 |
| --- | --- |
| 保护分支不可写 | 工作分支命中 `main` `master` `trunk` `develop` `release/*` `hotfix/*` `backup/*` 时直接拒绝；目标分支可以是被保护分支 |
| 不 force push | 脚本中不存在 `--force` / `+refspec`；推送失败只报告 |
| 不自动解冲突 | 只 `merge --abort`，不 `checkout --ours/--theirs`，不 `commit` 半成品 |
| 默认不动远端 | 不加 `--apply` 只打印计划；`--apply` 才 fetch / merge / push / delete |
| 不吞编译失败 | 编译命令不存在或退出码非 0 都中止；不允许「未运行编译」被记成通过 |
| 不删未合并分支 | 删除前逐个用 `git merge-base --is-ancestor <branch> <target>` 判定；本地再用 `git branch -d` 兜底 |
| 不碰工作区外 | 只在当前仓库根内操作；不使用 `git clean`、不删未跟踪文件、不碰 stash / tag / worktree |

## 清理范围

合并并推送成功后执行，顺序固定：

| 范围 | 处理 | 例外 |
| --- | --- | --- |
| 失效追踪引用 | `git fetch --prune <remote>`，清掉远端已删除分支对应的 `origin/*` | 无 |
| 本地已合并分支 | `git branch -d`，含本次工作分支 | 目标分支、保护分支、`--keep-branch` 指定时的工作分支、未合并分支、被 worktree 占用的分支 |
| 远端已合并分支 | `git push <remote> --delete <name>` | 目标分支、保护分支、`--keep-branch` 时的工作分支、未合并分支 |
| 不处理 | stash、tag、worktree、未合并分支、`.git` 内其他引用 | — |

`--keep-remote` 只关闭远端删除，仍做 `fetch --prune` 与本地清理。`--no-push` 时不做任何远端清理（避免删掉尚未包含本次合并的远端分支）。

## 失败与回滚

| 失败点 | 现场 | 脚本动作 | 人工兜底 |
| --- | --- | --- | --- |
| 预检 | 无变更 | 退出 2，打印未通过项 | 修正后重跑 |
| 提交 | 可能已 `git add` | 退出 1，不回滚暂存 | `git restore --staged <path>` |
| 编译（本次有新提交） | 本地多一个提交 | `git reset --soft HEAD~1`，改动回到暂存区 | `git reset --hard <提交前 SHA>`（会丢改动，慎用） |
| 编译（复跑，无新提交） | 现场不变 | 退出 3，不回滚既有提交 | 修复后重跑 |
| checkout 目标分支 | 仍在工作分支 | 退出 1，提交保留 | 处理占用文件后重跑 |
| merge 冲突 | 目标分支 merge 中 | `git merge --abort` + `git checkout <工作分支>`，退出 4 | 手动解冲突后重跑 |
| push | 本地已合并，远端未更新 | 不回滚，打印 `git reset --hard ORIG_HEAD`，退出 1 | 修网络/权限后重跑（会快进推送） |
| 清理 | 合并已推送 | 逐条报告，退出 5 | `git branch -D` / `git push --delete` 手动补 |

回滚的边界说清楚：**编译失败只撤销本次自动提交，不撤销本次工作区改动**；**合并冲突不撤销工作分支上的提交**；**推送失败不回滚本地合并**（回滚反而制造第二个分叉）。

## 输出示例

```text
== git-auto-flow ==
仓库   /Users/me/proj
模式   演练（加 --apply 执行）
分支   feat/parser -> main
提交   fix: 修解析边界

[1/6] 预检
  OK    工作区 3 项待提交
  OK    提交信息符合规范
  OK    编译命令 ic 可用
  OK    目标分支 main 存在
[2/6] 提交
  PLAN  git add -A && git commit -m "fix: 修解析边界"
[3/6] 增量编译
  PLAN  ic
[4/6] 合并
  PLAN  git fetch --prune origin && git checkout main && git pull --ff-only origin main
  PLAN  git merge --no-ff feat/parser
[5/6] 推送
  PLAN  git push origin main
[6/6] 清理
  PLAN  本地待删 1 个：feat/parser
  PLAN  远端待删 0 个
  PLAN  fetch --prune 清理失效追踪引用 0 个

演练结束：未改动任何内容。确认无误后加 --apply 执行。
```

## 注意事项

- `git add -A` 会把工作区所有改动卷进本次提交。仓库里有他人的未完成改动时，用 `--path` 圈定范围或用 `--staged` 只提交已挑选的内容；两者互斥。
- 脚本比较编译前后的 `git status --porcelain`，只要编译新增或修改了工作区内容就中止，避免把产物混进合并。用 `--path` 提交部分改动时，未被提交的改动不算「编译产生」，可以正常走完流程；但合并切换分支时它们不能与目标分支冲突，否则 checkout 失败并中止。
- 目标分支必须先存在于远端；纯本地仓库或首次推送场景需要先手动建立目标分支。
- 合并使用 `--no-ff`，保留分支历史；不接受「压成一个提交」的诉求，那属于另一条流程。
- 脚本不安装 git hook：提交动作由执行者（人或 Agent）显式触发，避免 hook 内递归提交、以及 IDE 保存即提交的意外。
- 清理只能证明「已合并」，不能证明「分支上的工作已被需要」；长期保留的分支请改名到 `backup/*` 或加 `--keep-branch`。
- 规则或保护分支名单变动时，同步改本文件与 `scripts/auto-flow.sh`，只改一处会造成文档与行为分叉。

## 来源与许可证

- 参考资料：见 [references/SOURCES.md](references/SOURCES.md)，本技能为原创，未改编他人代码
- 许可证：与仓库一致（MIT）
