part of 'forge_sessions_screen.dart';

extension _ForgeSessionsDisplayPanels on _ForgeSessionsScreenState {
  Widget _authenticatedDeviceInventoryPanel(
    BuildContext context,
    ForgeDeviceInventoryPage page,
  ) => KeyedSubtree(
    key: const ValueKey('forge-authenticated-device-inventory'),
    child: Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr('Authenticated device inventory observation'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            context.tr(
              'This owner-scoped candidate is read-only and remains unverified.',
            ),
          ),
          const SizedBox(height: 8),
          ForgeDeviceInventoryPanel(
            key: const ValueKey('forge-authenticated-device-inventory-panel'),
            page: page,
          ),
        ],
      ),
    ),
  );

  Widget _clientInstanceSessionFilter(
    BuildContext context,
    Iterable<ForgeClientInstanceSessionViewInstance> instances,
    String? selectedInstanceID,
  ) {
    return Card(
      key: const ValueKey('forge-client-instance-session-filter'),
      margin: const EdgeInsets.only(top: 12),
      child: ListTile(
        title: Text(context.tr('Session visibility scope')),
        subtitle: Text(
          context.tr(
            'Local display filter over the owner session list; instance metadata is unverified.',
          ),
        ),
        trailing: PopupMenuButton<String>(
          key: const ValueKey('forge-client-instance-session-filter-menu'),
          enabled: !_sessionViewInvalidated,
          tooltip: context.tr('Select a client-instance session scope'),
          child: Text(selectedInstanceID ?? context.tr('All client instances')),
          itemBuilder: (context) => [
            PopupMenuItem<String>(
              value: _allClientInstanceFilter,
              child: Text(context.tr('All client instances')),
            ),
            for (final instance in instances)
              PopupMenuItem<String>(
                value: instance.instanceID,
                child: Text(instance.instanceID),
              ),
          ],
          onSelected: (value) => selectClientInstanceFilter(
            instances,
            value == _allClientInstanceFilter ? null : value,
          ),
        ),
      ),
    );
  }

  Widget _authenticatedDeviceInventoryV2Panel(
    BuildContext context,
    ForgeDeviceInventoryPageV2 page,
  ) => KeyedSubtree(
    key: const ValueKey('forge-authenticated-device-inventory-v2'),
    child: Padding(
      padding: const EdgeInsets.only(top: 12),
      child: ForgeDeviceInventoryV2Panel(page: page),
    ),
  );

  Widget _authenticatedDeviceInventoryResourceConvergencePanel(
    BuildContext context,
    ForgeDeviceInventoryResourceConvergence convergence,
  ) => Card(
    key: const ValueKey(
      'forge-authenticated-device-inventory-resource-convergence',
    ),
    margin: const EdgeInsets.only(top: 12),
    child: ListTile(
      leading: const Icon(Icons.compare_arrows_outlined),
      title: Text(context.tr('Converged device resources')),
      subtitle: Text(
        context.tr(
          '${convergence.inventory.devices.length} device resources share the same Runner identity and lifecycle counters. This is an unverified display-only observation.',
        ),
      ),
      trailing: const Icon(Icons.visibility_outlined),
    ),
  );

  Widget _signOutStateCard(BuildContext context) => Card(
    child: ListTile(
      leading: _signingOut
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.lock_outline),
      title: Text(
        context.tr(
          _signingOut
              ? 'Signing out of Forge…'
              : 'Forge owner data is hidden until sign-out is retried.',
        ),
      ),
      subtitle: _signOutError == null ? null : Text(context.tr(_signOutError!)),
      trailing: _signingOut
          ? null
          : TextButton(
              onPressed: _signOutThisDevice,
              child: Text(context.tr('Retry sign out')),
            ),
    ),
  );
}
