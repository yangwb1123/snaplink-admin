# AGENTS.md — snaplink-console（sso-admin）

## 权威边界

本仓是 Snaplink 的管理端 UI。它**不拥有**任何身份事实：用户、租户、客户端、令牌、
授权判定全部由 Snaplink（`~/snaplink`）决定；审计事实与合规证据由 Snaplink Audit
Governance（`~/snaplink-audit-governance`）拥有，本仓只读其接口。文件与对象能力来自
Aero Vault（`~/aero-vault`），账号聚合来自 Aero ID（`~/aero-id`）。不要在本仓复制这些事实。

## 工程门禁（改动后必须全绿）

```sh
python3 cli.py check        # 快速子集：filesize + dart analyze
python3 cli.py test         # flutter test（2063 项）
make analyze                # dart analyze
make build-prod             # 生产 Web 产物
make release-artifact-check # B6-1b 关键面缺失检查
```

`python3 cli.py help` 列出全部阶段（`check-filesize`、`complexity`、`architecture`、
`root-policy`、`directory-fanout`、`invariants`、`coverage`…）。阈值与忽略项全部来自
`engineering.yaml`，`lib/` 下的根策略也在那里。

CI（`.github/workflows/`）跑的是 `ci.yml`（analyze + build-prod + release-artifact-check）、
`spec-gates.yml`（UI 规范：spacing/color/字体、UI 质量）与 `native-workspace.yml`。

**LLM/批次产出的接受标准就是上面这些命令**，不是运行器里另一份 validator 列表：批次
运行器（`~/ai-batch-runner`）在 `projects/snaplink-console/pi-batch.yaml` 里声明
`repo-gate: python3 cli.py check`，campaign 的实现阶段只允许引用它；该声明由运行器仓的
`checks/project_gates.py` 守卫，并会核对本文件是否真的写了这条门禁。

## 批次运行

本仓**不再 vendored** 批次运行器（`pbatch/`、`pi-batch.py`、`pi-batch.yaml`、`quality.py`
已删除）。配置与引擎在运行器仓：

```sh
bash ~/ai-batch-runner/projects/snaplink-console/run-campaign.sh --dry-run
bash ~/ai-batch-runner/projects/snaplink-console/run-campaign.sh --advance --dry-run
```

`examples/repository-campaign-pipeline.yaml` 留在本仓（campaign 以仓内相对路径引用它）；
`docs/campaigns/**` 是批次记录，其中 task 文件本就直接调用
`~/ai-batch-runner/pi-batch.py`。

## 已知与环境相关的门禁项

- `check-proto-sync` 类检查依赖钉住的工具版本（见运行器仓 `engineering.yaml` 的 pin）。
- `docs/auto/` 与 `.pi-batch/` 是运行态目录，已在 `engineering.yaml` 的忽略列表中。
