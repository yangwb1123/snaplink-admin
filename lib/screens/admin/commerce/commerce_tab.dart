import 'package:flutter/material.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/session.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/services/product_api_origin.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/admin_list_header.dart';
import 'package:sso_admin/widgets/app_snackbar.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'package:sso_admin/widgets/pull_to_refresh.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';
import '../admin_module_groups.dart';
import '../admin_navigation.dart';

import 'commerce_api.dart';
import 'commerce_checkout.dart';
import 'commerce_models.dart';
import 'commerce_money_dialogs.dart';
import 'commerce_panels.dart';
import 'commerce_plan_dialog.dart';
import 'commerce_selector.dart';
import 'commerce_subscription_dialogs.dart';
import 'commerce_wallet_panel.dart';
part 'commerce_checkout_flow.dart';
part 'commerce_tab_view.dart';

class CommerceTab extends StatefulWidget {
  final SnaplinkAdminApi api;
  final Object? availabilityError;
  final CommerceCheckoutOrigin? checkoutOrigin;
  final CommerceCheckoutNavigator? checkoutNavigator;

  /// P0-1 test seam: probe uses its own client (onUnauthorized: null) so a
  /// 401 probe never logs the operator out; tests inject a MockClient here.
  final SnaplinkAdminApi Function()? probeClientBuilder;

  const CommerceTab({
    super.key,
    required this.api,
    this.availabilityError,
    this.checkoutOrigin,
    this.checkoutNavigator,
    this.probeClientBuilder,
  });

  @override
  State<CommerceTab> createState() => _CommerceTabState();
}

class _CommerceTabState extends State<CommerceTab> {
  final _tenant = TextEditingController(),
      _currency = TextEditingController(text: 'USD');
  late final CommerceAdminApi _commerce = CommerceAdminApi(widget.api);

  List<Map<String, dynamic>> _plans = const [];
  List<Map<String, dynamic>> _subscriptions = const [];
  List<Map<String, dynamic>> _entries = const [];
  List<Map<String, dynamic>> _orders = const [];
  List<Map<String, dynamic>> _events = const [];
  Map<String, dynamic>? _entitlement;
  Map<String, dynamic>? _wallet;
  Map<String, dynamic>? _reconciliation;
  String? _eventOrderID;
  String? _catalogError;
  String? _tenantError;
  CheckoutProbeState _checkoutProbe = CheckoutProbeState.degraded;
  bool _catalogLoading = false;
  bool _tenantLoading = false;
  bool _mutating = false;
  bool _tenantLoaded = false;

  /// 模块强调色（tenants 组 amber）：页内图标统一按组色上色（X7）。
  Color get _accent => adminModuleIconColor(AdminModuleId.commerce);

  void _update(VoidCallback mutation) => setState(mutation);

  @override
  void initState() {
    super.initState();
    _loadPlans();
    _probeCheckout();
  }

  @override
  void dispose() {
    _tenant.dispose();
    _currency.dispose();
    super.dispose();
  }

  Future<void> _loadPlans() async {
    setState(() {
      _catalogLoading = true;
      _catalogError = null;
    });
    try {
      final response = await _commerce.listPlans();
      if (!mounted) return;
      setState(() => _plans = commerceRecords(response, 'plans'));
    } catch (error) {
      if (mounted) setState(() => _catalogError = error.toString());
    } finally {
      if (mounted) setState(() => _catalogLoading = false);
    }
  }

  Future<void> _probeCheckout() async {
    // P0-1 (api-gap): probe once per tab lifecycle with an unauthenticated-
    // outcome client (a 401 never triggers session-expiry logout); memoize.
    final probeClient =
        widget.probeClientBuilder?.call() ??
        SnaplinkAdminApi(
          baseUrl: widget.api.baseUrl,
          accessToken: Session.read() ?? '',
          onUnauthorized: null,
        );
    try {
      await CommerceAdminApi(probeClient).probeCheckout();
      if (!mounted) return;
      setState(() => _checkoutProbe = CheckoutProbeState.available);
    } catch (error) {
      if (!mounted) return;
      setState(() => _checkoutProbe = checkoutProbeState(error));
    }
  }

  Future<void> _loadTenant() async {
    final tenantID = _tenant.text.trim();
    final currency = _currency.text.trim().toUpperCase();
    if (tenantID.isEmpty || !RegExp(r'^[A-Z]{3}$').hasMatch(currency)) {
      setState(
        () => _tenantError =
            'Enter a tenant ID and a three-letter currency code.',
      );
      return;
    }
    _currency.text = currency;
    setState(() {
      _tenantLoading = true;
      _tenantError = null;
    });
    final results = await Future.wait([
      _section(_commerce.listSubscriptions(tenantID)),
      _section(_commerce.getEntitlement(tenantID), allowMissing: true),
      _section(_commerce.getWallet(tenantID, currency), allowMissing: true),
      _section(
        _commerce.listWalletEntries(tenantID, currency),
        allowMissing: true,
      ),
      _section(_commerce.listOrders(tenantID)),
    ]);
    if (!mounted) return;
    _applyTenantResults(results);
  }

  void _applyTenantResults(
    List<({Map<String, dynamic>? data, String? error})> results,
  ) {
    final errors = results.map((result) => result.error).whereType<String>();
    setState(() {
      _subscriptions = commerceRecords(
        results[0].data ?? const {},
        'subscriptions',
      );
      _entitlement = commerceRecord(results[1].data ?? const {}, 'entitlement');
      _wallet = commerceRecord(results[2].data ?? const {}, 'wallet');
      _entries = commerceRecords(results[3].data ?? const {}, 'entries');
      _orders = commerceRecords(results[4].data ?? const {}, 'orders');
      _events = const [];
      _eventOrderID = null;
      _reconciliation = null;
      _tenantError = errors.isEmpty ? null : errors.join('\n');
      _tenantLoading = false;
      _tenantLoaded = true;
    });
  }

  Future<({Map<String, dynamic>? data, String? error})> _section(
    Future<Map<String, dynamic>> request, {
    bool allowMissing = false,
  }) async {
    try {
      return (data: await request, error: null);
    } catch (error) {
      if (allowMissing &&
          error is SnaplinkAdminApiError &&
          error.status == 404) {
        return (data: null, error: null);
      }
      return (data: null, error: error.toString());
    }
  }

  Future<void> _publishPlan() async {
    final body = await CommercePlanDialog.show(context);
    if (body == null) return;
    await _mutate(
      () => _commerce.publishPlan(body),
      'Plan version published.',
      reloadPlans: true,
    );
  }

  Future<void> _createSubscription() async {
    final body = await CommerceCreateSubscriptionDialog.show(context, _plans);
    if (body == null) return;
    await _mutate(
      () => _commerce.createSubscription(_tenant.text.trim(), body),
      'Subscription created.',
    );
  }

  Future<void> _changeStatus(Map<String, dynamic> subscription) async {
    final status = await CommerceStatusDialog.show(
      context,
      subscription['status']?.toString() ?? 'pending',
    );
    if (status == null) return;
    await _mutate(
      () => _commerce.transitionSubscription(
        subscription['id'].toString(),
        status,
        _revision(subscription),
      ),
      'Subscription status changed.',
    );
  }

  Future<void> _changePlan(Map<String, dynamic> subscription) async {
    final selected = await CommercePlanChangeDialog.show(context, _plans);
    if (selected == null) return;
    await _mutate(
      () => _commerce.changePlan(
        subscription['id'].toString(),
        selected.$1,
        selected.$2,
        _revision(subscription),
      ),
      'Subscription plan changed.',
    );
  }

  Future<void> _renew(Map<String, dynamic> subscription) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Run administrative renewal?',
      message:
          'This repair action advances the subscription period without debiting the wallet. Normal paid renewal belongs to the opt-in renewal worker.',
      confirmLabel: 'Renew without debit',
    );
    if (!confirmed) return;
    await _mutate(
      () => _commerce.renewSubscription(
        subscription['id'].toString(),
        _revision(subscription),
      ),
      'Administrative renewal completed.',
    );
  }

  Future<void> _adjustWallet() async {
    final body = await CommerceWalletAdjustmentDialog.show(
      context,
      _currency.text,
    );
    if (body == null ||
        !await _confirmFinancial('Post immutable adjustment?')) {
      return;
    }
    await _mutate(
      () => _commerce.adjustWallet(_tenant.text.trim(), body),
      'Wallet adjustment posted.',
    );
  }

  Future<bool> _confirmFinancial(String title) => ConfirmDialog.show(
    context,
    title: title,
    message:
        'This changes the tenant financial record. Type the tenant ID to confirm the exact target.',
    confirmLabel: 'Confirm financial change',
    destructive: true,
    confirmText: _tenant.text.trim(),
  );

  Future<void> _reconcile() => _run(
    () => _commerce.reconcile(_tenant.text.trim()),
    onSuccess: (response) {
      _reconciliation = commerceRecord(response, 'report');
      _tenantError = null;
    },
  );

  Future<void> _loadEvents(String orderID) => _run(
    () => _commerce.listPaymentEvents(_tenant.text.trim(), orderID),
    onSuccess: (response) {
      _eventOrderID = orderID;
      _events = commerceRecords(response, 'events');
      _tenantError = null;
    },
  );

  /// 共享后台写入：busy 置位 → 成功/失败回填 → busy 复位。
  Future<void> _run(
    Future<Map<String, dynamic>> Function() action, {
    void Function(Map<String, dynamic> response)? onSuccess,
  }) async {
    setState(() => _mutating = true);
    try {
      final response = await action();
      if (mounted && onSuccess != null) setState(() => onSuccess(response));
    } catch (error) {
      if (mounted) setState(() => _tenantError = error.toString());
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _mutate(
    Future<Map<String, dynamic>> Function() action,
    String success, {
    bool reloadPlans = false,
  }) async {
    setState(() => _mutating = true);
    try {
      await action();
      if (!mounted) return;
      showAppSnackBar(context, content: LocalizedText(success));
      if (reloadPlans) await _loadPlans();
      if (_tenantLoaded) await _loadTenant();
    } catch (error) {
      if (mounted) setState(() => _tenantError = error.toString());
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  @override
  Widget build(BuildContext context) => _buildCommerceTab(context);

  Future<void> _refresh() async {
    await _loadPlans();
    if (_tenantLoaded) await _loadTenant();
  }

  static int _revision(Map<String, dynamic> record) =>
      (record['revision'] as num?)?.toInt() ?? 0;
}
