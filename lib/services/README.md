# lib/services — 横切服务

- `audit_log_service.dart`：本地审计（append-only，导出 CSV 带注入转义）
- `browser_navigation.dart`：URL 同步（路由事实源）
- `session.dart`：会话持久化（内存 + 平台存储）
- `export_service.dart`：CSV 导出（公式注入防护）
- `shortcut_service.dart`：全局快捷键（/ 命令面板、n 新建、r 刷新）
- `app_settings.dart`：用户设置（语言/主题/SSO Base URL——语言实时生效）

模式：单例 + ValueNotifier/Listenable，页面用 ListenableBuilder 响应。
