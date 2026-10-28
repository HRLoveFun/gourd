# 资料来源（MLA 格式）

本技能是 [alchaincyf/darwin-skill](https://github.com/alchaincyf/darwin-skill)（MIT）的移植版本，不是原创。上游原文的著作权归作者花叔所有，上游许可证见 [../LICENSE.upstream](../LICENSE.upstream)。

## 上游来源

- 花叔. "darwin-skill（达尔文.skill 2.1）." *GitHub*, 2026, github.com/alchaincyf/darwin-skill. Accessed 27 Oct. 2026.
- 花叔. "nuwa-skill（女娲.skill）." *GitHub*, 2026, github.com/alchaincyf/nuwa-skill. Accessed 27 Oct. 2026.
  - 女娲 Phase 5 的双 Agent 精炼用的是本技能的评估体系；反过来本技能可优化女娲生成的人物 Skill。
- Karpathy, Andrej. "autoresearch." *GitHub*, 2026, github.com/karpathy/autoresearch.
  - 1.0 的灵感来源：program.md / train.py / val_bpb / git ratchet 四件套的对应关系见 SKILL.md 的「设计灵感」。
- "SkillLens: Evaluating Agent Skills with Meta-Skill Dimensions." *arXiv*, 2026, arxiv.org/abs/2605.23899.
  - 9 维 rubric 的实证来源：LLM-as-judge 准确率 46.4% → 加入 meta-skill 三维度后 73.8%。
- "SkillOpt: Validation-Gated Skill Optimization." *arXiv*, 2026, arxiv.org/abs/2605.23904.
  - validation-gated edits 的形式化框架；微软官方仓库已把 darwin-skill 列入集成名单。
- Microsoft. "SkillOpt." *GitHub*, 2026, github.com/microsoft/SkillOpt. Accessed 27 Oct. 2026.

上游快照：commit `8a8b66258e3c45d6ae4aea39719468c6428fcb0a`，提交时间 2026-09-18T21:16:41+08:00，移植日期 2026-10-27。

## 未收录的上游内容（只留链接）

| 内容 | 链接 | 不收录的原因 |
| --- | --- | --- |
| 宣传页与文档站（`showcase.html`、`docs/index.html`） | github.com/alchaincyf/darwin-skill | 与技能执行无关，且内含大图 |
| 图表素材（`assets/*.png`、`hero.gif`、`chart-*.html`） | github.com/alchaincyf/darwin-skill/tree/master/assets | 单文件 1-10 MB，超过本仓库 200KB 二进制上限 |
| 成果卡片示例图 | github.com/alchaincyf/darwin-skill/tree/master/templates | 878KB，模板 HTML 已保留，需要时本地截图即可 |
| 多语种 README | github.com/alchaincyf/darwin-skill | 与技能执行无关 |

## 移植范围与改动（为什么改，不写改了什么）

1. **结构重排**：上游是「Rubric → 自主优化循环 → 报告 → 策略库 → 边界 → 黑名单 → 约束 → 使用方式」的散文顺序，改为「用途 → 文件结构 → 输入 → 输出 → 依赖 → 使用方法 → 注意事项」。9 维权重、`MAX_ROUNDS=3`、`dry_run >30%`、`150%` 体积上限这些阈值一个没动。
2. **细节外置**：优化策略库（30 行）与成果卡片生成（54 行）两节原文移入 `references/`，正文保留入口与一行指路。
3. **目录归位**：上游把卡片模板放在顶层 `templates/`，本仓库只认 `assets/`，故移到 `assets/templates/`；`screenshot.mjs` 的默认路径原本还指向移植前的 `../templates/…`，失败测试确认无参数时读不到文件，已改为 `../assets/templates/…`，显式传参与默认值都可用。`result-card.md` 里的 `templates/`、`.claude/skills/darwin-skill/` 两处旧路径已同步改成 `assets/templates/` 与 `skills/darwin-skill/`。
4. **版本自检改写**：上游假设本目录是上游仓库的 git 克隆；本目录在 gourd 仓库内，`git -C` 指向 gourd 的 origin。正文改为比对 `git ls-remote` 的上游 HEAD，并保留 `metadata.upstream_commit` 作为本目录的快照坐标。
5. **description 改写**：上游是英文长句 + 关键词串，本仓库要求「做什么 + 何时用 + 边界」的中文句式且必须写「不适用于」；触发词（优化 skill / 打分 / 达尔文 / skill review）全部保留。

6. **修了上游一个会让核心机制静默失效的 bug**（冷启动测试发现，属有意偏离上游）：
   - 上游 Phase 2 先 `git commit`、再用 `git show HEAD:<path>` 当「改前版」。提交之后 `HEAD` 已经是新版，两次读到的是**同一份文本**，judge 只能给 tie；tie 按规则算 keep，于是每轮都保留、revert 永不触发，而 `results.tsv` 会记成「paired 已通过」——恰好复现上游自己警告的「40 次 0 revert」。
   - 本目录改为**先判后提交**：改工作树 → paired 比较 `HEAD` 与工作树 → keep 才 commit，worse 则 `git checkout -- <path>` 丢弃。这样 `HEAD` 始终是「上一个 kept 版本」，比较的永远是两个不同版本，并加了「`git diff --quiet HEAD -- <path>` 必须为假」的前置断言。
   - 连带改动：`revert` 不再是「造一个反向 commit」（没有 commit 可反向），被拒尝试的审计由 `results.tsv` 的 `status=revert` 行承担；「用户说不好」的回滚改为对最后一轮 keep 的 commit 执行 `git revert <sha>`。
   - 同步补了上游的三处空白：keep 后重打一次绝对分供报告/卡片使用（并声明不参与裁决）、单 skill 的 Phase 边界（Phase 0 与 3 仍要跑）、异常表新增「起不了独立子 agent」与「工作树有未提交改动」两行。

7. **description 与版本自检的本地化**：description 按本仓库句式重写（上游是英文长句 + 关键词串，且不含「不适用于」边界）；版本自检改为比对 `metadata.upstream_commit`，因为本目录在 gourd 仓库内，`git -C` 命中的是 gourd 的 origin，按上游写法会每次误报有新版本。

8. **上游文档与自带模板不符**（实测）：`result-card.md` 里的 `dim-bar-before/after`、`improvement-1/2/3`、以及「改 URL hash 切 swiss/terminal/newspaper」在模板里都不存在——模板字段是 `improve-1/2/3`，另有 `top1-*` / `top2-*`，且三份模板是彼此独立的文件、不靠 hash 切换。切片已按模板改写，不再保留错误原文。

9. **独立冷启动与失败测试（2026-10-28）**：子 Agent 冷启动通过，报告一处模糊（「只优化最低 5-10 个」没给判据）与三处矛盾。已修：入口补默认值 5 个；黑名单 #3 的 break 判据改为与 HL-4 一致的 paired 连续 2 轮 slight/tie，绝对分 Δ<2 只作参考；`result-card.md` 的风格表、字段名、回退命令按模板实测改写；`runtime-neutrality.md` 的「grep 输出即红灯」改为先排假阳性。复测又修四处：SKILL.md 对 runtime 文件的引用句、`assets/test-prompts.json` 的触顶口径、`skilllens-evidence.md` 的触顶信号、输出表「3 种风格随机」改为三份模板择一。失败测试另修 `screenshot.mjs` 默认路径（无参数时读不到模板）。

## 与上游同步的步骤

```bash
git clone --depth 1 https://github.com/alchaincyf/darwin-skill.git /tmp/darwin-upstream
diff -u /tmp/darwin-upstream/SKILL.md skills/darwin-skill/references/strategy-library.md
diff -u /tmp/darwin-upstream/templates/result-card.html skills/darwin-skill/assets/templates/result-card.html
# 有实质变化时改正文与阈值，更新 frontmatter 的 upstream_commit、本文件快照与 last_reviewed
```

上游 `SKILL.md` 是唯一权威。正文与上游冲突时以上游为准。

## healthcheck

```yaml
version: 2.1.0
last_reviewed: 2026-10-28
review_every_days: 30
anchor_path: skills/darwin-skill/references/strategy-library.md
anchor_path: skills/darwin-skill/assets/templates/result-card.html
anchor_path: skills/darwin-skill/assets/test-prompts.json
anchor_path: skills/darwin-skill/scripts/screenshot.mjs
anchor_cmd: git --version
anchor_url: https://github.com/alchaincyf/darwin-skill
probe: 上游仍是 9 维 rubric、权重合计 100（改维度或改权重即需同步）
probe: 上游 keep/revert 仍走 paired 奇数 N 多数决，绝对分数仍只作 triage
probe: 上游仍要求每轮只改一个维度、每 skill 收尾人审
probe: 上游反例黑名单仍是 8 条（含 1b），没有新增公认反模式
probe: 上游仍把「只认 Claude Code 路径」列为 runtime gate 失败项
```

周期取 30 天而非仓库默认 5 天：上游按版本发版（v2.0 → v2.1 间隔两周），5 天会制造无效复核；判断层面的过时由五条探针负责。

## 使用事件

只记三类异常：漏触发、误触发、卡壳。同类累计 3 次 → 触发 L3 重构。

| 日期 | 类型 | 现象 |
| --- | --- | --- |
| 2026-10-28 | 卡壳 | 独立冷启动（子 Agent）：入口「最低 5-10 个」无选取判据；已补默认 5 个、上限 10 个 |

## 三测记录（2026-10-28）

```text
触发测试：命中 5/5 句；无关句 0/3 误命中（32 句由独立子 Agent 按四份 description 路由）
冷启动：子 Agent 独立执行，修复两轮后卡点 0；修复项见「移植范围与改动」第 9 条
失败测试：缺 playwright → 明确提示安装并退出 1；无参数默认路径已指向存在的模板；results.tsv 缺失/损坏按异常表重建（文档路径，未自动验证）
结论：可用
```
