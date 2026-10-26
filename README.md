# gourd

个人常用 Skill 仓库。把日常复用的脚本、配置、小工具、提示词和工作流，整理成一个个自包含的 Skill 目录，供 CodeBuddy / Claude Code / Opencode / Codex 这类 Agent 加载使用。

## 目录结构

```
gourd/
├── README.md            本文件
├── CATALOG.md           技能索引表
├── .gitignore
├── LICENSE              MIT
└── skills/
    ├── _template/       新建技能的模板，复制后改名使用
    │   ├── SKILL.md
    │   └── assets/
    └── <skill-name>/    实际技能，一个目录一个技能
```

## 使用前提

- Git（克隆与同步）
- 一个支持 Skill 的 Agent：CodeBuddy / Claude Code / Opencode / Codex，或其他能读本地文件并执行指令的 Agent
- 本仓库不引入任何运行时依赖；每个技能需要什么，写在该技能 `SKILL.md` 的「依赖」小节

## 如何克隆

```bash
# SSH 方式（需已配置 SSH key）
git clone git@github.com:<你的GitHub用户名>/gourd.git
cd gourd
```

不想用 SSH 就用网页上的 HTTPS 地址：`git clone https://github.com/<你的GitHub用户名>/gourd.git`。

## 技能索引

见 [CATALOG.md](CATALOG.md)。当前只有模板，实际技能尚未迁入。

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

## 新增一个技能

1. 复制模板：`cp -r skills/_template skills/your-skill-name`
   （目录名用英文小写 + 连字符，如 `log-cleanup`）
2. 改 `SKILL.md` 开头的 `name`（与目录名完全一致）和 `description`（写清"做什么 + 什么时候用"，Agent 靠这句话决定是否加载）
3. 脚本、配置、示例数据都放进该目录，不要放仓库根目录
4. 在 `CATALOG.md` 里加一行
5. 提交：`git add -A && git commit -m "add: your-skill-name"`

## 约定

- 一个技能一个目录，目录名英文小写 + 连字符
- 目录自包含：说明、脚本、配置、资源都放在目录内
- 文档用中文；目录名、文件名、命令用英文
- 复制或改编他人代码时，必须在 `SKILL.md` 的「来源与许可证」小节注明出处与原许可证
- 任何密钥、token、个人隐私配置都不进仓库（`.gitignore` 已拦截常见形式）

## 许可证

MIT，见 [LICENSE](LICENSE)。
