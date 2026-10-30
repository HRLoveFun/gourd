# 资料来源（MLA 格式）

本技能是 [unclebob/ub-mode](https://github.com/unclebob/ub-mode) 的中文重写版，不是原创。上游只有一个 `SKILL.md`，著作权归 Robert C. Martin 所有；该仓库**没有 `LICENSE` 文件**，按默认版权规则即保留所有权利，因此本目录**不收录上游原文**，只保留方法的中文转述与链接。

## 本技能用到的资料

- Martin, Robert C. "ub-mode." *GitHub*, 2026, github.com/unclebob/ub-mode. Accessed 30 Oct. 2026.
  - 三段结构与全部规则条目的来源。快照 commit `57a8bdd28e45ed41900ace0bafa2ff76dd9ed70f`（2026-10-25，仓库共 4 次提交）。
- Martin, Robert C. "crapper." *GitHub*, 2026, github.com/unclebob/crapper. Accessed 30 Oct. 2026.
  - CRAP 公式 `CC² × (1 − coverage)³ + CC`、风险分档（1–5 低 / 5–30 需看 / 30+ 高风险）、`./crapper` 调用方式与 `.metrics/crap.edn` 输出。
- Martin, Robert C. "dryer." *GitHub*, 2026, github.com/unclebob/dryer. Accessed 30 Oct. 2026.
  - 结构指纹的 Jaccard 相似度、默认 `--threshold 0.82`、`.metrics/dry.edn` 输出。
- Martin, Robert C. "mutator." *GitHub*, 2026, github.com/unclebob/mutator. Accessed 30 Oct. 2026.
  - 变异测试的调用方式、退出码（0 全杀 / 2 基线失败 / 3 有存活体）、依赖 `crapper` 检出在 `../crapper`。
- Martin, Robert C. "uml-viewer." *GitHub*, 2026, github.com/unclebob/uml-viewer. Accessed 30 Oct. 2026.
  - 只在「依赖」中作为可选工具提及；仓库内未见 `LICENSE` 文件。
- Poteto. *GitHub*, 2026, github.com/poteto. Accessed 30 Oct. 2026.
  - 上游 README 自述其规则部分借鉴 `poteto-mode` / `pstack`（**未核对原仓库内容**，仅记录上游的说法）。

## 未收录的上游内容

| 内容 | 链接 | 不收录的原因 |
| --- | --- | --- |
| 上游 `SKILL.md` 原文 | github.com/unclebob/ub-mode/blob/master/SKILL.md | 上游无许可证，整篇复制有版权风险；Git 历史删不干净 |
| 上游 `README.md` 的安装指引原文 | github.com/unclebob/ub-mode | 同上；安装方式在本仓无意义（本仓按 `skills/<name>/` 组织） |

## 移植范围与改动（为什么改，不写改了什么）

1. **语言与结构**：上游是英文项目符号清单，只有 `First Make it Work / Then Make it Right / Practice` 三个标题。本仓要求中文正文 + 九节骨架，故按「用途 → 文件结构 → 输入 → 输出 → 依赖 → 使用方法 → 注意事项 → 来源与许可证」重排；三段标题与顺序保留，40 条规则一条不少。
2. **增加「判定」列与落地动作**：上游只写「该做什么」，没写「什么时候这条真正生效」。冷启动时最容易卡在这一步——规则都对，但不知道此刻要不要用。故每条补一行可观察的触发条件（如「这次改动是否只有新增、没有删除」），判断依据全部来自上游句子的直接含义，不新增规则。
3. **门禁工具缺失时的降级路径**：上游默认 `crapper`／`dryer`／`mutator` 已就位，未写工具不在时如何。本仓要求「每句已完成都要能指到证据」，故明确：没跑就标「未运行」，且**三道全未运行时只能声明「跑起来了 + 修的是根因 + 测试测的是行为」，不得声明「正确」或「通过」**。降级后仍走第一段与第二段的「修根因 + 测行为」。
4. **判定线来源唯一化**：上游写「CRAP < 10」「重复度 0.8」，而 crapper 的 README 用 1–5 / 5–30 / 30+ 分档、dryer 默认 `--threshold 0.82`。三个数并存会让「确定性门禁」失去唯一判定，故补一条仲裁顺序：项目已有配置听项目的；没有则用 10 与 0.8，并注明这是上游口径而非工具默认值；两套口径都要报。
5. **提交与推送改为需授权**：上游最后一条要求「push to the main line」。本仓与常见用户环境的约定是提交必须先获批，故改为「未获授权只给建议的提交切分」，机制不变、权限归用户。
6. **「攻击前提」补执行对象**：上游「count which actors hold the imbalance. Remove the assignment.」中 actor 与 assignment 都没定义，是全篇最不可执行的一句。本目录改写为「数清哪些调用方或数据持有者承担了失衡（谁共享了不该共享的状态、谁被迫做一次重复校验）→ 去掉这个指派（取消『这件事归某一方独占负责』的旧约定）」，并给出兜底：说不清就把前提写成一句话交用户确认，不自创修法。这是**本目录的解释**，不保证等于上游原意；上游若补上定义，以上游为准。
7. **顺序冲突给仲裁**：上游规则 6「先减后加」与第二段「过完门禁才允许重构」在「加新功能」时指向相反动作。本目录限定规则 6 的删除范围「仅限本次改动范围内的死代码、重复实现与多余参数」，大范围重构一律排到门禁之后。
8. **无覆盖率项目的死路**：`coverage = 0` 时 `CRAP = CC² + CC`，`CC ≥ 3` 就已超过 10，上游的「CRAP < 10」对无测试项目永久不可达。本目录要求先补一个诚实的测试，补不出来则记「不适用（无覆盖率）」，不许用 `--no-coverage` 的结果冒充达标。
9. **两处不可判定项补量化**：「守住上下文窗口」补上可执行阈值（单次工具输出约 150 行、要留存的源码约 60 行，超过就落临时文件或交给子 agent，并注明是经验值）；「worktree 清理」补「只在用户明确要求时执行，未提交内容只列清单等决定」，以消除与「不改用户未提交改动」的冲突。
10. **配套工具只留调用形态，不抄使用细则**：四个工具各自有 README，抄进来会立刻过时。依赖小节保留链接、检出布局与「未在本机验证」；命令形态（`<检出>/crapper --root <项目根>`、`--threshold`、mutator 依赖 `../crapper`、`.venv` 建在检出目录）**读自各仓库根的 launcher 脚本与 `src/*/cli.py` 的 `parse_args`**，属源码核对而非实际运行，因此仍标未验证。冷启动发现「只给裸命令」会让执行者在工具目录里分析工具自己，故必须写清 `--root`。

## 与上游同步的步骤

```bash
git clone --depth 1 https://github.com/unclebob/ub-mode.git /tmp/ub-upstream
diff -u /tmp/ub-upstream/SKILL.md skills/ub-mode/SKILL.md   # 看条目是否有增删
git -C /tmp/ub-upstream log -1 --format='%H %ci'
# 有实质变化时改正文与判定列，更新 frontmatter 的 upstream_commit、本文件快照与 last_reviewed
```

上游 `SKILL.md` 是唯一权威。本目录与上游冲突时以上游为准；若冲突来自本目录刻意的改动（第 3–9 条），保持本目录写法并在本文件说明。

## healthcheck

`skills/skill-forge/scripts/staleness.sh` 读这个块。`anchor_path` 相对**仓库根目录**；日期一律 `YYYY-MM-DD`。

```yaml
version: 0.1.0
last_reviewed: 2026-10-30
review_every_days: 30
anchor_cmd: git --version
anchor_url: https://github.com/unclebob/ub-mode
anchor_url: https://github.com/unclebob/crapper
anchor_url: https://github.com/unclebob/dryer
anchor_url: https://github.com/unclebob/mutator
probe: 上游仍是 First Make it Work / Then Make it Right / Practice 三段，条目未增删（本快照为 9 + 5 + 4 条分组）
probe: 上游仍要求每函数 CRAP 低于 10，而 crapper README 的风险分档仍是 1-5 低 / 5-30 需看 / 30+ 高风险
probe: 上游仍以 0.8 作为重复度门槛，而 dryer 的默认 --threshold 仍是 0.82
probe: 上游仍把「覆盖未覆盖 / 杀存活体 / 删死代码」这三件事放在同一道门禁里
probe: 上游仓库仍无 LICENSE 文件（一旦补上许可证，「来源与许可证」节需重写并考虑收录原文）
```

周期取 30 天：上游按作者的写作节奏更新（4 次提交集中在 2026-10），5 天只会制造无效复核；判断层面的过时由五条探针负责。

## 使用事件

只记三类异常：漏触发、误触发、卡壳。同类累计 3 次 → 触发 L3 重构。

| 日期 | 类型 | 现象 |
| --- | --- | --- |
| 2026-10-30 | 卡壳 | 冷启动（子 Agent）三轮共指出 13 处不可执行或口径缺失，全部修入 0.1.0；明细见下节「三测记录」 |

## 三测记录

```text
触发测试：8 句真实说法交给独立子 Agent，按本仓 5 份 description 路由。应命中 4 句全部命中（「按 ub-mode 来改这个函数」「修了两次还挂同一道测试」「CRAP 42 怎么降」「mutator 报了 3 个存活变异体」）；边界 2 句未误命中（过度设计 → ai-engineering-audit，文档体系 → doc-architecture）；无关 2 句未命中任何技能（整理周报、Clean Architecture 评审分层）。唯一歧义句是「修了两次还挂」：若用户补一句「先别改，只说为什么」，应滑到「不适用于只做咨询」。
冷启动：三轮，均由独立子 Agent 只读 SKILL.md 执行，不提供任何背景。第一轮报出 8 处不可执行（阈值三套口径无仲裁、门禁全未运行的结论口径、先减后加与「过完门禁才重构」互斥、无覆盖率时 CRAP 永久不可达、规则 5 的「角色／指派」无定义、mutator 行做什么与怎么做混排、worktree 清理与「不改用户未提交改动」冲突、上下文窗口无量化线）与 1 处缺口（门禁只给裸命令，没说项目根怎么传）。据此重写为 0.1.0。第二轮复核：4 项已解决、4 项部分解决、1 项缺口仍在（裸命令）。第三轮定点复查：4 项部分解决全部转为已解决，裸命令改写成 `--root` 形态；仅剩「未覆盖行为 = 0」的取数来源要临场判断（已补 killed／survived／uncovered 三条计数）。
失败测试：工具缺失 → 标「未运行」并在结论开头标降级（文档路径，未实跑）；项目无覆盖率 → 落「已运行且未通过」态，先补测试或交用户定夺，禁止用 `--no-coverage` 冒充达标（文档路径）；无 git → 提交段只给建议切分（文档路径）；门禁工具本机未装 → `anchor_cmd` 只校验 `git`，四个工具 URL 未探测。
结论：可用。门禁工具的命令形态经源码核对（launcher + cli.py），但**未真机运行**，这是本技能唯一的已知未验证项。
```
