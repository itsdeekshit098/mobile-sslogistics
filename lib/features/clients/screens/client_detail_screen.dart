import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../shared/data/attachment_models.dart';
import '../../../shared/utils/money_format.dart';
import '../../../shared/widgets/attachments_sheet.dart';
import '../../../shared/widgets/delete_confirmation_dialog.dart';
import '../../../shared/widgets/detail_section_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/list_pagination_bar.dart';
import '../../../shared/utils/guarded_action.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/client_models.dart';
import '../providers/client_detail_provider.dart';
import '../providers/client_entries_provider.dart';
import '../providers/client_provider.dart';
import '../widgets/client_form_sheet.dart';
import '../widgets/contact_form_sheet.dart';
import '../widgets/deployment_form_sheet.dart';
import '../widgets/ledger_entry_sheet.dart';

class ClientDetailScreen extends ConsumerWidget {
  final int clientId;

  const ClientDetailScreen({super.key, required this.clientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(clientDetailProvider(clientId));
    final user = ref.watch(authProvider).valueOrNull;
    final canManage = user?.isAdmin == true;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // An individual has no separate points of contact — they are their own
    // contact — so the Contacts tab only exists for a company.
    final isIndividual = async.valueOrNull?.client.isIndividual ?? false;
    final tabLength = isIndividual ? 2 : 3;

    return DefaultTabController(
      length: tabLength,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkPageBg : AppColors.pageBg,
        appBar: AppBar(
          backgroundColor: isDark ? AppColors.darkCardBg : Colors.white,
          elevation: 0,
          surfaceTintColor: isDark ? AppColors.darkCardBg : Colors.white,
          leading: IconButton(
            icon: Icon(AppIcons.arrowLeft,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
            onPressed: () => context.canPop() ? context.pop() : context.go('/clients'),
          ),
          title: Text(
            async.valueOrNull?.client.name ?? 'Client',
            style: TextStyle(
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: [
            if (canManage && async.hasValue)
              PopupMenuButton<String>(
                icon: Icon(AppIcons.moreVert,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                onSelected: (action) => _handleMenu(context, ref, action, async.requireValue),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
          ],
          bottom: async.hasValue
              ? TabBar(
                  tabs: [
                    const Tab(text: 'Statement'),
                    if (!isIndividual) const Tab(text: 'Contacts'),
                    const Tab(text: 'Vehicles'),
                  ],
                )
              : null,
        ),
        body: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorState(
            message: e.toString().replaceFirst('Exception: ', ''),
            onRetry: () => ref.invalidate(clientDetailProvider(clientId)),
          ),
          data: (detail) => Column(
            children: [
              _SummaryCard(detail: detail),
              Expanded(
                child: TabBarView(
                  children: [
                    _StatementTab(clientId: clientId, canManage: canManage, outstanding: detail.balance.outstanding),
                    if (!isIndividual)
                      _ContactsTab(clientId: clientId, detail: detail, canManage: canManage),
                    _VehiclesTab(clientId: clientId, detail: detail, canManage: canManage),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleMenu(BuildContext context, WidgetRef ref, String action, ClientDetail detail) {
    if (action == 'edit') {
      _showEditForm(context, ref, detail.client);
      return;
    }
    if (action == 'delete') {
      showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => DeleteConfirmationDialog(
          title: 'Delete Client',
          targetName: detail.client.name,
          warningText: 'This action cannot be undone.',
          warningSubtext:
              'Only possible while their account is settled and their statement is empty — otherwise mark them inactive instead.',
          onConfirm: () async {
            await ref.read(clientRepositoryProvider).deleteClient(clientId);
            ref.invalidate(clientListProvider);
            if (context.mounted) context.pop();
          },
        ),
      );
    }
  }

  void _showEditForm(BuildContext context, WidgetRef ref, Client client) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.9,
        child: ClientFormSheet(
          client: client,
          onSubmit: ({
            name,
            required clientType,
            required partyKind,
            entityId,
            receivingAccountId,
            location,
            address,
            gstNumber,
            notes,
            openingBalance,
            openingDate,
          }) async {
            final isIndividual = partyKind == 'INDIVIDUAL';
            await ref.read(clientDetailProvider(clientId).notifier).updateClient({
              'party_kind': partyKind,
              // An individual's name is mirrored server-side from the linked
              // entity — omitted so it can never fight the trigger.
              if (!isIndividual) 'name': name,
              'entity_id': isIndividual ? entityId : null,
              'receiving_account_id': receivingAccountId,
              'client_type': clientType,
              'location': location,
              'address': address,
              'gst_number': isIndividual ? null : gstNumber,
              'notes': notes,
            });
            ref.invalidate(clientListProvider);
          },
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final ClientDetail detail;

  const _SummaryCard({required this.detail});

  @override
  Widget build(BuildContext context) {
    final balance = detail.balance;
    final fleetSummary = describeFleetMix(detail.fleetMix);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: DetailSectionCard(
        title: balance.advanceAmount > 0 ? 'Advance Held' : 'Outstanding',
        rows: [
          DetailRowData(
            null,
            formatRupees(balance.advanceAmount > 0 ? balance.advanceAmount : balance.outstanding),
            valueColor: balance.advanceAmount > 0
                ? AppColors.success
                : (balance.outstanding > 0 ? AppColors.error : null),
          ),
          DetailRowData('Total Billed', formatRupees(balance.totalBilled)),
          DetailRowData('Total Received', formatRupees(balance.totalPaid)),
          if (fleetSummary.isNotEmpty) DetailRowData('Fleet', fleetSummary),
          if (detail.client.bankAccount != null)
            DetailRowData('Pays into', detail.client.bankAccount!.displayLabel),
        ],
      ),
    );
  }
}

class _StatementTab extends ConsumerWidget {
  final int clientId;
  final bool canManage;
  final num outstanding;

  const _StatementTab({required this.clientId, required this.canManage, required this.outstanding});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(clientEntriesProvider(clientId));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        if (canManage)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showLedgerSheet(context, ref, 'BILL'),
                    icon: const Icon(AppIcons.receipt, size: 16),
                    label: const Text('Add Bill'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showLedgerSheet(context, ref, 'PAYMENT'),
                    icon: const Icon(AppIcons.handCoins, size: 16),
                    label: const Text('Record Payment'),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ErrorState(
              message: e.toString().replaceFirst('Exception: ', ''),
              onRetry: () => ref.invalidate(clientEntriesProvider(clientId)),
            ),
            data: (state) {
              if (state.entries.isEmpty) {
                return EmptyState(
                  title: 'Nothing on the statement yet',
                  subtitle: 'Add a bill or record a payment to start this account.',
                  icon: AppIcons.receipt,
                );
              }
              return Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 8),
                      itemCount: state.entries.length,
                      itemBuilder: (context, i) {
                        final entry = state.entries[i];
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border(
                                bottom: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      entry.entryType,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        decoration: entry.isReversed ? TextDecoration.lineThrough : null,
                                        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      [
                                        formatDisplayDate(entry.entryDate),
                                        if (entry.invoiceNo != null) 'Inv ${entry.invoiceNo}',
                                        if (entry.description != null) entry.description!,
                                      ].join(' · '),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    (entry.direction == 'DEBIT' ? '+' : '−') + formatRupees(entry.amount),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      decoration: entry.isReversed ? TextDecoration.lineThrough : null,
                                      color: entry.direction == 'DEBIT' ? AppColors.error : AppColors.success,
                                    ),
                                  ),
                                  Text(
                                    'Bal ${formatRupees(entry.runningBalance)}',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                              InkWell(
                                onTap: () => _showAttachments(context, ref, entry, canManage),
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                  child: Row(
                                    children: [
                                      Icon(
                                        AppIcons.fileText,
                                        size: 15,
                                        color: entry.attachmentCount > 0
                                            ? AppColors.primary
                                            : (isDark
                                                ? AppColors.darkTextMuted
                                                : AppColors.textMuted),
                                      ),
                                      if (entry.attachmentCount > 0) ...[
                                        const SizedBox(width: 2),
                                        Text(
                                          '${entry.attachmentCount}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              if (canManage && entry.canReverse)
                                IconButton(
                                  icon: const Icon(AppIcons.undo, size: 16),
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => _confirmReverse(context, ref, entry),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  ListPaginationBar(
                    page: state.page,
                    totalPages: state.totalPages,
                    total: state.total,
                    pageSize: state.pageSize,
                    itemLabel: 'entries',
                    onPageChange: ref.read(clientEntriesProvider(clientId).notifier).changePage,
                    onPageSizeChange: ref.read(clientEntriesProvider(clientId).notifier).changePageSize,
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  void _showLedgerSheet(BuildContext context, WidgetRef ref, String kind) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LedgerEntrySheet(
        kind: kind,
        outstanding: outstanding,
        onSubmit: ({
          required entryType,
          required amount,
          required entryDate,
          invoiceNo,
          periodMonth,
          paymentMethod,
          reference,
          description,
        }) async {
          await ref.read(clientEntriesProvider(clientId).notifier).addEntry(
                entryType: entryType,
                amount: amount,
                entryDate: entryDate,
                invoiceNo: invoiceNo,
                periodMonth: periodMonth,
                paymentMethod: paymentMethod,
                reference: reference,
                description: description,
              );
          ref.invalidate(clientDetailProvider(clientId));
        },
      ),
    );
  }

  void _confirmReverse(BuildContext context, WidgetRef ref, LedgerEntry entry) {
    showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reverse Entry'),
        content: Text(
          'This cancels ${formatRupees(entry.amount)} dated ${formatDisplayDate(entry.entryDate)}. Both the original and the correction stay on the statement.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await runGuarded(context, () async {
                await ref.read(clientEntriesProvider(clientId).notifier).reverseEntry(entry.id);
                ref.invalidate(clientDetailProvider(clientId));
              });
            },
            child: const Text('Reverse'),
          ),
        ],
      ),
    );
  }

  void _showAttachments(BuildContext context, WidgetRef ref, LedgerEntry entry, bool canManage) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.75,
        child: AttachmentsSheet(
          ownerType: AttachmentOwnerType.clientEntry,
          ownerId: entry.id,
          title: 'Payment Proof — ${entry.entryType}',
          canManage: canManage,
          allowPdf: true,
        ),
      ),
    ).then((_) {
      // The row's attachment_count badge only refreshes with the list.
      ref.invalidate(clientEntriesProvider(clientId));
    });
  }
}

class _ContactsTab extends ConsumerWidget {
  final int clientId;
  final ClientDetail detail;
  final bool canManage;

  const _ContactsTab({required this.clientId, required this.detail, required this.canManage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      children: [
        if (canManage)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: OutlinedButton.icon(
              onPressed: () => _showContactSheet(context, ref, null),
              icon: const Icon(AppIcons.plus, size: 16),
              label: const Text('Add Contact'),
            ),
          ),
        if (detail.contacts.isEmpty)
          EmptyState(
            title: 'No contacts yet',
            subtitle: 'Add the people at this company worth having a number for.',
            icon: Icons.contact_phone_outlined,
          )
        else
          ...detail.contacts.map((contact) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCardBg : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                contact.name,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                ),
                              ),
                              if (contact.isPrimary) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text('Primary',
                                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.primary)),
                                ),
                              ],
                            ],
                          ),
                          if (contact.role != null || contact.designation != null)
                            Text(
                              [contact.role, contact.designation].whereType<String>().join(' · '),
                              style: TextStyle(fontSize: 11.5,
                                  color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                            ),
                          if (contact.phone != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(contact.phone!,
                                  style: TextStyle(fontSize: 12.5,
                                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
                            ),
                        ],
                      ),
                    ),
                    if (canManage)
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(AppIcons.pencil, size: 16),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _showContactSheet(context, ref, contact),
                          ),
                          IconButton(
                            icon: const Icon(AppIcons.trash2, size: 16, color: AppColors.error),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _confirmDelete(context, ref, contact),
                          ),
                        ],
                      ),
                  ],
                ),
              )),
      ],
    );
  }

  void _showContactSheet(BuildContext context, WidgetRef ref, ClientContact? contact) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ContactFormSheet(
        contact: contact,
        onSubmit: ({id, required name, role, designation, phone, altPhone, email, isPrimary = false}) =>
            ref.read(clientDetailProvider(clientId).notifier).addOrUpdateContact(
                  id: id,
                  name: name,
                  role: role,
                  designation: designation,
                  phone: phone,
                  altPhone: altPhone,
                  email: email,
                  isPrimary: isPrimary,
                ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, ClientContact contact) {
    showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Contact'),
        content: Text('Remove ${contact.name} from this client\'s contacts?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await runGuarded(
                context,
                () => ref.read(clientDetailProvider(clientId).notifier).deleteContact(contact.id),
              );
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

class _VehiclesTab extends ConsumerWidget {
  final int clientId;
  final ClientDetail detail;
  final bool canManage;

  const _VehiclesTab({required this.clientId, required this.detail, required this.canManage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fleetSummary = describeFleetMix(detail.fleetMix);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      children: [
        if (fleetSummary.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'Running here: $fleetSummary',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              ),
            ),
          ),
        if (canManage)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: OutlinedButton.icon(
              onPressed: () => _showDeploymentSheet(context, ref, null),
              icon: const Icon(AppIcons.plus, size: 16),
              label: const Text('Add Vehicle'),
            ),
          ),
        if (detail.deployments.isEmpty)
          EmptyState(
            title: 'No vehicles recorded',
            subtitle: 'Add the vehicles running for this client.',
            icon: AppIcons.truck,
          )
        else
          ...detail.deployments.map((d) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: d.isActive ? (isDark ? AppColors.darkCardBg : Colors.white) : (isDark ? AppColors.darkPageBg : AppColors.pageBg),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            d.vehicle?.vehicleNumber ?? '${d.quantity} × ${vehicleTypeLabel(d.vehicleType)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                            ),
                          ),
                          Text(describeDeployment(d),
                              style: TextStyle(fontSize: 11.5,
                                  color: isDark ? AppColors.darkTextMuted : AppColors.textMuted)),
                          if (d.monthlyRate != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text('${formatRupees(d.monthlyRate)}/month',
                                  style: TextStyle(fontSize: 12,
                                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
                            ),
                        ],
                      ),
                    ),
                    if (canManage)
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(AppIcons.pencil, size: 16),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _showDeploymentSheet(context, ref, d),
                          ),
                          IconButton(
                            icon: const Icon(AppIcons.trash2, size: 16, color: AppColors.error),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _confirmDelete(context, ref, d),
                          ),
                        ],
                      ),
                  ],
                ),
              )),
      ],
    );
  }

  void _showDeploymentSheet(BuildContext context, WidgetRef ref, ClientDeployment? deployment) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.9,
        child: DeploymentFormSheet(
          deployment: deployment,
          onSubmit: ({
            id,
            vehicleId,
            required quantity,
            vehicleType,
            seatingCapacity,
            truckType,
            containerLength,
            axleType,
            containerBodyType,
            monthlyRate,
            startDate,
            endDate,
          }) =>
              ref.read(clientDetailProvider(clientId).notifier).addOrUpdateDeployment(
                    id: id,
                    vehicleId: vehicleId,
                    quantity: quantity,
                    vehicleType: vehicleType,
                    seatingCapacity: seatingCapacity,
                    truckType: truckType,
                    containerLength: containerLength,
                    axleType: axleType,
                    containerBodyType: containerBodyType,
                    monthlyRate: monthlyRate,
                    startDate: startDate,
                    endDate: endDate,
                  ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, ClientDeployment deployment) {
    showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Vehicle'),
        content: const Text('Remove this deployment from the client?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await runGuarded(
                context,
                () => ref
                    .read(clientDetailProvider(clientId).notifier)
                    .deleteDeployment(deployment.id),
              );
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}
