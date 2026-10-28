# 资料来源（MLA 格式）

本技能是 [alchaincyf/nuwa-skill](https://github.com/alchaincyf/nuwa-skill)（MIT）的移植版本，不是原创。上游原文的著作权归作者花叔所有，上游许可证见 [../LICENSE.upstream](../LICENSE.upstream)。

## 上游来源

- 花叔. "nuwa-skill." *GitHub*, 2026, github.com/alchaincyf/nuwa-skill. Accessed 27 Oct. 2026.
- 花叔. "达尔文.skill（darwin-skill）." *GitHub*, 2026, github.com/alchaincyf/darwin-skill. Accessed 27 Oct. 2026.
  - 女娲 Phase 5 的双 Agent 精炼内嵌了达尔文的评估体系，两个技能互为上下游。
- "Agent Skills Specification." *Agent Skills*, agentskills.io/specification. Accessed 27 Oct. 2026.

上游快照：commit `7c7edfeb9d90a28b1f79e7847e1ba27a698cdc24`，提交时间 2026-10-24T16:12:03Z，移植日期 2026-10-27。

## 未收录的上游内容（只留链接）

| 内容 | 链接 | 不收录的原因 |
| --- | --- | --- |
| `examples/` 现成人物 Skill（乔布斯、芒格、卡帕西、MrBeast 等） | github.com/alchaincyf/nuwa-skill/tree/main/examples | 二十余个目录、数十 MB 图片，与本仓库「一技能一目录」约定冲突；需要时按上游路径取 |
| 宣传图与演示动画（`assets/hero.gif` 等） | github.com/alchaincyf/nuwa-skill/tree/main/assets | 单文件 2-10 MB，超过本仓库 200KB 二进制上限 |
| 多语种 README | github.com/alchaincyf/nuwa-skill | 与技能执行无关 |

## 移植范围与改动（为什么改，不写改了什么）

为满足本仓库约定（`SKILL.md` ≤500 行、九节骨架、`[技能目录]` 运行期中立），做了三类改动：

1. **结构重排**：上游 `## 核心理念` / `## 执行流程` 的顺序改为「用途 → 文件结构 → 输入 → 输出 → 依赖 → 使用方法」。Phase、阈值、黑名单条目一条未删。
2. **细节外置**：Phase 0B（79 行）、Phase 1（148 行）、回答工作流（58 行）三段整段原文移入 `references/`，正文保留判断所必需的表格与一行指路。外置的是细节，不是判断。
3. **运行期中立**：上游硬编码的 `.claude/skills/` 统一写成 `[技能目录]`。原因：达尔文 rubric 把「只认 Claude Code 路径」列为 gate 失败项，移植时不该把同一个坑带进来。外置切片里的两处同类路径（`research-swarm.md`、`diagnosis-path.md`）同样只替换路径，判据文字未动。
4. **版本检查改写**：上游按「本目录是 git 克隆」比对 tag；本目录在 gourd 仓库内，`git -C` 指向的是 gourd 的 origin。改为比对 `git ls-remote` 的上游 HEAD 与 frontmatter 的 `metadata.upstream_commit`。

5. **补齐上游留白**（冷启动测试发现，属「据惯例补齐」，不是上游原文）：
   - 上游 `[skill目录]` 同时指女娲自己的目录与目标技能目录，同一个词两个含义，已拆成 `[本技能目录]` / `[目标目录]`
   - 上游 Phase 5 只说「8 维度结构评估」而没有列出维度，按它与 darwin rubric 的对应关系写明是 dim2-dim9 那八项
   - 上游「快速档 = 3 个维度」与后文写死的 6 维流程没有映射，补进「特殊场景」
   - 上游正文写「三个检查点」，实际有四个 🔴（1.5 / 2.5 / 4 / 5），改为四个
   - 4.4 通过标准写「3-7 个」，失败信号写「<3 或 >10」，8-10 个无判据，改为「>7 须在验证报告说明理由」
   - 上游 Phase 5 的八项只给了维度名、没给评分锚点，补了一档 1-10 含义（3/5/8/10 四个锚点），并指明与 darwin 的 dim2-dim9 同口径
   - Phase 0A 把「逐条确认」压成一句、并保留了两处原文关键句（本地素材怎么问、成本量级怎么说）；`.last-update-check` 缺失按「到期」处理，上游未定义此分支

## 与上游同步的步骤

上游发新版时（`metadata.version` 或 `upstream_commit` 变化）：

```bash
# 1. 取上游最新
git clone --depth 1 https://github.com/alchaincyf/nuwa-skill.git /tmp/nuwa-upstream
# 2. 对照差异：正文对应上游 SKILL.md，references 三个切片对应同名段落
diff -u /tmp/nuwa-upstream/SKILL.md skills/huashu-nuwa/references/research-swarm.md
# 3. 有实质变化时改正文与方法，更新 frontmatter 的 upstream_commit、本文件的快照与 last_reviewed
```

上游 `SKILL.md` 是唯一权威。正文与上游冲突时以上游为准；外置切片与上游对应段落不一致时，先修切片。

## healthcheck

```yaml
version: 1.0.0
last_reviewed: 2026-10-27
review_every_days: 30
anchor_path: skills/huashu-nuwa/references/research-swarm.md
anchor_path: skills/huashu-nuwa/references/answer-protocol.md
anchor_path: skills/huashu-nuwa/references/skill-template.md
anchor_path: skills/huashu-nuwa/scripts/quality_check.py
anchor_cmd: python3 --version
anchor_cmd: bash --version
anchor_url: https://github.com/alchaincyf/nuwa-skill
probe: 上游仍是 Phase 0 → 5 六个阶段，且 Phase 4 通过标准仍是六项（增删项即需同步）
probe: 上游仍把知乎、微信公众号、百度百科列为信息源黑名单，没有放开
probe: 上游 skill-template.md 仍含「回答工作流（Agentic Protocol）」一节
probe: 上游 examples/ 仍以 <person>-perspective/ 命名，Phase 0.5 的目录约定未变
probe: 上游仍要求「所有调研文件必须存在 skill 目录内部」，没有改存外部目录
```

周期取 30 天而非仓库默认 5 天：上游按版本发版、不是每周变动，5 天会制造无效复核。判断层面的过时（阈值失效、黑名单过时）靠上面五条探针，不靠 TTL。

## 使用事件

只记三类异常：漏触发、误触发、卡壳。同类累计 3 次 → 触发 L3 重构。

| 日期 | 类型 | 现象 |
| --- | --- | --- |
