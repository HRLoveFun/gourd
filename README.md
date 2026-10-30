# gourd

个人常用 Skill 仓库。把日常复用的脚本、配置、小工具、提示词和工作流，整理成一个个自包含的 Skill 目录，供 CodeBuddy / Claude Code / Opencode / Codex 这类 Agent 加载使用。

## 目录结构

```
gourd/
├── README.md            本文件
├── CATALOG.md           技能索引表
├── .github/workflows/   CI：每次提交跑约定检查与时效体检
├── .gitignore
├── LICENSE              MIT
├── template/            新建技能的模板，复制后改名使用
│   ├── SKILL.md
│   ├── assets/
│   └── references/
└── skills/              实际技能，一个目录一个技能
    ├── skill-forge/     元技能：把材料提炼成技能 + 体检
    │   ├── SKILL.md
    │   ├── assets/
    │   ├── references/
    │   └── scripts/
    └── <skill-name>/
        ├── SKILL.md
        ├── assets/
        ├── references/
        └── scripts/
```

模板放在根目录 `template/`，不放进 `skills/`。原因：Agent 规范要求 `SKILL.md` 的 `name` 与父目录名一致，`skills/` 下只留能直接加载的真实技能，避免模板被当成技能加载时报错。

移植自他人仓库的技能，目录里多一份 `LICENSE.upstream`（上游许可证原文），其余结构不变，见下文「方式二」。

## 使用前提

- Git（克隆与同步）
- 一个支持 Skill 的 Agent：CodeBuddy / Claude Code / Opencode / Codex，或其他能读本地文件并执行指令的 Agent
- 本仓库不引入任何运行时依赖；每个技能需要什么，写在该技能 `SKILL.md` 的「依赖」小节

## 如何克隆

```bash
# SSH 方式（需已配置 SSH key）
git clone git@github.com:HRLoveFun/gourd.git
cd gourd
```

不想用 SSH 就用网页上的 HTTPS 地址：`git clone https://github.com/HRLoveFun/gourd.git`。

## 技能索引

见 [CATALOG.md](CATALOG.md)。

第一个技能是 [skills/skill-forge/](skills/skill-forge/)——元技能：把材料提炼成新技能，并负责既有技能的体检与修订。新技能优先用它起：

```bash
./skills/skill-forge/scripts/new-skill.sh <skill-name> "<一句话用途>"
./skills/skill-forge/scripts/lint-skill.sh <skill-name>   # 提交前必过
./skills/skill-forge/scripts/staleness.sh --all           # 定期时效体检
```

## 怎么给 Agent 用

两种方式，选一种：

1. 整个仓库放在固定位置，在 Agent 会话里让它读对应技能的 `SKILL.md`，例如「按 `skills/log-cleanup/SKILL.md` 执行」。
2. 把某个技能目录复制到 Agent 的技能目录，让它自动按 `description` 匹配触发。以 Claude Code 为例：

```bash
# 仅当前项目可用
mkdir -p .claude/skills && cp -r skills/log-cleanup .claude/skills/
# 或全局可用
mkdir -p ~/.claude/skills && cp -r skills/log-cleanup ~/.claude/skills/
```

其他 Agent 的技能目录位置以各自文档为准；不确定时用方式 1。

## 持续集成

`.github/workflows/skills-ci.yml` 在每次 push 与 PR 时跑，顺序固定：

| 步骤 | 失败意味着 |
| --- | --- |
| `bash -n` | 脚本有语法错误（先于业务检查，避免误判） |
| `shellcheck --severity=warning` | 有真实可修的坑，不是风格问题 |
| 可执行位检查 | 脚本在 git 里丢了 `100755`，克隆后无法直接执行 |
| `lint-skill.sh --all` | 违反仓库约定（命名、frontmatter、healthcheck 缺失等） |
| `staleness.sh --all` | 锚点断了或 TTL 超期，技能已不可信 |
| `staleness.sh --all --network` | **仅报告不拦路**，外网抖动不该变红灯 |
| CATALOG 一致性 | 目录与索引表对不上 |

### 复核提醒

`review-reminder.yml` 每周一 09:00（UTC+8）检查各技能是否到期，**有到期项就开一个 Issue**，GitHub 会自动把 Issue 全文发成通知邮件。正文里带 description、接口摘要、逐条探针和期间改动，核完改 `last_reviewed` 后关闭 Issue 即可。

不需要配置任何 SMTP 或凭据。手动预览：

```bash
./skills/skill-forge/scripts/review-packet.sh --force-due --dry-run
```

> GitHub 在仓库 60 天无提交后会自动停用定时任务，届时用 `workflow_dispatch` 手动跑一次。

另外约定：改动 `description`（技能接口）时，commit 首行加 `L3:` 前缀并写清旧接口与新接口的差异。语义判断无法自动化，工具只查结构。

本地等价命令：

```bash
./skills/skill-forge/scripts/lint-skill.sh --all
./skills/skill-forge/scripts/staleness.sh --all
```

时效体检对链接的探测受网络限制，CI 上单独一步且 `continue-on-error`，结果只作参考。

## 新增一个技能

两种来源，最终形态相同：`skills/<name>/` 自包含目录、`CATALOG.md` 有一行、`lint-skill.sh` 退出码 0。差别在于方式二动手前要先解决"我有没有权用"。

### 方式一：自己创建

推荐用元技能 `skill-forge` 走完整流程（含准入判断、切分、三测、healthcheck）：

```bash
./skills/skill-forge/scripts/new-skill.sh your-skill-name "一句话用途"
```

手工流程等价于下面几步：

1. 复制模板：`cp -r template skills/your-skill-name`
   （目录名用英文小写字母、数字、连字符，如 `log-cleanup`）
2. 改 `SKILL.md` 开头的 `name`（与目录名完全一致）和 `description`（写清"做什么 + 什么时候用 + 不适用于什么"，Agent 靠这句话决定是否加载）
3. 脚本、配置、示例数据都放进该目录，不要放仓库根目录
4. 参考过的资料按 MLA 记进 `SKILL.md` 同级的 `references/SOURCES.md`，并在其中的 `healthcheck` 块声明锚点
5. 在 `CATALOG.md` 里加一行
6. 跑 `./skills/skill-forge/scripts/lint-skill.sh your-skill-name`，退出码 0 再提交
7. 提交：`git add -A && git commit -m "add: your-skill-name"`

### 方式二：复制公共仓库里他人分享的 skill

**先确认有权复制，再动手。** 本仓库公开，推上去就进了 Git 历史，事后删文件不能撤回已经发生的分发；判断必须发生在复制之前。

#### 第 1 步：查上游许可证

| 上游许可证 | 能否复制 | 做法 |
| --- | --- | --- |
| MIT / BSD-2 / BSD-3 | 可以 | 保留版权声明与许可证原文；标注改动 |
| Apache-2.0 | 可以 | 同上；有 `NOTICE` 就一并保留，并注明修改过 |
| GPL-2.0 / GPL-3.0 / AGPL | 不要 | 传染性：与本仓库 MIT 混合分发，会要求整仓按 GPL 发布 |
| CC BY | 仅文字可以 | 注明作者与出处；不适用于代码 |
| CC BY-SA | 不要 | 相同方式共享会传染到整个仓库 |
| CC BY-NC / CC BY-ND | 不要 | 禁商用 / 禁改编，而移植本身就含重排与删节 |
| 没有 LICENSE 文件 | 不要 | 默认保留所有权利；只能读，然后用自己的话重写判据与流程 |
| 上游 README 单独给了授权 | 按授权 | 授权原文或链接记进 `references/SOURCES.md` |

三条比表格更好用的判据：

- **代码和文字都受保护。** 翻译成中文、重排章节、删减内容仍属改编，不因"改过了"免责。许可证义务随之保留。
- **不受保护的是想法与事实。** 上游的判据、流程思路可以学，然后自己写；原句、原结构、整段原文不能照搬。上游没有许可证时，这是唯一合规的做法。
- **拿不准就问作者，或不用。** 问一句的成本远低于事后下架。仓库已公开过的东西，不要赌。

#### 第 2 步：按本仓库约定改造

1. 目录名重命名成英文小写字母、数字、连字符，`SKILL.md` 的 `name` 同步改，两者必须完全一致
2. 重写 `description`：上游多半没写"不适用于什么"，不写就会误触发
3. 按九节骨架重排；上游的 `.claude/`、示例目录、宣传图、超 200KB 素材一律不收，改在 `references/SOURCES.md` 留链接
4. 把上游许可证原文原样存为 `skills/<name>/LICENSE.upstream`，不加自己的版权行——MIT 要求"所有副本包含版权声明与许可声明"，这是义务不是礼貌
5. `SKILL.md` 的「来源与许可证」写全：上游链接、原作者、许可证、快照 commit 与日期、移植日期、本目录改了哪些地方、与上游冲突时以谁为准
6. `references/SOURCES.md` 的 healthcheck 把上游当锚点：`anchor_url` 指向上游仓库，`probe:` 写"上游是否仍为 MIT""上游结构是否已改"；`review_every_days` 按上游发版节奏取，移植类常用 30 天
7. `CATALOG.md` 那行的用途末尾补「移植自 owner/repo（许可证）」

#### 第 3 步：验收

```bash
./skills/skill-forge/scripts/lint-skill.sh <skill-name>   # 退出码 0 再提交
git add -A && git commit -m "add: <skill-name>（移植自 owner/repo，MIT）"
```

许可证兼容性只能人工判断：CI 与 `lint-skill.sh` 只查结构与格式，查不出"这个许可证能不能用"。现成两例可照抄格式：[skills/huashu-nuwa/](skills/huashu-nuwa/)、[skills/darwin-skill/](skills/darwin-skill/)。

## 约定

- 一个技能一个目录，目录名只用英文小写字母、数字、连字符
- 目录自包含：说明、脚本、配置、资源都放在目录内
- 文档用中文；目录名、文件名、命令用英文
- 参考资料只收 MLA 格式的引用与链接，写在 `references/SOURCES.md`，不复制他人文档原文
- 单个文件超过约 200KB 的二进制素材（PDF、大图、音视频、数据集）不入库，改留链接
- 改编或移植他人技能时，在 `SKILL.md` 的「来源与许可证」注明原仓库、原作者与原许可证，上游许可证原文保留为 `LICENSE.upstream`
- GPL / AGPL / CC BY-NC / CC BY-ND 许可的素材一律不入库；没有许可证的上游视为保留所有权利，只读不抄
- 任何密钥、token、个人隐私配置都不进仓库（`.gitignore` 已拦截常见形式）
- 两个以上技能共用的资料暂不设共享目录；真出现时再加，并在本文件说明
- 每个技能的 `references/SOURCES.md` 带一个 `healthcheck` 块（锚点 + 探针 + 复核周期），供 `staleness.sh` 检查时效

## 许可证

MIT，见 [LICENSE](LICENSE)。
