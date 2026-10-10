import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/widgets/admin_data_table.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/format_helpers.dart';
import 'package:sso_admin/widgets/section_header.dart';
import 'package:sso_admin/widgets/status_chip.dart';
import '../admin_module_groups.dart';
import '../admin_navigation.dart';

part 'commerce_wallet_panel_wallet.dart';

class CommerceWalletPanel extends StatelessWidget {
  final String currency;
  final Map<String, dynamic>? wallet;
  final List<Map<String, dynamic>> entries;
  final List<Map<String, dynamic>> orders;
  final String? eventOrderID;
  final List<Map<String, dynamic>> events;
  final Map<String, dynamic>? reconciliation;
  final bool walletKnown;
  final bool ledgerKnown;
  final bool ordersKnown;

  /// P0-1 probe result: false hides the checkout affordance on replicas
  /// that do not serve the session endpoint (no dead-end 404 button).
  final bool checkoutEnabled;
  final VoidCallback? onAdjust;
  final VoidCallback? onTopUp;
  final VoidCallback? onReconcile;
  final ValueChanged<String>? onLoadEvents;
  final ValueChanged<Map<String, dynamic>>? onCheckoutOrder;

  const CommerceWalletPanel({
    super.key,
    required this.currency,
    required this.wallet,
    required this.entries,
    required this.orders,
    required this.eventOrderID,
    required this.events,
    required this.reconciliation,
    this.walletKnown = true,
    this.ledgerKnown = true,
    this.ordersKnown = true,
    this.checkoutEnabled = false,
    required this.onAdjust,
    required this.onTopUp,
    required this.onReconcile,
    required this.onLoadEvents,
    required this.onCheckoutOrder,
  });

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _walletCard(context),
      const SizedBox(height: 12),
      _paymentsCard(context),
    ],
  );

  Widget _paymentsCard(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            'Top-up orders and payment facts',
            action: Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onReconcile,
                  icon: const Icon(Icons.rule_outlined, size: 18),
                  label: const LocalizedText('Reconcile'),
                ),
                FilledButton.icon(
                  onPressed: ordersKnown ? onTopUp : null,
                  icon: const Icon(Icons.add_card_outlined, size: 18),
                  label: const LocalizedText('Create top-up order'),
                ),
              ],
            ),
          ),
          const LocalizedText(
            'Only the authenticated payment adapter can apply captured, rejected, refunded, or chargeback facts. This console never handles card data or provider secrets.',
          ),
          const Divider(),
          if (!ordersKnown)
            const LocalizedText('Payment orders are unavailable.')
          else if (orders.isEmpty)
            const LocalizedText('No top-up orders exist for this tenant.')
          else
            ...orders.map((order) => _orderTile(context, order)),
          if (reconciliation != null) ...[
            const Divider(),
            _reconciliation(context),
          ],
        ],
      ),
    ),
  );

  Widget _orderTile(BuildContext context, Map<String, dynamic> order) {
    final id = order['id']?.toString() ?? '';
    final showingEvents = id.isNotEmpty && id == eventOrderID;
    final checkoutReady =
        checkoutEnabled &&
        order['status'] == 'pending' &&
        order['provider'] == 'stripe' &&
        (order['provider_order_id']?.toString() ?? '').isEmpty;
    final provider =
        'Provider reference: ${order['provider'] ?? '—'} / ${order['provider_order_id'] ?? '—'}';
    final paid =
        'Paid ${order['paid_minor'] ?? 0} · refunded ${order['refunded_minor'] ?? 0}';
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: LocalizedText(
                    '{currency} {amount} minor units',
                    style: Theme.of(context).textTheme.titleMedium,
                    args: {
                      'currency': order['currency'] ?? '',
                      'amount': formatCount(order['amount_minor'] ?? 0),
                    },
                  ),
                ),
                _orderStatusChip(order['status']?.toString() ?? 'unknown'),
                const SizedBox(width: 8),
                Chip(
                  label: LocalizedText(
                    'Revision {revision}',
                    args: {'revision': order['revision'] ?? '—'},
                  ),
                ),
              ],
            ),
            SelectableText(id.isEmpty ? '—' : id),
            Text(provider),
            Text(paid),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: id.isEmpty || onLoadEvents == null
                      ? null
                      : () => onLoadEvents!(id),
                  icon: Icon(
                    Icons.receipt_long_outlined,
                    color: adminModuleIconColor(AdminModuleId.commerce),
                  ),
                  label: const LocalizedText('Load payment facts'),
                ),
                if (checkoutReady)
                  FilledButton.tonalIcon(
                    onPressed: onCheckoutOrder == null
                        ? null
                        : () => onCheckoutOrder!(order),
                    icon: const Icon(Icons.open_in_new),
                    label: const LocalizedText('Continue secure checkout'),
                  ),
              ],
            ),
            if (showingEvents) _eventList(context),
          ],
        ),
      ),
    );
  }

  Widget _eventList(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Divider(),
      if (events.isEmpty)
        const LocalizedText('No normalized payment facts are recorded.')
      else
        AdminDataTable(
          density: TableDensity.compact,
          minWidth: 560,
          columns: [
            AdminDataColumn(
              id: 'type',
              label: 'TYPE · AMOUNT',
              width: 260,
              cardPrimary: true,
              builder: (context, i) => TableCellText(
                '${events[i]['type'] ?? 'unknown'} · ${formatCount(events[i]['amount_minor'] ?? 0)} minor units',
                bold: true,
              ),
            ),
            AdminDataColumn(
              id: 'detail',
              label: 'ID · OCCURRED',
              width: 300,
              cardDetail: true,
              builder: (context, i) => TableCellText(
                '${events[i]['id'] ?? '—'} · ${formatServerTime(events[i]['occurred_at'])}',
                muted: true,
                maxLines: 2,
              ),
            ),
          ],
          itemCount: events.length,
          rowBuilder: (context, i) => const SizedBox.shrink(),
        ),
    ],
  );

  Widget _reconciliation(BuildContext context) {
    final issues = _records(reconciliation!['issues']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LocalizedText(
          'Reconciliation report',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(
          '${reconciliation!['orders_checked'] ?? 0} orders checked · ${issues.length} issues',
        ),
        if (issues.isEmpty)
          const LocalizedText('Order totals match the immutable ledger.')
        else
          AdminDataTable(
            density: TableDensity.compact,
            minWidth: 520,
            columns: [
              AdminDataColumn(
                id: 'order',
                label: 'ORDER',
                width: 240,
                cardPrimary: true,
                builder: (context, i) => TableCellText(
                  issues[i]['order_id']?.toString() ?? '—',
                  bold: true,
                ),
              ),
              AdminDataColumn(
                id: 'detail',
                label: 'EXPECTED · LEDGER',
                width: 280,
                cardDetail: true,
                builder: (context, i) => TableCellText(
                  'Expected ${issues[i]['expected_minor'] ?? 0} · ledger ${issues[i]['ledger_minor'] ?? 0}',
                  muted: true,
                ),
              ),
            ],
            itemCount: issues.length,
            rowBuilder: (context, i) => const SizedBox.shrink(),
          ),
      ],
    );
  }
}

/// 订单状态双表达（X9）：pending/captured/failed/refunded 语义工厂，
/// 未知值原样展示（API 值走 Text，X10 不伪造 i18n 键）。
StatusChip _orderStatusChip(String status) => switch (status) {
  'pending' => StatusChip.pending(label: status),
  'captured' || 'paid' => StatusChip.active(label: status),
  'failed' || 'rejected' => StatusChip.failed(label: status),
  'refunded' || 'chargebacked' => StatusChip.suspended(label: status),
  _ => StatusChip.unknown(label: status),
};

List<Map<String, dynamic>> _records(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((record) => Map<String, dynamic>.from(record))
      .toList(growable: false);
}
