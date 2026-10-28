# 门禁配置片段

> 只打印给用户，不代写。改 `.git/hooks` 影响同仓库所有克隆；CI 文件要提交进仓库，属于用户的决策。
> 前提：`doc-check.sh` 已复制到项目的 `scripts/doc-check.sh`，并 `chmod +x`。

## 一、pre-commit（原生 hook，无依赖）

```bash
cd <项目根>
mkdir -p .git/hooks
cat > .git/hooks/pre-commit <<'EOF'
#!/usr/bin/env bash
# 文档地图与文件对不上时拦下提交；用 --no-verify 可临时跳过（跳过要在 commit message 里说明原因）
set -u
root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
bash "$root/scripts/doc-check.sh" --root "$root" || {
  echo "" >&2
  echo "文档地图与文件对不上：先改 AGENTS.md 的地图，再动文件，最后重跑。" >&2
  exit 1
}
EOF
chmod +x .git/hooks/pre-commit
```

`core.hooksPath` 被改过的仓库，hook 要装到那个目录，装完可用 `git config core.hooksPath` 确认。

## 二、pre-commit 框架（团队已有 `.pre-commit-config.yaml`）

```yaml
repos:
  - repo: local
    hooks:
      - id: doc-check
        name: doc map check
        entry: bash scripts/doc-check.sh
        language: system
        pass_filenames: false
        always_run: true
```

## 三、GitHub Actions

```yaml
name: docs
on: [push, pull_request]
jobs:
  doc-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: 文档地图与文件对账
        run: bash scripts/doc-check.sh
```

## 四、什么时候加 `--strict`

默认只让 FAIL 拦路，WARN 只打印。刚落地时 WARN 会成片出现（缺元信息头、有死链），此时开 `--strict` 会让所有人第一周就学会 `--no-verify`，门禁等于没有。

建议：先默认跑两周，WARN 清零后把 CI 那行改成 `bash scripts/doc-check.sh --strict`，把 WARN 也拦成红灯。

## 五、不接门禁

也可以只手工跑。那就把「跑 `doc-check.sh`」写进 `AGENTS.md` 的改动协议，作为收工前的固定动作——靠约定而不靠机器时，**验收动作必须写在同一页上**，否则没人会翻第二页。
