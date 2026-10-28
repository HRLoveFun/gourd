---
name: darwin-skill
description: 按 9 维 rubric 评估并迭代优化一个 Agent Skill：基线评分 → 每轮只改一个维度 → 独立 judge 做 paired 多数决 → 只保留改进、退步自动回滚，全程 git 留痕并出成果卡片。当用户说「优化这个 skill」「给 skill 打个分」「自动优化」「达尔文」「skill 质量检查」「帮我改改 skill」「skill review」时使用。不适用于从零写一个新 skill、单个函数的代码审查、只想跑一次格式检查，以及没有 git 或无法跑测试 prompt 的环境。
metadata:
  author: "花叔"
  homepage: "https://github.com/alchaincyf"
  repository: "https://github.com/alchaincyf/darwin-skill"
  version: "2.1.0"
  imported: "2026-10-27"
  upstream_commit: "8a8b66258e3c45d6ae4aea39719468c6428fcb0a"
---

# 达尔文 · Skill 2.1

> 借鉴 Karpathy autoresearch 的自主实验循环：**评估 → 改进 → 实测验证 → 人类确认 → 保留或回滚 → 成果卡片**。
>
> 本目录移植自 [alchaincyf/darwin-skill](https://github.com/alchaincyf/darwin-skill)（MIT），方法、阈值与黑名单未改。移植范围与差异见 [references/SOURCES.md](references/SOURCES.md)。

## 用途

**接口摘要**：接受一个或一批 `SKILL.md`（含路径），产出 9 维评分卡、按轮次的改进 commit、`results.tsv` 优化日志与成果卡片 PNG；不改 skill 的功能与用途，只改「怎么写、怎么执行」。

它治一个具体的病：**skill 看起来写得挺全，但用起来没效果**。所以评分分两层——结构分（静态看写法）+ 效果分（带着 skill 跑真实 prompt，和 baseline 对比），后者的权重（23/100）决定了它不只是个格式检查器。

与纯结构审查的区别：不只看 SKILL.md 规不规范，更看改完后**实际跑出来的效果是否更好**。

## 文件结构

```
darwin-skill/
├── SKILL.md                      本文件：rubric + 优化循环 + 边界
├── LICENSE.upstream              上游 MIT 许可证原文
├── references/
│   ├── SOURCES.md                MLA 引用 + healthcheck + 与上游同步的步骤
│   ├── strategy-library.md       P0-P3 优化策略库（每轮改什么时读）
│   ├── result-card.md            成果卡片生成流程（Phase 3 出图时读）
│   ├── runtime-neutrality.md     红灯/绿灯对照表与例外清单
│   └── skilllens-evidence.md     SkillLens 论文证据与实战案例数字
├── scripts/
│   └── screenshot.mjs            2x 高清截图（需 node + playwright-core）
└── assets/
    ├── templates/                result-card 三种风格模板（swiss/terminal/newspaper）
    └── test-prompts.json         本 skill 自己的测试 prompt（自评时的样例）
```

`results.tsv` 不预置：首次优化时在**本目录**新建（上游约定放在 darwin 自己的目录里，跨仓库累积一份优化史）。本 skill 只规定格式，不预置数据。

## 输入

| 项目 | 说明 | 是否必需 |
| --- | --- | --- |
| 优化范围 | 「全部 skill」或指定 1 个（含路径） | 是 |
| 目标仓库 | 含 `skills/` 或 `.claude/skills/` 的 git 仓库 | 是，不在 git 仓库时见异常表 |
| 测试 prompt | 每个 skill 2-3 条典型用户说法 | 否，缺时 Phase 0.5 设计后请用户确认 |
| 历史记录 | 本目录既有的 `results.tsv` | 否，缺时新建 |

范围只有一句「帮我改改 skill」而没有对象：先问清是哪一个、在哪个仓库，不要凭印象挑。

## 输出

| 产物 | 位置 | 说明 |
| --- | --- | --- |
| 9 维评分卡 | 会话内输出 | 基线一张、每个 skill 收尾一张 |
| 改进提交 | `auto-optimize/YYYYMMDD-HHMM` 分支 | 只给 keep 的轮次提交（每轮一个）；worse 不提交，由 `results.tsv` 留痕 |
| 优化日志 | 本目录 `results.tsv` | 9 列，含 `eval_mode`，可直接当审计记录 |
| 成果卡片 | 用户指定的 PNG 路径 | 三份模板择一（默认主模板），需要 node + playwright |

写入范围只有四处：被优化 skill 目录（SKILL.md 与 test-prompts.json）、本目录的 `results.tsv` 与 `.last-update-check`、用户指定的卡片 PNG、优化分支上的提交。除此之外不动任何文件，尤其不覆盖用户未提交的改动。

## 依赖

- 运行时：git（棘轮机制的前提）、bash 3.2+、支持 subagent 的 Agent runtime（独立 judge 与 with/baseline 对比都要用）
- 第三方包：出卡片时需 node 18+ 与 `playwright` 或 `playwright-core`（`npm i -g playwright-core && npx playwright install chromium`）；不出卡片则无依赖
- 外部服务或凭证：无，不需要 API key；除版本自检的 `git ls-remote` 外不联网

## 使用方法

先按用户说法选入口，再按 Phase 执行。**三个 🔴 CHECKPOINT 必须停下来等人确认。**

### 使用方式（入口）

| 用户说法 | 执行范围 |
| --- | --- |
| 「优化所有 skills」 | Phase 0-3 全流程，默认先基线评估，按分数升序优化最低 5 个（用户指定才扩到 10 个） |
| 「优化 huashu-slides 这个 skill」 | 单个 skill：Phase 0 仍要建分支与 `results.tsv` → 0.5-2 → Phase 3 只出单 skill 卡片，不按分数挑多个 |
| 「评估所有 skills 的质量」 | Phase 0 只建分支与 `results.tsv`（不做优化）→ 0.5-1，出评分卡，不进入优化循环 |
| 「看看 skill 优化历史」 | 读并展示 `results.tsv` |

### 评估 Rubric（9 维度，总分 100）

**设计依据**：SkillLens 论文（arXiv 2605.23899）实测 LLM-as-judge 评估 skill 质量准确率仅 46.4%（接近随机），加入 meta-skill 三维度后升到 73.8%。rubric 因此强化 dim3 / dim5、新增 dim9。

结构维度（59 分）——静态分析：

| # | 维度 | 权重 | 评分标准 |
| --- | --- | --- | --- |
| 1 | Frontmatter 质量 | 7 | name 规范、description 含做什么+何时用+触发词、≤1024 字符、结尾不许加「灵活应用／根据情况判断」这类空话 |
| 2 | 工作流清晰度 | 12 | 步骤明确可执行、有序号、每步有输入/输出 |
| 3 | 失败模式编码 | 12 | 必须写出「如果 X 失败 → Y」的明确分支；只写正向流程而无法失败分支扣 ≥3 分 |
| 4 | 检查点设计 | 6 | 关键决策前有用户确认；检查点必须显性标记（🔴 / STOP / CHECKPOINT），光靠「建议…」措辞不算 |
| 5 | 可执行具体性 | 18 | 有具体参数、格式、示例；「建议／可以考虑／视情况而定」出现 ≥3 处扣 ≥3 分 |
| 6 | 资源整合度 | 4 | references / scripts / assets 引用正确、路径可达 |

效果维度（35 分）——需要实测：

| # | 维度 | 权重 | 评分标准 |
| --- | --- | --- | --- |
| 7 | 整体架构 | 12 | 层次清晰、不冗余不遗漏；AI 腔废话（说白了／换句话说／首先其次综上）出现一处扣 1 分 |
| 8 | 实测表现 | 23 | 用测试 prompt 跑一遍，输出是否达到 skill 宣称的能力 |

Meta-skill 维度（6 分）——反例与黑名单：

| # | 维度 | 权重 | 评分标准 |
| --- | --- | --- | --- |
| 9 | 反例与黑名单 | 6 | 必须有「不要做什么」的清单；只有「应该做 X」没有「不要做 Y」扣 ≥3 分 |

**评分规则**：dim 1-7、9 各打 1-10 分乘权重；dim 8 跑 2-3 条测试 prompt 后打分；**总分 = Σ(维度分 × 权重) / 10**。

⚠️ **绝对总分只用于 triage**（粗排「哪支最弱、先改谁」），**绝不用于 keep/revert**。实测同一份未改文字换个 judge 评，总分可摆 ±8；keep/revert 一律走 Phase 2 的 paired 比较。原因：LLM judge 给的是抽样不是测量——绝对分像用两台未校准的磅秤量节食前后，差值大半是磅秤差；paired 是同一台磅秤量前后，误差相减抵销。

**dim 8 怎么测**：为每个 skill 设计 2-3 条最典型（不是边缘 case）的用户 prompt → 子 agent 分别带 skill 和不带 skill（baseline）执行 → 对比输出是否完成意图、提升是否明显、有没有 skill 引入的负面影响。子 agent 不可用时退化为「干跑验证」并在 `results.tsv` 标 `dry_run`；**dry_run 比例 >30% → 评估失效警告**。

### Runtime 适配性审查（gate 项，独立于 9 维评分）

skill 应当能在 Claude Code / Codex / Cursor / OpenClaw / Hermes / Gemini CLI / OpenCode 等 runtime 通用，否则别的 agent 会把「在 Claude Code 里」这类措辞理解成「不是给我用的」而拒装。Phase 1 基线评估时强制跑一次红灯扫描：

```bash
grep -nE "(在 Claude Code|Claude Code skill|Claude Code 用户|Cursor only|Codex 中|^\[!\[Claude Code|~/\.claude/skills/[a-z]|/plugin install\b)" SKILL.md README.md 2>/dev/null
```

输出非空 ≠ 红灯：先读命中行上下文排除假阳性（grep 本身、反例引用、讲解该规则的元陈述），记 `runtime_scan=false_positive`；确认是真红灯（指令性用法）就把 Phase 2 第一轮定为 P0「runtime drift 修复」，`results.tsv` 的 note 记 `runtime_warn=N`。frontmatter 触发词、生态内 skill 名引用、明确标注 runtime-specific 的章节、commit message 属正当出现，不算红灯。→ 完整对照表见 [references/runtime-neutrality.md](references/runtime-neutrality.md)。该文件的扫描命令同样只给候选，必须先排除假阳性；两处表述不一致时**以本节为准**（上游自带的分歧，已记进 SOURCES）。

### Phase 0: 初始化

1. 确认优化范围（全部 / 指定列表）
2. 建分支 `auto-optimize/YYYYMMDD-HHMM`
3. 初始化本目录的 `results.tsv`（不存在时写表头）
4. 读历史，避免重复踩已回滚过的改法

### Phase 0.5: 测试 Prompt 设计

为每个 skill 读 SKILL.md、设计 2-3 条 prompt（典型 happy path + 一条稍复杂或歧义的），存入 `{skill目录}/test-prompts.json`：

```json
[{"id": 1, "prompt": "用户会说的话", "expected": "期望输出的简短描述"}]
```

**展示给用户，确认后再进入评估。** 没有测试 prompt，dim 8 的 23 分就是凭空打分。

### Phase 1: 基线评估（Baseline）——只用于 triage

对每个 skill：主 agent 按 dim 1-7、9 打分（附一句理由）→ 每条测试 prompt spawn 两个子 agent：with_skill 把该 SKILL.md 全文放进子 agent 上下文（或按它的安装方式加载），baseline 用同一 prompt、不加载 SKILL.md、其余设置一致 → 对比后给 dim 8 打分 → 算加权总分 → 写 `results.tsv`。

子 agent 不可用时 dim 8 用干跑，标 `dry_run`——跑不了测试也不能跳过这个维度。

**🔴 CHECKPOINT · 🛑 STOP**：展示评分卡（skill、总分、结构短板、效果短板）后暂停，等用户确认再进优化循环。

### Phase 2: 优化循环

按基线分从低到高排序，先优化最弱的。`MAX_ROUNDS` 默认 3，逐轮执行：

1. **诊断**：找加权短板最大的维度，`weighted_gap = weight × (10 - score) / 10`。不用「原始分最低」——低权重维度会制造进步幻觉（实战：dim9 原始分最低被优先修，而 dim8 加权短板最大却 4 轮未动）。加权短板差距 ≤1.0 时回退为原始分升序。注意 dim2/3/4 是相关簇，修一个另两个常跟着涨。
2. **提方案**：改哪个段落、对应 rubric 哪条、预期提升多少分。**每轮只改一个维度**。
3. **改（先不提交）**：只改工作树里的 SKILL.md，`git add` 与 commit 留到裁决之后。路径一律用**仓库相对路径**（先 `git rev-parse --show-toplevel` 拿仓库根；git 不接受绝对路径）。
4. **Paired 重评**：spawn N=3 独立 judge，每个在**同一次 call 内**读两版——改前 `git show HEAD:<仓库相对路径>`、改后工作树文件——照 9 维 rubric 当**比较准则**（不是各打绝对分），回 `{better | worse | tie}` + `margin{clear | slight}` + 一句理由。同一 judge 一次比两版，它那把不准的尺对两版等量作用、比较时抵销。
   - **前置断言**：`git diff --quiet HEAD -- <path>` 必须为假（两版确实不同）。为真说明改动没落盘，立即中止并报错——拿同一份文本比出来的 tie 是假通过。
   - **close call**：3 票里票差 ≤1（如 2 better / 1 tie）时升到 5 名 judge 重投。
5. **多数决**：
   - better 票 ≥ worse 票 → `keep`：`git add <path> && git commit -m "optimize {skill}: {改进摘要}"`。**先判后提交**，这样 `HEAD` 始终是「上一个 kept 版本」，paired 比较的永远是两个不同版本。
   - worse 票占多数 → 丢弃改动 `git checkout -- <path>`，`results.tsv` 记票数与一句 worse 理由，break。不产生回滚 commit——这次尝试的审计由 `results.tsv` 那一行承担（`status=revert` + 票数 + 理由）。
   - 连续 2 轮多数判 `slight` 或 `tie` → break 进 Phase 3。
6. **复评绝对分（只为报告）**：keep 后由同一批 judge 按 rubric 重打一次绝对分作为 After，Before 取 Phase 1 基线（后续轮取上一轮 After）。这两个分数只进报告与卡片，**不参与 keep/revert 判决**。
7. **记日志**：`results.tsv` 追加一行。

单评绝对分出现「负 delta」不是 revert 信号——必须经 paired 多数判 worse 才回滚，否则在丢真实增益。

**🔴 CHECKPOINT**：每个 skill 优化完强制人审，展示 `git diff`、分数变化、测试输出对比；等用户确认 OK 再继续下一个。用户说「不好」→ 对该 skill 最后一轮 keep 的 commit 执行 `git revert <sha>`，并在 `results.tsv` 补一行 `status=revert`、`note=user_reject`，不要静默丢弃。

### Phase 2.5: 探索性重写（按需）

hill-climbing 连续 2 个 skill 都在 round 1 就 break 时，提议一次重写：`git stash` 存当前最优 → 从头重写 SKILL.md（重组结构与表达，不是微调）→ 重评 → 重写版更好则采用，否则 `git stash pop` 恢复。这解决局部最优。**🔴 CHECKPOINT · 🛑 STOP**：必须征得用户同意才执行。

### Phase 3: 汇总报告

输出总览（优化 skill 数、实验次数、保留/回滚数、完整测试与干跑次数）、分数变化表（Before / After / Δ）、主要改进 1-2-3 条。随后生成成果卡片：

- **选模板**：三份都是独立模板，不是靠 hash 切风格——复制一份改字段即可。`result-card.html` 是总览卡（含 `top1-*` / `top2-*` 两条最亮改动），`-white.html` / `-dark.html` 是字段更少的单风格变体（10-15 个字段 vs 19 个）
- **填数**：**先从模板里取字段清单**再填，不要照文档猜——`grep -o 'data-field="[^"]*"' <模板> | sort -u`。主模板的字段是 `skill-id` / `skill-name` / `score-before` / `score-after` / `score-delta` / `improve-1` `improve-2` `improve-3` / `date` / `top1-*` / `top2-*`；上游文档写的 `improvement-1` 与 `dim-bar-*` 在这套模板里不存在，照抄会留下空占位符
- **截图**：`node skills/darwin-skill/scripts/screenshot.mjs <card.html 绝对路径> <out.png 绝对路径>`（2x 高清、只截 `.card`）；脚本失败时回退 `npx playwright screenshot "file:///…/card.html" out.png --viewport-size=960,1280 --wait-for-timeout=2000`
- **存哪**：动手前问用户，默认 `./optimize-<skill>-YYYYMMDD-HHMM.png`
- **何时出**：单 skill 优化完出一张；全量完成后出总览一张
- **分支收尾（Phase 3 结束前必做）**：问用户「合回主分支（`git checkout main && git merge --no-ff`）/ 保留分支 / 删除分支」，不自动合并、不擅自删

→ 完整生成流程与品牌元素见 [references/result-card.md](references/result-card.md)。

### results.tsv 格式

```tsv
timestamp	commit	skill	old_score	new_score	status	dimension	note	eval_mode
2026-03-31T10:00	baseline	huashu-proofreading	-	78	baseline	-	初始评估	full_test
2026-06-10T06:30	paired	some-skill	87.3	89.6	keep	dim8	3-0 better clear；单评 78.8 属换尺噪音	paired
```

`eval_mode`：`paired`（同 judge 比改前/改后，**keep/revert 的权威依据**）｜`full_test`（子 agent 跑 prompt）｜`dry_run`（模拟推演，仅供参考）。文件位置：本目录 `results.tsv`，跨 skill、跨仓库累积；提交时随优化 commit 一起进历史。

### 实战 high-leverage 四条

- **HL-1（dim4）显性视觉标记是杠杆**：加 🔴 CHECKPOINT / 🛑 STOP，4 行改动可撬动 dim4 +3 分；靠「必须」措辞没用，LLM 扫的是视觉标记
- **HL-2（dim3）if-then 三段式 fallback 表**：把「症状／解法」两列升级为「触发条件 / 一线修复 / 仍失败兜底」
- **HL-3（Phase 2 诊断）维度相关簇**：dim2/3/4 同涨同落，看最大加权短板时同时看整簇
- **HL-4（Phase 2 退出）触顶即 break**：主判据是 paired 连续 2 轮判 `slight`/`tie`；第 6 步的复评绝对分 Δ<2 只作参考。+0.15 是停手信号，硬凑满 3 轮只会 over-engineering

### 优化策略库（P0 → P3）

每轮只做最高优先级的一个：P0 是 runtime 红灯与实测跑偏，P1 是结构与检查点缺失，P2 是步骤模糊、缺输入输出规格、缺异常处理，P3 是可读性。→ 逐条清单见 [references/strategy-library.md](references/strategy-library.md)。

## 注意事项

### 异常与边界条件

流程假设环境理想，实操常遇异常。以下 fallback 保证不「一跑就卡住」：

| 场景 | 触发条件 | 处理动作 |
| --- | --- | --- |
| 不在 git 仓库 | `git rev-parse` 失败 | 问用户：`git init`，或退回文件备份 `cp SKILL.md SKILL.md.bak.YYYYMMDD-HHMM` 代替 revert |
| `results.tsv` 缺失 / 损坏 | 文件不存在，或列数不匹配 | 缺失则写表头新建；损坏则备份为 `.bak.YYYYMMDD-HHMM` 后重建并告知 |
| 分支已存在 | `git checkout -b` 失败 | 分支名加 `-2` / `-3`；第 3 次失败则切回现有分支并问用户 |
| `git revert` 失败 | 冲突或工作树脏 | 先 `git stash` 重试；仍失败则从上一 commit 读出 SKILL.md 覆盖手改 |
| MAX_ROUNDS 触顶 | 已跑 3 轮仍有短板 | 不强制 break，展示最弱维度问「再加 1 轮 / 进 Phase 2.5 / 收工」 |
| 优化后超 150% 体积 | 新文件 > 原 × 1.5 | 拒绝提交，回改进步骤精简冗余再评 |
| `test-prompts.json` 已存在 | 文件已在 skill 目录 | 默认复用并展示，问「复用 / 重写 / 追加」 |
| 找不到 SKILL.md | 目录存在但无 SKILL.md | 该 skill 终止，`results.tsv` 记 `status=error`，继续下一个 |
| runtime 起不了独立子 agent | judge 无法 spawn | Phase 2 不得自治：只输出单轮改动方案交人审，`results.tsv` 标 `eval_mode=self_review`、结论标「参考」，**不冒充 paired 判决** |
| 工作树有未提交改动 | `git status` 非空且与本轮无关 | 先问用户 stash / 先提交 / 另起分支，不要带着别人的改动建优化分支 |

**原则**：异常先告知用户再按规则处理，绝不静默跳过或静默失败。

### darwin 操作反例黑名单（dim9 自用）

来自本机 `results.tsv` 早期 40 次 0 revert 的教训。每轮 Phase 2 改动前对照一次，命中即改方案：

| # | 反模式 | 替代做法 |
| --- | --- | --- |
| 1 | 同 context 自评自改 | 必须 spawn 独立子 agent；keep/revert 走 paired 奇数 N 多数决 |
| 1b | 拿绝对分数 delta 当棘轮 | 绝对分只做 triage；paired 的 within-judge 抵销消除换尺污染 |
| 2 | 用 `git reset --hard` 回滚 | 未提交的改动用 `git checkout -- <path>` 丢弃；已提交的坏改动用 `git revert <sha>`。`reset --hard` 会连别人的未提交改动一起抹掉 |
| 3 | 为凑分增冗余 | 触顶信号（paired 连续 2 轮判 slight/tie）即 break；绝对分 Δ<2 只作参考，不作判据 |
| 4 | 跳过 test-prompts 直接评分 | Phase 0.5 强制设计 2-3 条；用户不给就默认编 3 条并展示确认 |
| 5 | 轮内改多个维度 | 每轮 1 个维度，否则分数升降无法归因 |
| 6 | dry_run 比例 >30% | 强制至少 1 次真实 full_test，dry_run 多的行显式打 ⚠️ |
| 7 | 静默跳过异常 | 异常表逐条先告知用户再处理 |
| 8 | 忽视维度相关性单独优化 | 找最大加权短板时同时看 dim2/3/4 整簇 |

### 约束规则

1. 不改 skill 的核心功能与用途——只改「怎么写、怎么执行」
2. 不引入新依赖：不擅自给被优化的 skill 加 scripts 或 references
3. 每轮只改一个维度
4. 优化后 SKILL.md 不超过原始体积的 150%
5. 所有改动在 git 分支上，用 `git revert` 不用 `reset --hard`
6. dim 8 必须用子 agent 或至少干跑验证，不能在同一上下文里改完直接评
7. Runtime 中立：除非 skill 名明确绑定单一 runtime，否则「在 Claude Code 里」「安装路径只给 `.claude/skills/`」都算 gate 不通过，P0 必修

### 版本自检（静默）

每次使用前读本目录 `.last-update-check`（一行 `YYYY-MM-DD ok|failed|off`；不存在视为到期）。`off`、`ok` 不足 30 天、`failed` 不足 7 天 → 跳过本节，不提任何更新相关的话。到期时跑 `git ls-remote https://github.com/alchaincyf/darwin-skill HEAD`，与 frontmatter 的 `metadata.upstream_commit` 比较，写入 `<今天> ok` 或 `<今天> failed`。**不要用本目录 HEAD 比**——本目录在 gourd 仓库内，`git -C` 命中的是 gourd 的 origin，会每次误报有新版本。上游落后时先完成用户当前任务，收尾附一句「上游 darwin-skill 有新提交，本目录快照基于 <短 SHA>」，是否更新由用户决定，不主动执行。

## 来源与许可证

- 上游：[alchaincyf/darwin-skill](https://github.com/alchaincyf/darwin-skill)，作者花叔（[@AlchainHust](https://x.com/AlchainHust)），MIT，快照 commit `8a8b662`（2026-09-18），移植于 2026-10-27
- 学术依据：SkillLens（arXiv 2605.23899，9 维 rubric 的实证来源）、SkillOpt（arXiv 2605.23904，validation-gated 机制）、Karpathy 的 autoresearch（1.0 的灵感）
- 本目录的改动：按本仓库九节重排；策略库与成果卡片两节原文外置到 `references/`；`templates/` 收进 `assets/templates/` 以符合「一技能一目录」；未收录上游 `showcase.html`、`docs/`、宣传图与大图（链接见 [references/SOURCES.md](references/SOURCES.md)）
- 除 [references/SOURCES.md](references/SOURCES.md) 记录的刻意偏离（如先判后提交）外，上游原文与本文冲突时以上游为准，并按下文同步
- 参考资料按 MLA 记在 [references/SOURCES.md](references/SOURCES.md)，那里同时有 healthcheck 块与与上游同步的步骤
- 许可证：MIT（与仓库一致），上游许可证原文见 [LICENSE.upstream](LICENSE.upstream)
