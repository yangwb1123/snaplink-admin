/// Tenant data-residency administration copy.
const appAdminResidencySourceZh = <String, String>{
  'Data residency': '数据驻留',
  'Home region': '主区域',
  'Home region is required when write enforcement is enabled.':
      '启用写入区域强制策略时必须设置主区域。',
  'Allowed serving regions': '允许提供服务的区域',
  'One per line or comma-separated; duplicates drop and the home region is always allowed.':
      '每行一个或用逗号分隔；重复项会被移除，主区域始终允许。',
  'Primary region for tenant data. Leave blank for unconstrained residency.':
      '租户数据的主区域。留空表示不限制数据驻留区域。',
  'Enforce writes in home region': '强制在主区域写入',
  'Reject token-issuing writes served outside the home region.':
      '拒绝由主区域以外部署处理的令牌签发写入。',
  'Home region: {region}': '主区域：{region}',
  'Allowed serving regions: {regions}': '允许提供服务的区域：{regions}',
  'Write enforcement enabled': '已启用写入区域强制策略',
  'Write enforcement is inactive because no home region is configured.':
      '写入区域强制策略未生效，因为尚未配置主区域。',
};
