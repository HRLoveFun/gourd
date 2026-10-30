# 资料来源（MLA 格式）

本技能参考过的资料，只记**引用与链接**，不放原文。

## 本技能用到的资料

- Git 项目。《git-merge Documentation》《git-branch Documentation》《git-push Documentation》《git-fetch Documentation》。Software Freedom Conservancy，git-scm.com/docs。访问日期 2026年10月30日。

  > 只取命令语义：`merge --no-ff` 保留分支拓扑、`branch -d` 只删已合并分支、`push --delete` 删除远端引用、`fetch --prune` 清理失效追踪引用。流程编排、保护分支名单与回滚策略为本技能自拟，不来自文档。

- Chacon, Scott, and Ben Straub. *Pro Git*. 2nd ed., Apress, 2014. git-scm.com/book。

  > 只取「分支只是指向提交的可移动指针」这一模型，用于解释为何清理已合并分支不会丢失提交。

## 与材料的偏离

材料只提供命令语义，以下为自拟设计：

- **默认演练、`--apply` 才落地**：用户要求「自动」，但删远端分支不可撤销；把确认点收敛成一次显式开关，而不是每步询问。
- **保护分支名单含 `backup/*`**：Git 文档没有这个概念。加入是因为备份分支常保留未合并的历史，按「已合并即删」会误删。
- **编译后检查工作区**：`git merge` 本身会因未跟踪文件与目标分支冲突而失败，但错误信息晚且难读；提前检查能把「产物该提交还是该忽略」变成显式问题。
- **推送失败不回滚**：回滚已完成的本地合并会制造第二个分叉，保留合并并给出 `reset --hard ORIG_HEAD` 更可控。

刻意未做：

- **不装 git hook**：hook 内再提交会递归，且「保存即提交」把节奏交给编辑器。
- **不自动解冲突**：冲突需要业务判断，脚本只负责 abort 与回到安全点。
- **不做 squash 合并**：与「保留分支历史」的目标相反，属于另一条流程。

## 修订记录

**0.1.0（2026-10-30）**：建立。脚本在临时仓库上验证：正常合并、编译失败回滚、合并冲突中止、保护分支拒绝、无改动跳过提交五种路径。

已知悬空：`ic` 只是默认命令名，**未在真实项目上验证**其增量编译耗时与退出码语义；远端删除只在本地 bare 仓库上测过，未测 GitHub 分支保护规则拒绝删除时的表现。

## 使用事件

只记三类异常（漏触发 / 误触发 / 卡壳），一行一次。同类累计 3 次触发 L3 重构；单次导致错误产出立即 L2。判据见 `skills/skill-forge/SKILL.md` 阶段九。

| 日期 | 类型 | 说明 |
| --- | --- | --- |
| （暂无） | - | 新建，尚无真实使用事件 |

## healthcheck

`skills/skill-forge/scripts/staleness.sh` 读这个块。`anchor_path` 相对**仓库根目录**；日期一律 `YYYY-MM-DD`。

> 只锚**本技能依赖的外部前提**，不要锚本技能自己的产物（否则永远自洽，等于没检查）。

```yaml
review_every_days: 30
last_reviewed: 2026-10-30
version: 0.1.0

# 本技能依赖的仓库约定：九节骨架与 CATALOG 登记规则变了，正文与脚本的落地方式要重看
anchor_path: template/SKILL.md
anchor_path: skills/skill-forge/scripts/lint-skill.sh

# 依赖的命令（只放版本无关的探测）
anchor_cmd: git --version
anchor_cmd: bash --version

probe: git 的 merge --no-ff、branch -d、push --delete、fetch --prune 语义是否仍如本文假设
probe: 本仓库的默认分支是否仍为 main；保护分支名单是否仍适用
probe: 是否出现取代 ic 的构建入口，导致默认编译命令失效
probe: 远端分支保护规则是否会拒绝 push --delete；拒绝时脚本的退出码 5 是否仍能说明现场
```
