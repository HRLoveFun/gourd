# 技能索引

| 技能名称 | 用途 | 路径 | 状态 |
| --- | --- | --- | --- |
| skill-forge | 把材料提炼成符合本仓库约定的 skill，并做体检与修订 | [skills/skill-forge/](skills/skill-forge/) | 可用 |
| ai-engineering-audit | 审查 AI 参与产出的软件，按过剩设计、需求真实性、反馈层级、认知债务四条轴找出问题，产出带证据的发现与一条主判断。当用户说「这个 AI 写的模块帮我把把关」「是不是过度设计了」「需求老变要不要推倒重来」「测试全绿但我看不懂这系统了」「该继续加功能还是先停下来整理」时使用。不适用于单个函数的 code review、性能调优、从零写新项目、纯技术选型。 | [skills/ai-engineering-audit/](skills/ai-engineering-audit/) | 可用 |
| huashu-nuwa | 把一个人物或主题蒸馏成可运行的人物 Skill：六维并行调研 → 三重验证提炼心智模型 → 组装后用子 Agent 验证与精炼。当用户说「造一个XX的skill」「蒸馏XX」「用XX的视角看这个问题」「更新XX的skill」时使用。不适用于纯资料整理、一次性问答、需要实时行情或私域数据的查询。移植自 alchaincyf/nuwa-skill（MIT）。 | [skills/huashu-nuwa/](skills/huashu-nuwa/) | 可用 |
| darwin-skill | 按 9 维 rubric 评估并迭代优化 Agent Skill：基线评分 → 单维度改进 → 独立 judge 做 paired 多数决 → 保留改进、退步回滚，git 留痕并出成果卡片。当用户说「优化这个 skill」「给 skill 打分」「达尔文」「skill 质量检查」时使用。不适用于从零写新 skill、单函数 code review、只想跑一次格式检查。移植自 alchaincyf/darwin-skill（MIT）。 | [skills/darwin-skill/](skills/darwin-skill/) | 可用 |
| doc-architecture | 为项目设计、落地并维护分层文档体系：以 AGENTS.md 为唯一入口和文档地图，按读者的问题分层（L0–L3），用单一事实来源与写入时机表防止文档随迭代漂移，并用 doc-check.sh 对账地图与文件。当用户说「给这个项目建一套文档体系」「文档越写越乱，帮我重构」「agent 不知道先看哪份文档、进度在哪」「文档和代码对不上，怎么防止越改越飘」「新项目开工，先把文档结构定下来」时使用。不适用于润色单份文档、生成 API 参考、知识库/笔记系统、无代码的纯写作项目。 | [skills/doc-architecture/](skills/doc-architecture/) | 可用 |
| ub-mode | 用 Uncle Bob 的三段式纪律约束每一次代码改动：先让它跑起来（最小改动、TDD、先定数据形状），再让它正确（修根因、测行为、把 CRAP／重复度／变异三道确定性门禁压到阈值内），最后按实践收尾（动作日志、上下文窗口、小步有序提交）。移植自 unclebob/ub-mode（上游未声明许可证，仅中文重写）。 | [skills/ub-mode/](skills/ub-mode/) | 可用 |
| git-auto-flow | 把一次代码改动收尾成固定流程：按规范提交 → 跑增量编译（默认 ic）→ 成功后合并到目标分支 → 清理已合并的本地与远端分支及失效追踪引用。默认演练，--apply 才落地，保护分支不写不删。当用户说「提交并合并」「走自动流程」「改完了收尾」「清理已合并分支」时使用。不适用于跨仓库发布、打 tag 发版、需要人工解冲突的合并。 | [skills/git-auto-flow/](skills/git-auto-flow/) | 可用 |

说明：

- 状态取值：`可用` / `草稿` / `待迁移` / `已废弃`
- 根目录 `template/` 是模板，不算技能，不列入本表
- 新增技能时按 `README.md` 的「新增一个技能」流程，同步更新本表
- 已废弃的技能删目录、留本表一行，备注删除的 commit 短哈希
