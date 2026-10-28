> 成果卡片生成原文，来自上游 SKILL.md。Phase 3 出图时读。
>
> **与上游的差异（2026-10-28 修正）**：上游原文有 `dim-bar-before/after`、`improvement-1/2/3` 与 URL hash 切三风格，实测模板都不存在；下述正文已按模板实际字段改写。填数前仍先 `grep -o 'data-field="[^"]*"' <模板>` 取清单，以模板为准。

## 成果卡片生成（Result Card）

每个skill优化完成后（或全量汇总后），自动生成视觉成果卡片，截图保存为PNG。

### 卡片模板

模板位置：`assets/templates/`。三份**彼此独立**的模板，没有 CSS 主题类、没有 URL hash 切换；选一份复制后填字段。

| 模板 | 字段数 | 用途 |
|------|--------|------|
| `result-card.html` | 19（含 `top1-*` / `top2-*` 两条最亮改动） | 总览卡，默认 |
| `result-card-white.html` | 10 | 浅色单 skill 卡 |
| `result-card-dark.html` | 14（含 `score-after-2`） | 深色单 skill 卡 |

字段以模板里的 `data-field` 为准，填数前先取清单：`grep -o 'data-field="[^"]*"' <模板> | sort -u`。

### 生成流程

```
1. 选一份模板（默认 result-card.html），复制到临时工作文件
2. 用 sed/编辑工具 替换占位数据：
   - data-field="skill-name" / "skill-id" → 实际 skill 名
   - data-field="score-before/after/delta" → 实际分数
   - data-field="improve-1/2/3" → 实际改进摘要（不是 improvement-1/2/3）
   - data-field="top1-*" / "top2-*" → 两条最亮改动（仅主模板）
   - data-field="date" → 当前日期
3. 用 scripts/screenshot.mjs 截图（2x 高清，只截 .card 元素，自动 open 图片）：
   node skills/darwin-skill/scripts/screenshot.mjs \
     /abs/path/to/card.html /abs/path/to/output.png
   # 回退方案（脚本失败时）：
   npx playwright screenshot "file:///path/to/card.html" \
     output.png --viewport-size=960,1280 --wait-for-timeout=2000
4. 提示用户查看成果卡片 PNG
```

### 资源文件速查

| 路径 | 用途 |
|---|---|
| `assets/templates/result-card.html` | 总览卡模板（19 字段） |
| `assets/templates/result-card-white.html` / `-dark.html` | 单 skill 卡模板（10 / 14 字段） |
| `skills/darwin-skill/scripts/screenshot.mjs` | 2x 高清截图，只截 .card，自动 open |
| `results.tsv` | 历次优化日志（9列含 eval_mode） |
| `{skill目录}/test-prompts.json` | 每个 skill 的测试 prompt 集（用于维度8实测） |

### 何时生成

- **单skill卡片**：每个skill优化完成后，展示该skill的分数变化
- **总览卡片**：全部优化完成后（Phase 3），展示全局战绩

### 品牌元素

- 顶部：Darwin.skill 品牌标识 + 日期
- 底部：「Train your Skills like you train your models」+ github.com/alchaincyf/darwin-skill
