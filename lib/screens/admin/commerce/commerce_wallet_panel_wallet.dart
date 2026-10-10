part of 'commerce_wallet_panel.dart';

extension _CommerceWalletView on CommerceWalletPanel {
  Widget _walletCard(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            'Wallet and immutable ledger',
            action: OutlinedButton.icon(
              onPressed: walletKnown ? onAdjust : null,
              icon: const Icon(Icons.post_add_outlined, size: 18),
              label: const LocalizedText('Post adjustment'),
            ),
          ),
          const LocalizedText(
            'All values are integer minor units. Currency decimal exponents are never inferred by this console.',
          ),
          const Divider(),
          if (!walletKnown)
            const LocalizedText('Wallet data is unavailable.')
          else if (wallet == null)
            LocalizedText(
              'No {currency} wallet exists for this tenant.',
              args: {'currency': currency},
            )
          else
            _walletSummary(context),
          const SizedBox(height: 8),
          if (!ledgerKnown)
            const LocalizedText('Ledger data is unavailable.')
          else
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: LocalizedText(
                'Ledger entries ({entries_length})',
                args: {'entries_length': entries.length},
              ),
              children: entries.isEmpty
                  ? [
                      const EmptyState(
                        variant: EmptyStateVariant.empty,
                        title: 'No ledger entries.',
                      ),
                    ]
                  : [_ledgerTable(context)],
            ),
        ],
      ),
    ),
  );

  Widget _walletSummary(BuildContext context) {
    final statusLabel = wallet!['status']?.toString() ?? 'unknown';
    final balance =
        '${wallet!['currency'] ?? currency} ${formatCount(wallet!['balance_minor'] ?? 0)} minor units';
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Icon(
          wallet!['status'] == 'active'
              ? Icons.account_balance_wallet
              : Icons.lock,
          color: wallet!['status'] == 'active'
              ? AppColors.success
              : AppColors.warning,
          size: 32,
        ),
        Text(balance, style: Theme.of(context).textTheme.titleMedium),
        StatusChip(
          label: statusLabel,
          color: wallet!['status'] == 'active'
              ? AppColors.success
              : AppColors.warning,
          icon: wallet!['status'] == 'active'
              ? Icons.check_circle
              : Icons.circle_outlined,
        ),
        LocalizedText(
          'Wallet version {version}',
          args: {'version': wallet!['version'] ?? 0},
        ),
      ],
    );
  }

  Widget _ledgerTable(BuildContext context) => AdminDataTable(
    density: TableDensity.compact,
    minWidth: 640,
    columns: [
      AdminDataColumn(
        id: 'kind',
        label: 'KIND · AMOUNT',
        width: 240,
        cardPrimary: true,
        builder: (context, i) => TableCellText(
          '${entries[i]['kind'] ?? 'unknown'} · ${formatCount(entries[i]['amount_minor'] ?? 0)} minor units',
          bold: true,
        ),
      ),
      AdminDataColumn(
        id: 'detail',
        label: 'BALANCE · REFERENCE · OCCURRED',
        width: 340,
        cardDetail: true,
        builder: (context, i) => TableCellText(
          'Balance ${formatCount(entries[i]['balance_after'])} · ${entries[i]['reference'] ?? '—'} · ${formatServerTime(entries[i]['occurred_at'])}',
          muted: true,
          maxLines: 2,
        ),
      ),
      AdminDataColumn(
        id: 'version',
        label: 'VERSION',
        width: 100,
        builder: (context, i) =>
            TableCellText('v${entries[i]['wallet_version'] ?? '—'}'),
      ),
    ],
    itemCount: entries.length,
    rowBuilder: (context, i) => const SizedBox.shrink(),
  );
}
