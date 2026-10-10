# snaplink-console（sso-admin）

## 产品边界与不变量

Flutter/Dart UI；入口见 `lib/app_router.dart`，产品契约见 `docs/PRODUCT_ARCHITECTURE.md`、`docs/FORGE_SESSIONS.md`。

- 身份、租户、客户端、令牌及授权归 Snaplink（`~/snaplink`）；审计/合规证据归 Audit Governance（`~/snaplink-audit-governance`），本仓只读。
- 文件/对象归 Aero Vault（`~/aero-vault`），账号聚合归 Aero ID（`~/aero-id`）；不得复制权威事实。
- Agent Hub/Forge 独立于身份会话；隔离客户端凭据，预览/候选不等于执行授权。
- 依发布契约与运行时能力实现；探测失败≠未启用，不猜接口或跨服务回退。保持 EN/ZH 与平台适配。
- 写操作不自动重放；未知结果先核对，契约支持的重试复用原请求/幂等键。危险操作确认，批量逐项反馈；秘密一次性展示、不入日志/缓存，PII 附件下载。

## 工程门禁（改动后必须全绿）

```sh
python3 cli.py check        # filesize + dart analyze
python3 cli.py test         # flutter test
make analyze
make build-prod
make release-artifact-check # B6-1b 产物检查
```

阈值、豁免与结构策略以 `engineering.yaml` 为准，全部阶段见 `python3 cli.py help`；不得降低门禁掩盖失败。CI 见 `.github/workflows/`（工程、UI 规范、原生）；工具版本遵循 CI/运行器 pin。

## 批次运行

运行器仅使用 `~/ai-batch-runner`，不得在本仓 vendored。其 `projects/snaplink-console/pi-batch.yaml` 声明 `repo-gate: python3 cli.py check`；campaign 实现阶段只允许引用它。接受标准仍是上述仓内门禁，不是外置 validator；运行器 `checks/project_gates.py` 核对本文件声明。

```sh
bash ~/ai-batch-runner/projects/snaplink-console/run-campaign.sh --dry-run
bash ~/ai-batch-runner/projects/snaplink-console/run-campaign.sh --advance --dry-run
```

仓内保留 `examples/repository-campaign-pipeline.yaml`（相对路径引用）与 `docs/campaigns/` 记录；`docs/auto/`、`.pi-batch/` 为运行态目录，忽略规则以 `engineering.yaml` 为准。
