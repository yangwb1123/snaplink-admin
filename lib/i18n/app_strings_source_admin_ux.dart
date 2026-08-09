/// EN→ZH catalog for the data- & role-driven UI density/hierarchy campaign
/// (wave 1). Keys are verified absent from every other catalog
/// (design §6.0-B/C); `i18n_catalog_uniqueness_test.dart` guards against
/// spread-order override drift.
library;

/// Overview / persona.
const appAdminUxSourceZh = <String, String>{
  'Live endpoints': '在线端点',
  'Documented-only routes': '仅文档路由',
  'Commerce availability': '商务可用性',
  'Available': '可用',
  'Not advertised': '未公布',
  'Persona: {persona}': '角色：{persona}',
  'Persona.full': '全面运营',
  'Persona.securityOps': '安全运维',
  'Persona.auditor': '审计员',
  'Persona.support': '支持',
  'Persona.identityOps': '身份运维',
  'Persona.general': '通用',
  'Persona is derived from the server capability inventory, not from your identity.':
      '角色基于服务器能力清单推导，并非来自您的身份。',
  'Running': '运行中',
  'Documented-only': '仅文档',

  // Lists / audit.
  'Total': '总计',
  'On this page': '本页统计',
  'Secrets expiring': '即将过期的密钥',
  'Providers': '提供商',
  'Suspended': '已暂停',
  'Entries': '条目数',
  'Error rate': '错误率',
  'Failure': '失败',
  'Recent events': '最近事件',
  'No matches': '无匹配结果',
  'No clients match the current filter.': '没有客户端匹配当前筛选条件。',

  // Detail screens.
  'Scopes': '权限范围',
  'Secret expiry': '密钥到期',
  'Never expires': '永不过期',
  'inactive': '不活跃',
};
