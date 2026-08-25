part of 'permissions_tab.dart';

extension _PermissionsTabView on _PermissionsTabState {
  Widget _buildPermissionsTab(BuildContext context) {
    final clientId = _clientId;
    final accent = adminModuleIconColor('permissions');
    return PullToRefresh(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: _permissionPageChildren(context, clientId, accent),
      ),
    );
  }

  List<Widget> _permissionPageChildren(
    BuildContext context,
    String? clientId,
    Color accent,
  ) => [
    const AdminBreadcrumb(),
    const SizedBox(height: 4),
    _permissionsHeader(context, accent),
    const SizedBox(height: 16),
    _clientSelector(accent),
    if (_error != null) ...[const SizedBox(height: 8), _errorBanner(context)],
    if (clientId != null) ...[
      const SizedBox(height: 12),
      _sectionSelector(accent),
    ],
    if (clientId != null && _loading) ...[
      const SizedBox(height: 12),
      const SkeletonListTile(itemCount: 3),
    ],
    if (clientId != null && !_loading) ..._loadedPermissionSections(),
  ];

  Widget _clientSelector(Color accent) => LayoutBuilder(
    builder: (context, constraints) {
      final clientId = _clientId;
      if (constraints.maxWidth >= 520) {
        return PermissionsClientSelector(
          controller: _clientCtrl,
          clientId: clientId,
          loading: _loading,
          onSearch: _searchClient,
          onSubmitted: _searchClient,
        );
      }
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: constraints.maxWidth,
            child: TextField(
              controller: _clientCtrl,
              decoration: InputDecoration(
                labelText: 'Client ID'.localized,
                hintText: 'Enter client ID and press Search'.localized,
                prefixIcon: Icon(
                  Icons.business_outlined,
                  size: 18,
                  color: accent,
                ),
              ),
              onSubmitted: (_) => _searchClient(),
            ),
          ),
          FilledButton.icon(
            onPressed: _loading ? null : _searchClient,
            icon: const Icon(Icons.search, size: 18),
            label: const LocalizedText('Search'),
          ),
          if (clientId case final value?)
            Chip(
              avatar: Icon(Icons.check_circle, size: 16, color: accent),
              label: Text(value),
              visualDensity: VisualDensity.compact,
            ),
        ],
      );
    },
  );

  Widget _permissionsHeader(BuildContext context, Color accent) {
    final theme = Theme.of(context);
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(Icons.admin_panel_settings_outlined, color: accent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                container: true,
                header: true,
                child: Text(
                  AppStrings.of(context).permissions,
                  style: theme.textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: 4),
              LocalizedText(
                'Client-scoped roles, assignments and navigation menus.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: _clientId == null || _loading ? null : _load,
          icon: Icon(Icons.refresh, color: accent),
          tooltip: context.strings.refresh,
        ),
      ],
    );
  }

  Widget _sectionSelector(Color accent) => SectionSelector(
    current: _currentSection,
    onSelected: _selectSection,
    sections: [
      SectionDef('all', 'All', Icons.view_quilt_outlined, color: accent),
      SectionDef('roles', 'Roles', Icons.shield_outlined, color: accent),
      SectionDef(
        'assignments',
        'Assignments',
        Icons.assignment_outlined,
        color: accent,
      ),
      SectionDef('menus', 'Menus', Icons.account_tree_outlined, color: accent),
    ],
  );

  List<Widget> _loadedPermissionSections() => [
    if ((_currentSection == 'all' || _currentSection == 'roles') &&
        _supportsRoles) ...[
      const SizedBox(height: 12),
      _roleSection(),
    ],
    if ((_currentSection == 'all' || _currentSection == 'assignments') &&
        _supportsAssignments) ...[
      const SizedBox(height: 12),
      _assignmentSection(),
    ],
    if ((_currentSection == 'all' || _currentSection == 'menus') &&
        _supportsMenus) ...[
      const SizedBox(height: 12),
      PermissionMenusCard(
        controller: _menusCtrl,
        mutating: _mutating,
        onSave: _saveMenus,
      ),
    ],
  ];

  Widget _errorBanner(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.dangerTint.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        Icon(
          Icons.error_outline,
          size: 18,
          color: AppColors.semanticFor(
            Theme.of(context).brightness,
            AppColors.danger,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            context.tr(_error!),
            // R29：dark 下提亮（2.26→5.29:1 ≥AA），浅色恒等。
            style: TextStyle(
              color: AppColors.semanticFor(
                Theme.of(context).brightness,
                AppColors.danger,
              ),
            ),
          ),
        ),
        TextButton(
          onPressed: _clientId == null ? null : _load,
          child: const LocalizedText('Retry'),
        ),
      ],
    ),
  );

  Widget _roleSection() => RolesCard(
    roles: _roles.map((role) => Map<String, dynamic>.from(role)).toList(),
    mutating: _mutating,
    clientId: _clientId,
    onCreateRole: () => _editRole(),
    onEditRole: _editRole,
    onDeleteRole: _deleteRole,
  );

  Widget _assignmentSection() => AssignmentsCard(
    assignments: _assignments
        .map((assignment) => Map<String, dynamic>.from(assignment))
        .toList(),
    mutating: _mutating,
    clientId: _clientId,
    userController: _userCtrl,
    roleCodesController: _roleCodesCtrl,
    onAssignRoles: _assign,
    onUnassignRole: (userId, _) => _unassign(userId),
  );
}
