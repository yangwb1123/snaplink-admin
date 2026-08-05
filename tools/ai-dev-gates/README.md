# ai-dev-gates — 自包含的 AI 生成规范门禁

从 [ai-batch-runner](https://github.com/)（AI-SDLC 决策操作系统）复制的
纯 stdlib 检查器，用于守护本仓库的 Flutter 代码质量。**零依赖、可移植**：
复制这三个文件到任意前端项目即可获得同样门禁。

- `check-ui-spec.py`：UI 规范门禁（魔法间距 / 硬编码颜色 / inline style，
  8pt token 集）
- `check-frontend-quality.py`：前端工程门禁（console.log / any / 空 catch /
  测试跳过恒失败；上帝文件 / 复杂度 / 循环 await（N+1）/ useEffect 泄漏
  在 --strict 下失败）

用法：`make ui-check` / `make ui-quality` / `make spec-check`
CI：`.github/workflows/spec-gates.yml`

与上游同步：`cp <ai-batch-runner>/scripts/check-{ui-spec,frontend-quality}.py tools/ai-dev-gates/`
