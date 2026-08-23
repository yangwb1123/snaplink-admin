part of 'organizations_tab.dart';

extension _OrganizationsTabView on _OrganizationsTabState {
  Widget _buildOrganizationsTab(BuildContext context) {
    final managedTenantId = _managedTenantId;
    if (managedTenantId != null) {
      return OrganizationAdminPanel(
        api: widget.api,
        tenantId: managedTenantId,
        onClose: _closeOrganizationAdmin,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _organizationsHeader(context),
        Expanded(child: _organizationsBody(context)),
      ],
    );
  }

  Widget _organizationsHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  container: true,
                  header: true,
                  child: Text(
                    context.strings.organizations,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr('Teams and organizations you belong to.'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: context.tr('Refresh organizations'),
            onPressed: _loading || _accepting || _leavingTenantId != null
                ? null
                : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }

  Widget _organizationsBody(BuildContext context) {
    if (_loading) return const SkeletonListTile(itemCount: 3);
    if (!_available) {
      return const EmptyState(
        compact: true,
        variant: EmptyStateVariant.notEnabled,
        icon: Icons.business_outlined,
        title: 'Organizations are not available for this account.',
      );
    }
    if (_error != null) {
      return PortalErrorCard(message: context.tr(_error!), onRetry: _load);
    }
    return PullToRefresh(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: _organizationListChildren(context),
      ),
    );
  }

  List<Widget> _organizationListChildren(BuildContext context) => [
    MessageBanner(_notice, ok: _ok),
    if (_orgs.isEmpty)
      const EmptyState(
        compact: true,
        icon: Icons.groups_outlined,
        title: 'You are not a member of any organization.',
      )
    else
      _organizationsCard(),
    _invitationCard(context),
  ];

  Widget _organizationsCard() => PortalCard(
    title: 'Your organizations',
    children: [
      for (final (index, org) in _orgs.indexed)
        StaggeredFadeIn(index: index, child: _orgRow(org)),
    ],
  );

  Widget _invitationCard(BuildContext context) => PortalCard(
    title: 'Accept an invitation',
    children: [
      TextField(
        controller: _inviteCtrl,
        enabled: !_accepting,
        decoration: InputDecoration(labelText: context.tr('Invitation token')),
      ),
      const SizedBox(height: 12),
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(
          onPressed: _accepting ? null : _acceptInvite,
          icon: _accepting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.login_outlined, size: 18),
          label: Text(context.tr('Join organization')),
        ),
      ),
    ],
  );
}
