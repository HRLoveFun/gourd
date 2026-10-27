# 资料来源（MLA 格式）

本技能参考过的资料，只记**引用与链接**，不放原文。

- 不放原文的原因：仓库是公开的，整篇复制他人文档有版权风险；Git 又会永久保存历史里出现过的每个文件，塞进去就删不干净。
- 只用 MLA 格式的原因：要素固定，一眼能判断"谁写的、发在哪、什么时候、链接是什么"。

## 本技能用到的资料

- Anthropic. *Skills*. GitHub, 2026, github.com/anthropics/skills. Accessed 27 Oct. 2026.
- "Agent Skills Specification." *Agent Skills*, agentskills.io/specification. Accessed 27 Oct. 2026.
- *gourd* 仓库内的 `README.md`、`CATALOG.md`、`template/SKILL.md`、`template/references/SOURCES.md`，用于对齐本仓库的目录、命名、引用与 500 行上限等约定。

## 使用事件

只记三类异常，一行一次。同类累计 3 次触发 L3 重构；单次导致错误产出立即 L2。判据与动作见 `SKILL.md` 阶段九。

| 日期 | 类型 | 说明 |
| --- | --- | --- |
| （暂无） | - | 首次启用，尚无事件 |

## healthcheck

`scripts/staleness.sh` 读这个块。`anchor_path` 相对**仓库根目录**；改动锚点即改动本技能的事实前提，属 L2。日期一律写 `YYYY-MM-DD`。

```yaml
review_every_days: 5
last_reviewed: 2026-10-27
version: 0.1.0

anchor_path: template/SKILL.md
anchor_path: template/references/SOURCES.md
anchor_path: CATALOG.md
anchor_path: README.md

anchor_cmd: bash --version
anchor_cmd: git rev-parse --show-toplevel
anchor_cmd: grep --version

anchor_url: https://github.com/HrLoveFun/gourd

probe: 仓库是否仍要求 references/ 只放 SOURCES.md（只记引用不抄原文）
probe: skills/ 下是否仍只放能直接加载的真实技能，模板仍在根目录 template/
probe: SKILL.md 的 name 是否仍须与父目录名完全一致
probe: 500 行上限与 200KB 二进制不入库的约定是否仍然有效
probe: CATALOG.md 的状态取值是否仍为 可用/草稿/待迁移/已废弃
```

### 锚点选择原则

- 只锚**本技能依赖的前提**，不锚本技能自己的产物（否则永远自洽，等于没检查）
- `anchor_path` 用来发现"被引用的东西消失了"
- `anchor_cmd` 只放**版本无关的探测**，别放会变的输出比对
- `anchor_url` 默认不联网，加 `--network` 才探测；离线环境跑不出 STALE 属预期

## 链接失效怎么办

保留原条目，行末补 `（已失效，2026-10-27 核对）`，不要直接删——将来还能凭标题和作者重新找到。
