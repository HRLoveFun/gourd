# gourd

个人常用 Skill 仓库。把日常复用的脚本、配置、小工具、提示词和工作流，整理成一个个自包含的 Skill 目录，供 CodeBuddy / Claude Code / Opencode / Codex 这类 Agent 加载使用。

## 目录结构

```
gourd/
├── README.md            本文件
├── CATALOG.md           技能索引表
├── .gitignore
├── LICENSE              MIT
├── template/            新建技能的模板，复制后改名使用
│   ├── SKILL.md
│   ├── assets/
│   └── references/
└── skills/              实际技能，一个目录一个技能
    └── <skill-name>/
        ├── SKILL.md
        ├── assets/
        ├── references/
        └── scripts/
```

模板放在根目录 `template/`，不放进 `skills/`。原因：Agent 规范要求 `SKILL.md` 的 `name` 与父目录名一致，`skills/` 下只留能直接加载的真实技能，避免模板被当成技能加载时报错。

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

1. 复制模板：`cp -r template skills/your-skill-name`
   （目录名用英文小写字母、数字、连字符，如 `log-cleanup`）
2. 改 `SKILL.md` 开头的 `name`（与目录名完全一致）和 `description`（写清"做什么 + 什么时候用"，Agent 靠这句话决定是否加载）
3. 脚本、配置、示例数据都放进该目录，不要放仓库根目录
4. 参考过的资料按 MLA 记进 `SKILL.md` 同级的 `references/SOURCES.md`
5. 在 `CATALOG.md` 里加一行
6. 提交：`git add -A && git commit -m "add: your-skill-name"`

## 约定

- 一个技能一个目录，目录名只用英文小写字母、数字、连字符
- 目录自包含：说明、脚本、配置、资源都放在目录内
- 文档用中文；目录名、文件名、命令用英文
- 参考资料只收 MLA 格式的引用与链接，写在 `references/SOURCES.md`，不复制他人文档原文
- 单个文件超过约 200KB 的二进制素材（PDF、大图、音视频、数据集）不入库，改留链接
- 改编他人代码时，在 `SKILL.md` 的「来源与许可证」注明原仓库与原许可证
- 任何密钥、token、个人隐私配置都不进仓库（`.gitignore` 已拦截常见形式）
- 两个以上技能共用的资料暂不设共享目录；真出现时再加，并在本文件说明

## 许可证

MIT，见 [LICENSE](LICENSE)。
