import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/app_user.dart';
import '../../models/content_models.dart';
import '../../services/firestore_service.dart';
import '../../widgets/common.dart';

String _money(num v) {
  final s = v.toStringAsFixed(2);
  return '\$${s.endsWith('.00') ? s.substring(0, s.length - 3) : s}';
}

Color _stageColor(CampaignStage s, ColorScheme scheme) => switch (s) {
      CampaignStage.planning => Colors.blueGrey,
      CampaignStage.selling => Colors.green,
      CampaignStage.ordering => Colors.orange,
      CampaignStage.delivery => Colors.indigo,
      CampaignStage.closed => Colors.grey,
    };

/// Fundraising campaign manager: create campaigns, run their workflow, and
/// track customer orders from payment through delivery.
///
/// Actions are permission-gated: `manage_fundraising` can do everything;
/// `fulfill_fundraising` (volunteers) can add orders and update their
/// payment/fulfillment status but cannot edit campaigns or products.
class FundraisingAdmin extends StatelessWidget {
  final FirestoreService fs;
  final AppUser user;
  const FundraisingAdmin({super.key, required this.fs, required this.user});

  bool get _canManage => user.can('manage_fundraising');

  Future<void> _editCampaign(
      BuildContext context, FundraisingCampaign? existing) async {
    final result = await showDialog<FundraisingCampaign>(
      context: context,
      builder: (_) => _CampaignDialog(existing: existing),
    );
    if (result != null) await fs.upsert('fundraising_campaigns', result);
  }

  void _open(BuildContext context, FundraisingCampaign campaign) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _CampaignDetailScreen(
          fs: fs, user: user, campaignId: campaign.id),
    ));
  }

  void _openVendors(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _VendorsScreen(fs: fs, canManage: _canManage),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FundraisingCampaign>>(
      stream: fs.fundraisingCampaigns(),
      builder: (context, campSnap) {
        if (campSnap.hasError) {
          return EmptyState(
              icon: Icons.error_outline,
              message: 'Something went wrong.\n${campSnap.error}');
        }
        if (!campSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final campaigns = campSnap.data!;
        return StreamBuilder<List<FundraisingOrder>>(
          stream: fs.fundraisingOrders(),
          builder: (context, ordSnap) {
            final orders = ordSnap.data ?? const <FundraisingOrder>[];
            return PageBody(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('Fundraising Campaigns',
                            style: Theme.of(context).textTheme.titleLarge),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _openVendors(context),
                        icon: const Icon(Icons.store_outlined, size: 18),
                        label: const Text('Vendors'),
                      ),
                      if (_canManage) ...[
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: () => _editCampaign(context, null),
                          icon: const Icon(Icons.add),
                          label: const Text('New campaign'),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Plan a sale (mulch, t-shirts, raffle…), track its workflow, '
                    'and manage customer orders and delivery.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  if (campaigns.isEmpty)
                    const EmptyState(
                      icon: Icons.campaign_outlined,
                      message: 'No campaigns yet — create one to get started.',
                    )
                  else
                    for (final c in campaigns)
                      _CampaignCard(
                        campaign: c,
                        orders:
                            orders.where((o) => o.campaignId == c.id).toList(),
                        onOpen: () => _open(context, c),
                      ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _CampaignCard extends StatelessWidget {
  final FundraisingCampaign campaign;
  final List<FundraisingOrder> orders;
  final VoidCallback onOpen;
  const _CampaignCard(
      {required this.campaign, required this.orders, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final raised = orders
        .where((o) => o.paymentStatus == PaymentStatus.paid)
        .fold(0.0, (s, o) => s + o.total);
    final units = orders.fold(0, (s, o) => s + o.unitCount);
    final progress =
        campaign.goalAmount <= 0 ? null : (raised / campaign.goalAmount).clamp(0.0, 1.0);
    final df = DateFormat('MMM d');
    final dates = [
      if (campaign.startsAt != null) df.format(campaign.startsAt!),
      if (campaign.endsAt != null) df.format(campaign.endsAt!),
    ].join(' – ');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(campaign.title,
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  Pill(campaign.stage.label,
                      color: _stageColor(campaign.stage, scheme)),
                ],
              ),
              const SizedBox(height: 4),
              Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Pill(campaign.type.label, icon: Icons.sell_outlined),
                if (dates.isNotEmpty)
                  Text(dates,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant)),
              ]),
              if (campaign.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(campaign.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant)),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 20,
                runSpacing: 6,
                children: [
                  _miniStat(context, '${orders.length}', 'orders'),
                  _miniStat(context, '$units', 'units'),
                  _miniStat(context, _money(raised), 'raised'),
                  if (campaign.goalAmount > 0)
                    _miniStat(context, _money(campaign.goalAmount), 'goal'),
                ],
              ),
              if (progress != null) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                      value: progress, minHeight: 8),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniStat(BuildContext context, String value, String label) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          Text(label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      );
}

// ===========================================================================
// Campaign detail
// ===========================================================================

class _CampaignDetailScreen extends StatelessWidget {
  final FirestoreService fs;
  final AppUser user;
  final String campaignId;
  const _CampaignDetailScreen(
      {required this.fs, required this.user, required this.campaignId});

  bool get _canManage => user.can('manage_fundraising');
  bool get _canFulfill => user.can('fulfill_fundraising') || _canManage;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FundraisingCampaign>>(
      stream: fs.fundraisingCampaigns(),
      builder: (context, campSnap) {
        final campaign = campSnap.data
            ?.where((c) => c.id == campaignId)
            .cast<FundraisingCampaign?>()
            .firstWhere((c) => true, orElse: () => null);
        if (campSnap.hasData && campaign == null) {
          // Deleted while open.
          return Scaffold(
            appBar: AppBar(title: const Text('Campaign')),
            body: const EmptyState(
                icon: Icons.info_outline, message: 'This campaign was removed.'),
          );
        }
        if (campaign == null) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(campaign.title),
            actions: [
              if (_canManage)
                IconButton(
                  tooltip: 'Edit campaign',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () async {
                    final result = await showDialog<FundraisingCampaign>(
                      context: context,
                      builder: (_) => _CampaignDialog(existing: campaign),
                    );
                    if (result != null) {
                      await fs.upsert('fundraising_campaigns', result);
                    }
                  },
                ),
              if (_canManage)
                IconButton(
                  tooltip: 'Delete campaign',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _deleteCampaign(context, campaign),
                ),
            ],
          ),
          body: StreamBuilder<List<FundraisingOrder>>(
            stream: fs.fundraisingOrders(),
            builder: (context, ordSnap) {
              final orders = (ordSnap.data ?? const <FundraisingOrder>[])
                  .where((o) => o.campaignId == campaignId)
                  .toList();
              return StreamBuilder<List<Vendor>>(
                stream: fs.fundraisingVendors(),
                builder: (context, venSnap) {
                  final vendors = venSnap.data ?? const <Vendor>[];
                  return _body(context, campaign, orders, vendors);
                },
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _deleteCampaign(
      BuildContext context, FundraisingCampaign campaign) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete campaign?'),
        content: Text(
            '“${campaign.title}” and its setup will be removed. Existing '
            'orders are not deleted automatically.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await fs.delete('fundraising_campaigns', campaign.id);
      if (context.mounted) Navigator.pop(context);
    }
  }

  Widget _body(BuildContext context, FundraisingCampaign campaign,
      List<FundraisingOrder> orders, List<Vendor> vendors) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
      children: [
        _WorkflowBar(
          stage: campaign.stage,
          onSet: _canManage
              ? (s) => fs.upsert(
                  'fundraising_campaigns', campaign.copyWith(stage: s))
              : null,
        ),
        const SizedBox(height: 20),
        _Dashboard(campaign: campaign, orders: orders),
        const SizedBox(height: 24),
        _ProductsSection(
          campaign: campaign,
          orders: orders,
          vendors: vendors,
          canManage: _canManage,
          onChanged: (products) => fs.upsert('fundraising_campaigns',
              campaign.copyWith(products: products)),
        ),
        if (campaign.vendorName.isNotEmpty ||
            campaign.vendorContact.isNotEmpty) ...[
          const SizedBox(height: 24),
          _sectionTitle(context, 'Vendor / Supplier'),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.local_shipping_outlined),
              title: Text(campaign.vendorName.isEmpty
                  ? 'Vendor'
                  : campaign.vendorName),
              subtitle: campaign.vendorContact.isEmpty
                  ? null
                  : Text(campaign.vendorContact),
            ),
          ),
        ],
        const SizedBox(height: 24),
        _OrdersSection(
          fs: fs,
          campaign: campaign,
          orders: orders,
          canManage: _canManage,
          canFulfill: _canFulfill,
        ),
      ],
    );
  }
}

Widget _sectionTitle(BuildContext context, String text) => Text(
      text,
      style: Theme.of(context)
          .textTheme
          .titleMedium
          ?.copyWith(fontWeight: FontWeight.w700),
    );

/// Horizontal workflow stages; tapping a stage sets it (managers only).
class _WorkflowBar extends StatelessWidget {
  final CampaignStage stage;
  final void Function(CampaignStage)? onSet;
  const _WorkflowBar({required this.stage, this.onSet});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < CampaignStage.values.length; i++) ...[
            if (i > 0)
              Icon(Icons.chevron_right,
                  color: scheme.onSurfaceVariant, size: 20),
            _stageChip(context, CampaignStage.values[i]),
          ],
        ],
      ),
    );
  }

  Widget _stageChip(BuildContext context, CampaignStage s) {
    final scheme = Theme.of(context).colorScheme;
    final active = s == stage;
    final done = s.index < stage.index;
    final color = _stageColor(s, scheme);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: ActionChip(
        avatar: Icon(
          done ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 18,
          color: active
              ? Colors.white
              : (done ? color : scheme.onSurfaceVariant),
        ),
        label: Text(s.label,
            style: TextStyle(
                color: active ? Colors.white : null,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
        backgroundColor: active ? color : scheme.surfaceContainerHighest,
        onPressed: onSet == null ? null : () => onSet!(s),
      ),
    );
  }
}

class _Dashboard extends StatelessWidget {
  final FundraisingCampaign campaign;
  final List<FundraisingOrder> orders;
  const _Dashboard({required this.campaign, required this.orders});

  @override
  Widget build(BuildContext context) {
    final paid = orders.where((o) => o.paymentStatus == PaymentStatus.paid);
    final unpaid = orders.where((o) => o.paymentStatus == PaymentStatus.unpaid);
    final revenue = paid.fold(0.0, (s, o) => s + o.total);
    final outstanding = unpaid.fold(0.0, (s, o) => s + o.total);
    final units = orders.fold(0, (s, o) => s + o.unitCount);
    final delivered = orders
        .where((o) => o.fulfillmentStatus == FulfillmentStatus.delivered)
        .length;
    final toDeliver = orders
        .where((o) =>
            o.fulfillmentStatus == FulfillmentStatus.pending ||
            o.fulfillmentStatus == FulfillmentStatus.packed)
        .length;
    final progress = campaign.goalAmount <= 0
        ? null
        : (revenue / campaign.goalAmount).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(context, 'Dashboard'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _tile(context, Icons.receipt_long, '${orders.length}', 'Orders',
                Colors.blue),
            _tile(context, Icons.inventory_2, '$units', 'Units', Colors.teal),
            _tile(context, Icons.payments, _money(revenue), 'Collected',
                Colors.green),
            _tile(context, Icons.hourglass_bottom, _money(outstanding),
                'Outstanding', Colors.orange),
            _tile(context, Icons.local_shipping, '$toDeliver', 'To deliver',
                Colors.indigo),
            _tile(context, Icons.check_circle, '$delivered', 'Delivered',
                Colors.grey),
          ],
        ),
        if (progress != null) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Text('Goal ${_money(campaign.goalAmount)}',
                  style: Theme.of(context).textTheme.bodySmall),
              const Spacer(),
              Text('${(progress * 100).round()}%',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: progress, minHeight: 10),
          ),
        ],
      ],
    );
  }

  Widget _tile(BuildContext context, IconData icon, String value, String label,
      Color color) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          Text(label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _ProductsSection extends StatelessWidget {
  final FundraisingCampaign campaign;
  final List<FundraisingOrder> orders;
  final List<Vendor> vendors;
  final bool canManage;
  final void Function(List<CampaignProduct>) onChanged;
  const _ProductsSection({
    required this.campaign,
    required this.orders,
    required this.vendors,
    required this.canManage,
    required this.onChanged,
  });

  String _vendorNames(CampaignProduct p) => p.vendorIds
      .map((id) => vendors
          .cast<Vendor?>()
          .firstWhere((v) => v?.id == id, orElse: () => null)
          ?.title)
      .whereType<String>()
      .join(', ');

  int _soldFor(String name) => orders.fold(
      0,
      (s, o) =>
          s +
          o.items
              .where((i) => i.productName == name)
              .fold(0, (t, i) => t + i.quantity));

  Future<void> _edit(BuildContext context, CampaignProduct? existing) async {
    final result = await showDialog<CampaignProduct>(
      context: context,
      builder: (_) => _ProductDialog(existing: existing, vendors: vendors),
    );
    if (result == null) return;
    final list = List<CampaignProduct>.of(campaign.products);
    final idx = list.indexWhere((p) => p.id == result.id);
    if (idx >= 0) {
      list[idx] = result;
    } else {
      list.add(result);
    }
    onChanged(list);
  }

  void _remove(CampaignProduct p) =>
      onChanged(campaign.products.where((x) => x.id != p.id).toList());

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _sectionTitle(context, 'Products / Items')),
            if (canManage)
              TextButton.icon(
                onPressed: () => _edit(context, null),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add item'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (campaign.products.isEmpty)
          Text('No items yet.',
              style: TextStyle(color: scheme.onSurfaceVariant))
        else
          for (final p in campaign.products)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                isThreeLine: p.vendorIds.isNotEmpty,
                title: Text(p.name),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text([
                      _money(p.price),
                      if (p.options.isNotEmpty)
                        'Options: ${p.options.join(', ')}',
                      '${_soldFor(p.name)} sold'
                          '${p.goalQty != null ? ' / ${p.goalQty} goal' : ''}',
                    ].join('  ·  ')),
                    if (p.vendorIds.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            Icon(Icons.store_outlined,
                                size: 13, color: scheme.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _vendorNames(p).isEmpty
                                    ? '${p.vendorIds.length} vendor(s)'
                                    : _vendorNames(p),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: scheme.onSurfaceVariant),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                trailing: canManage
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Edit',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _edit(context, p),
                          ),
                          IconButton(
                            tooltip: 'Remove',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _remove(p),
                          ),
                        ],
                      )
                    : null,
              ),
            ),
      ],
    );
  }
}

class _OrdersSection extends StatelessWidget {
  final FirestoreService fs;
  final FundraisingCampaign campaign;
  final List<FundraisingOrder> orders;
  final bool canManage;
  final bool canFulfill;
  const _OrdersSection({
    required this.fs,
    required this.campaign,
    required this.orders,
    required this.canManage,
    required this.canFulfill,
  });

  Future<void> _edit(BuildContext context, FundraisingOrder? existing) async {
    final result = await showDialog<FundraisingOrder>(
      context: context,
      builder: (_) => _OrderDialog(campaign: campaign, existing: existing),
    );
    if (result != null) await fs.upsert('fundraising_orders', result);
  }

  Future<void> _delete(BuildContext context, FundraisingOrder o) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete order?'),
        content: Text('${o.customerName}\'s order will be permanently removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) await fs.delete('fundraising_orders', o.id);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _sectionTitle(context, 'Orders (${orders.length})')),
            if (canFulfill)
              FilledButton.tonalIcon(
                onPressed: () => _edit(context, null),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add order'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (orders.isEmpty)
          Text('No orders yet.',
              style: TextStyle(color: scheme.onSurfaceVariant))
        else
          for (final o in orders)
            _OrderTile(
              order: o,
              onTap: canFulfill ? () => _edit(context, o) : null,
              onDelete: canManage ? () => _delete(context, o) : null,
              onQuickFulfill: canFulfill
                  ? (s) => fs.upsert('fundraising_orders',
                      o.copyWith(fulfillmentStatus: s))
                  : null,
              onQuickPay: canFulfill
                  ? (s) => fs.upsert(
                      'fundraising_orders', o.copyWith(paymentStatus: s))
                  : null,
            ),
      ],
    );
  }
}

Color _payColor(PaymentStatus s) => switch (s) {
      PaymentStatus.paid => Colors.green,
      PaymentStatus.unpaid => Colors.orange,
      PaymentStatus.refunded => Colors.grey,
    };

Color _fulfillColor(FulfillmentStatus s) => switch (s) {
      FulfillmentStatus.pending => Colors.orange,
      FulfillmentStatus.packed => Colors.blue,
      FulfillmentStatus.delivered => Colors.green,
      FulfillmentStatus.canceled => Colors.grey,
    };

class _OrderTile extends StatelessWidget {
  final FundraisingOrder order;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final void Function(FulfillmentStatus)? onQuickFulfill;
  final void Function(PaymentStatus)? onQuickPay;
  const _OrderTile({
    required this.order,
    this.onTap,
    this.onDelete,
    this.onQuickFulfill,
    this.onQuickPay,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(order.customerName,
                        style: Theme.of(context).textTheme.titleSmall),
                  ),
                  Text(_money(order.total),
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  if (onDelete != null)
                    IconButton(
                      tooltip: 'Delete',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      onPressed: onDelete,
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(order.summary,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant)),
              if (order.deliveryAddress.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.place_outlined,
                      size: 14, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(order.deliveryAddress,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant)),
                  ),
                ]),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _payMenu(context),
                  _fulfillMenu(context),
                  if (order.assignedTo.isNotEmpty)
                    Pill(order.assignedTo, icon: Icons.person_outline),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _payMenu(BuildContext context) {
    final chip = Pill(order.paymentStatus.label,
        icon: Icons.payments_outlined, color: _payColor(order.paymentStatus));
    if (onQuickPay == null) return chip;
    return PopupMenuButton<PaymentStatus>(
      tooltip: 'Set payment status',
      onSelected: onQuickPay,
      itemBuilder: (_) => [
        for (final s in PaymentStatus.values)
          PopupMenuItem(value: s, child: Text(s.label)),
      ],
      child: chip,
    );
  }

  Widget _fulfillMenu(BuildContext context) {
    final chip = Pill(order.fulfillmentStatus.label,
        icon: Icons.local_shipping_outlined,
        color: _fulfillColor(order.fulfillmentStatus));
    if (onQuickFulfill == null) return chip;
    return PopupMenuButton<FulfillmentStatus>(
      tooltip: 'Set fulfillment status',
      onSelected: onQuickFulfill,
      itemBuilder: (_) => [
        for (final s in FulfillmentStatus.values)
          PopupMenuItem(value: s, child: Text(s.label)),
      ],
      child: chip,
    );
  }
}

// ===========================================================================
// Editors
// ===========================================================================

InputDecoration _dec(String label) => InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      isDense: true,
    );

class _CampaignDialog extends StatefulWidget {
  final FundraisingCampaign? existing;
  const _CampaignDialog({this.existing});

  @override
  State<_CampaignDialog> createState() => _CampaignDialogState();
}

class _CampaignDialogState extends State<_CampaignDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _desc;
  late final TextEditingController _goal;
  late final TextEditingController _vendor;
  late final TextEditingController _vendorContact;
  late final TextEditingController _notes;
  late CampaignType _type;
  late CampaignStage _stage;
  DateTime? _start;
  DateTime? _end;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title);
    _desc = TextEditingController(text: e?.description);
    _goal = TextEditingController(
        text: (e != null && e.goalAmount > 0)
            ? e.goalAmount.toStringAsFixed(0)
            : '');
    _vendor = TextEditingController(text: e?.vendorName);
    _vendorContact = TextEditingController(text: e?.vendorContact);
    _notes = TextEditingController(text: e?.notes);
    _type = e?.type ?? CampaignType.product;
    _stage = e?.stage ?? CampaignStage.planning;
    _start = e?.startsAt;
    _end = e?.endsAt;
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _goal.dispose();
    _vendor.dispose();
    _vendorContact.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool start) async {
    final now = DateTime.now();
    final initial = (start ? _start : _end) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (picked != null) {
      setState(() => start ? _start = picked : _end = picked);
    }
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final e = widget.existing;
    Navigator.pop(
      context,
      FundraisingCampaign(
        id: e?.id ?? 'new',
        title: _title.text.trim(),
        description: _desc.text.trim(),
        type: _type,
        stage: _stage,
        goalAmount: double.tryParse(_goal.text.trim()) ?? 0,
        startsAt: _start,
        endsAt: _end,
        products: e?.products ?? const [],
        vendorName: _vendor.text.trim(),
        vendorContact: _vendorContact.text.trim(),
        notes: _notes.text.trim(),
        createdAt: e?.createdAt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('MMM d, y');
    return AlertDialog(
      title: Text(widget.existing == null ? 'New Campaign' : 'Edit Campaign'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                    controller: _title,
                    decoration: _dec('Campaign name'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _desc,
                    decoration: _dec('Description (optional)'),
                    maxLines: 2),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<CampaignType>(
                        initialValue: _type,
                        decoration: _dec('Type'),
                        items: [
                          for (final t in CampaignType.values)
                            DropdownMenuItem(value: t, child: Text(t.label)),
                        ],
                        onChanged: (v) => setState(() => _type = v ?? _type),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<CampaignStage>(
                        initialValue: _stage,
                        decoration: _dec('Stage'),
                        items: [
                          for (final s in CampaignStage.values)
                            DropdownMenuItem(value: s, child: Text(s.label)),
                        ],
                        onChanged: (v) => setState(() => _stage = v ?? _stage),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _goal,
                    decoration: _dec('Fundraising goal (\$, optional)'),
                    keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickDate(true),
                        icon: const Icon(Icons.event, size: 18),
                        label: Text(
                            _start == null ? 'Start date' : df.format(_start!)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickDate(false),
                        icon: const Icon(Icons.event_available, size: 18),
                        label:
                            Text(_end == null ? 'End date' : df.format(_end!)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _vendor,
                    decoration: _dec('Vendor / supplier (optional)')),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _vendorContact,
                    decoration: _dec('Vendor contact (optional)')),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _notes,
                    decoration: _dec('Internal notes (optional)'),
                    maxLines: 2),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

class _ProductDialog extends StatefulWidget {
  final CampaignProduct? existing;
  final List<Vendor> vendors;
  const _ProductDialog({this.existing, this.vendors = const []});

  @override
  State<_ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<_ProductDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _price;
  late final TextEditingController _options;
  late final TextEditingController _goal;
  late final Set<String> _vendorIds;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name);
    _price = TextEditingController(
        text: (e != null && e.price > 0) ? e.price.toStringAsFixed(2) : '');
    _options = TextEditingController(text: e?.options.join(', '));
    _goal =
        TextEditingController(text: e?.goalQty != null ? '${e!.goalQty}' : '');
    _vendorIds = {...?e?.vendorIds};
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _options.dispose();
    _goal.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final e = widget.existing;
    final options = _options.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    Navigator.pop(
      context,
      CampaignProduct(
        id: e?.id ??
            'p_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}',
        name: _name.text.trim(),
        price: double.tryParse(_price.text.trim()) ?? 0,
        options: options,
        goalQty: int.tryParse(_goal.text.trim()),
        // Keep only vendors that still exist, plus any pre-existing ids when
        // the vendor list wasn't available to edit.
        vendorIds: widget.vendors.isEmpty
            ? (e?.vendorIds ?? const [])
            : _vendorIds.toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(widget.existing == null ? 'New Item' : 'Edit Item'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                    controller: _name,
                    decoration: _dec('Item name'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _price,
                    decoration: _dec('Unit price (\$)'),
                    keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _options,
                    decoration:
                        _dec('Options (comma-separated, e.g. S, M, L)')),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _goal,
                    decoration: _dec('Target quantity (optional)'),
                    keyboardType: TextInputType.number),
                const SizedBox(height: 16),
                Text('Vendor(s) / supplier(s)',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                if (widget.vendors.isEmpty)
                  Text(
                    'No vendors yet — add them with the Vendors button on the '
                    'campaigns screen, then assign them here.',
                    style: TextStyle(
                        fontSize: 12, color: scheme.onSurfaceVariant),
                  )
                else
                  for (final v in widget.vendors)
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _vendorIds.contains(v.id),
                      onChanged: (checked) => setState(() {
                        if (checked ?? false) {
                          _vendorIds.add(v.id);
                        } else {
                          _vendorIds.remove(v.id);
                        }
                      }),
                      title: Text(v.title),
                      subtitle:
                          v.contact.isEmpty ? null : Text(v.contact),
                    ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

// ===========================================================================
// Vendors registry
// ===========================================================================

class _VendorsScreen extends StatelessWidget {
  final FirestoreService fs;
  final bool canManage;
  const _VendorsScreen({required this.fs, required this.canManage});

  Future<void> _edit(BuildContext context, Vendor? existing) async {
    final result = await showDialog<Vendor>(
      context: context,
      builder: (_) => _VendorDialog(existing: existing),
    );
    if (result != null) await fs.upsert('fundraising_vendors', result);
  }

  Future<void> _delete(BuildContext context, Vendor v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete vendor?'),
        content: Text(
            '“${v.title}” will be removed. Products that referenced it will '
            'simply show one fewer vendor.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) await fs.delete('fundraising_vendors', v.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendors'),
        actions: [
          if (canManage)
            IconButton(
              tooltip: 'Add vendor',
              icon: const Icon(Icons.add),
              onPressed: () => _edit(context, null),
            ),
        ],
      ),
      body: StreamBuilder<List<Vendor>>(
        stream: fs.fundraisingVendors(),
        builder: (context, snap) {
          if (snap.hasError) {
            return EmptyState(
                icon: Icons.error_outline,
                message: 'Something went wrong.\n${snap.error}');
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final vendors = snap.data!;
          if (vendors.isEmpty) {
            return const EmptyState(
              icon: Icons.store_outlined,
              message: 'No vendors yet — add your suppliers to assign them to '
                  'products.',
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final v in vendors)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.store_outlined),
                    title: Text(v.title),
                    subtitle: Text([
                      if (v.contact.isNotEmpty) v.contact,
                      if (v.notes.isNotEmpty) v.notes,
                    ].join('\n')),
                    isThreeLine: v.contact.isNotEmpty && v.notes.isNotEmpty,
                    trailing: canManage
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Edit',
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _edit(context, v),
                              ),
                              IconButton(
                                tooltip: 'Delete',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _delete(context, v),
                              ),
                            ],
                          )
                        : null,
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _edit(context, null),
              icon: const Icon(Icons.add),
              label: const Text('Add vendor'),
            )
          : null,
    );
  }
}

class _VendorDialog extends StatefulWidget {
  final Vendor? existing;
  const _VendorDialog({this.existing});

  @override
  State<_VendorDialog> createState() => _VendorDialogState();
}

class _VendorDialogState extends State<_VendorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _contact;
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.title);
    _contact = TextEditingController(text: e?.contact);
    _notes = TextEditingController(text: e?.notes);
  }

  @override
  void dispose() {
    _name.dispose();
    _contact.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final e = widget.existing;
    Navigator.pop(
      context,
      Vendor(
        id: e?.id ?? 'new',
        title: _name.text.trim(),
        contact: _contact.text.trim(),
        notes: _notes.text.trim(),
        createdAt: e?.createdAt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'New Vendor' : 'Edit Vendor'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                  controller: _name,
                  decoration: _dec('Vendor / company name'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _contact,
                  decoration: _dec('Contact (phone / email, optional)')),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _notes,
                  decoration: _dec('Notes (optional)'),
                  maxLines: 2),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

class _OrderDialog extends StatefulWidget {
  final FundraisingCampaign campaign;
  final FundraisingOrder? existing;
  const _OrderDialog({required this.campaign, this.existing});

  @override
  State<_OrderDialog> createState() => _OrderDialogState();
}

class _LineDraft {
  CampaignProduct? product;
  String? option;
  final TextEditingController qty;
  _LineDraft({this.product, this.option, int quantity = 1})
      : qty = TextEditingController(text: '$quantity');
}

class _OrderDialogState extends State<_OrderDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _contact;
  late final TextEditingController _address;
  late final TextEditingController _method;
  late final TextEditingController _assigned;
  late final TextEditingController _notes;
  late PaymentStatus _pay;
  late FulfillmentStatus _fulfill;
  final List<_LineDraft> _lines = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.customerName);
    _contact = TextEditingController(text: e?.customerContact);
    _address = TextEditingController(text: e?.deliveryAddress);
    _method = TextEditingController(text: e?.paymentMethod);
    _assigned = TextEditingController(text: e?.assignedTo);
    _notes = TextEditingController(text: e?.notes);
    _pay = e?.paymentStatus ?? PaymentStatus.unpaid;
    _fulfill = e?.fulfillmentStatus ?? FulfillmentStatus.pending;
    if (e != null && e.items.isNotEmpty) {
      for (final item in e.items) {
        final product = widget.campaign.products
            .cast<CampaignProduct?>()
            .firstWhere((p) => p?.name == item.productName, orElse: () => null);
        _lines.add(_LineDraft(
          product: product,
          option: item.option.isEmpty ? null : item.option,
          quantity: item.quantity,
        ));
      }
    } else {
      _lines.add(_LineDraft(
          product: widget.campaign.products.isNotEmpty
              ? widget.campaign.products.first
              : null));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _contact.dispose();
    _address.dispose();
    _method.dispose();
    _assigned.dispose();
    _notes.dispose();
    for (final l in _lines) {
      l.qty.dispose();
    }
    super.dispose();
  }

  double get _total {
    var t = 0.0;
    for (final l in _lines) {
      final p = l.product;
      if (p == null) continue;
      final q = int.tryParse(l.qty.text.trim()) ?? 0;
      t += p.price * q;
    }
    return t;
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final items = <OrderItem>[];
    for (final l in _lines) {
      final p = l.product;
      if (p == null) continue;
      final q = int.tryParse(l.qty.text.trim()) ?? 0;
      if (q <= 0) continue;
      items.add(OrderItem(
        productName: p.name,
        option: l.option ?? '',
        quantity: q,
        unitPrice: p.price,
      ));
    }
    if (items.isEmpty) {
      setState(() => _error = 'Add at least one item with a quantity.');
      return;
    }
    final e = widget.existing;
    Navigator.pop(
      context,
      FundraisingOrder(
        id: e?.id ?? 'new',
        campaignId: widget.campaign.id,
        customerName: _name.text.trim(),
        customerContact: _contact.text.trim(),
        deliveryAddress: _address.text.trim(),
        items: items,
        paymentStatus: _pay,
        paymentMethod: _method.text.trim(),
        fulfillmentStatus: _fulfill,
        assignedTo: _assigned.text.trim(),
        notes: _notes.text.trim(),
        createdAt: e?.createdAt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'New Order' : 'Edit Order'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                    controller: _name,
                    decoration: _dec('Customer name'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _contact,
                    decoration: _dec('Contact (phone / email, optional)')),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _address,
                    decoration: _dec('Delivery address / pickup (optional)'),
                    maxLines: 2),
                const SizedBox(height: 16),
                Text('Items', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                for (var i = 0; i < _lines.length; i++) _lineRow(i),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _lines.add(_LineDraft(
                        product: widget.campaign.products.isNotEmpty
                            ? widget.campaign.products.first
                            : null))),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add item'),
                  ),
                ),
                const Divider(),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('Total: ${_money(_total)}',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<PaymentStatus>(
                        initialValue: _pay,
                        decoration: _dec('Payment'),
                        items: [
                          for (final s in PaymentStatus.values)
                            DropdownMenuItem(value: s, child: Text(s.label)),
                        ],
                        onChanged: (v) => setState(() => _pay = v ?? _pay),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<FulfillmentStatus>(
                        initialValue: _fulfill,
                        decoration: _dec('Fulfillment'),
                        items: [
                          for (final s in FulfillmentStatus.values)
                            DropdownMenuItem(value: s, child: Text(s.label)),
                        ],
                        onChanged: (v) =>
                            setState(() => _fulfill = v ?? _fulfill),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _method,
                    decoration:
                        _dec('Payment method / note (e.g. Cash, Check #)')),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _assigned,
                    decoration: _dec('Assigned volunteer / team (optional)')),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _notes,
                    decoration: _dec('Notes (optional)'),
                    maxLines: 2),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }

  Widget _lineRow(int i) {
    final line = _lines[i];
    final products = widget.campaign.products;
    final hasOptions = line.product?.options.isNotEmpty ?? false;
    // Keep the selected option valid for the chosen product.
    if (hasOptions &&
        (line.option == null ||
            !line.product!.options.contains(line.option))) {
      line.option = line.product!.options.first;
    }
    if (!hasOptions) line.option = null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: DropdownButtonFormField<CampaignProduct>(
              initialValue: products.contains(line.product) ? line.product : null,
              isExpanded: true,
              decoration: _dec('Item'),
              items: [
                for (final p in products)
                  DropdownMenuItem(
                      value: p,
                      child: Text('${p.name} · ${_money(p.price)}',
                          overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (p) => setState(() {
                line.product = p;
                line.option = (p != null && p.options.isNotEmpty)
                    ? p.options.first
                    : null;
              }),
              validator: (v) => v == null ? 'Pick' : null,
            ),
          ),
          if (hasOptions) ...[
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                initialValue: line.option,
                isExpanded: true,
                decoration: _dec('Opt'),
                items: [
                  for (final o in line.product!.options)
                    DropdownMenuItem(value: o, child: Text(o)),
                ],
                onChanged: (o) => setState(() => line.option = o),
              ),
            ),
          ],
          const SizedBox(width: 8),
          SizedBox(
            width: 62,
            child: TextFormField(
              controller: line.qty,
              decoration: _dec('Qty'),
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
            ),
          ),
          IconButton(
            tooltip: 'Remove',
            icon: const Icon(Icons.close, size: 18),
            onPressed: _lines.length == 1
                ? null
                : () => setState(() {
                      _lines.removeAt(i).qty.dispose();
                    }),
          ),
        ],
      ),
    );
  }
}
