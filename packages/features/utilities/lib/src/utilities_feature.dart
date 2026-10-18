import 'dart:async';

import 'package:app_localizations/app_localizations.dart';
import 'package:checkout/checkout.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:payment_domain/payment_domain.dart';

import 'models.dart';
import 'utilities_cubit.dart';

final class UtilitiesFeature extends StatelessWidget {
  const UtilitiesFeature({
    required this.repository,
    required this.checkout,
    required this.accountId,
    this.onPaymentChanged,
    super.key,
  });

  final UtilitiesRepository repository;
  final CheckoutDependencies checkout;
  final String accountId;
  final ValueChanged<PaymentRecord>? onPaymentChanged;

  @override
  Widget build(BuildContext context) => RecoverablePaymentFeature(
    dependencies: checkout,
    onPaymentChanged: onPaymentChanged,
    child: _UtilitiesScreen(
      repository: repository,
      checkout: checkout,
      accountId: accountId,
      onPaymentChanged: onPaymentChanged,
    ),
  );
}

final class _UtilitiesScreen extends StatefulWidget {
  const _UtilitiesScreen({
    required this.repository,
    required this.checkout,
    required this.accountId,
    this.onPaymentChanged,
  });

  final UtilitiesRepository repository;
  final CheckoutDependencies checkout;
  final String accountId;
  final ValueChanged<PaymentRecord>? onPaymentChanged;

  @override
  State<_UtilitiesScreen> createState() => _UtilitiesScreenState();
}

final class _UtilitiesScreenState extends State<_UtilitiesScreen> {
  late final UtilitiesCubit _controller;
  final TextEditingController _account = TextEditingController();
  PaymentIntent? _intent;

  @override
  void initState() {
    super.initState();
    _controller = UtilitiesCubit(widget.repository);
  }

  @override
  void dispose() {
    _account.dispose();
    unawaited(_controller.close());
    super.dispose();
  }

  void _finish() {
    setState(() => _intent = null);
    unawaited(_controller.load(_account.text));
  }

  @override
  Widget build(BuildContext context) {
    if (_intent case final intent?) {
      return CheckoutView(
        dependencies: widget.checkout,
        intent: intent,
        onPaymentChanged: widget.onPaymentChanged,
        onFinished: _finish,
        onBack: () => setState(() => _intent = null),
      );
    }
    return BlocBuilder<UtilitiesCubit, UtilitiesState>(
      bloc: _controller,
      builder: (context, state) {
        final l10n = context.l10n;
        final formats = context.formats;
        return DsPage(
          title: l10n.utilitiesTitle,
          subtitle: l10n.utilitiesSubtitle,
          children: [
            DsSection(
              title: l10n.utilitiesAccountSection,
              child: DsColumn(
                children: [
                  DsField(
                    label: l10n.utilitiesAccountLabel,
                    controller: _account,
                    hint: l10n.utilitiesAccountHint,
                    keyboardType: TextInputType.number,
                  ),
                  DsButton(
                    label: l10n.utilitiesLoad,
                    loading: state.phase == UtilitiesPhase.loading,
                    onPressed: state.phase == UtilitiesPhase.loading
                        ? null
                        : () => _controller.load(_account.text),
                  ),
                ],
              ),
            ),
            if (state.phase == UtilitiesPhase.loading)
              DsLoading(label: l10n.utilitiesLoading),
            if (state.problem case final problem?)
              DsStatus(
                title: l10n.utilitiesUnavailable,
                message: switch (problem) {
                  UtilitiesProblem.invalidAccount =>
                    l10n.utilitiesInvalidAccount,
                  UtilitiesProblem.requestFailed => switch (state.failure) {
                    final failure? => l10n.paymentFailure(failure),
                    null => l10n.utilitiesLoadFailed,
                  },
                },
                kind: DsStatusKind.error,
                action: DsButton(
                  label: l10n.commonRetry,
                  onPressed: () => _controller.load(_account.text),
                ),
              ),
            if (state.phase == UtilitiesPhase.ready && state.bills.isEmpty)
              DsStatus(
                title: l10n.utilitiesEmptyTitle,
                message: l10n.utilitiesEmptyMessage,
                kind: DsStatusKind.empty,
              ),
            for (final bill in state.bills)
              DsCard(
                child: DsColumn(
                  children: [
                    DsListTile(
                      title: bill.title,
                      subtitle: '${bill.provider} · ${bill.description}',
                      trailing: DsMoneyText(
                        formats.money(bill.amount),
                        prominent: false,
                      ),
                      icon: bill.paid ? DsIcons.success : DsIcons.home,
                    ),
                    DsText(
                      l10n.utilitiesDueDate(formats.date(bill.dueDate)),
                      style: DsTextStyle.caption,
                      tone: DsTone.muted,
                    ),
                    if (bill.paid)
                      DsText(l10n.commonPaid, tone: DsTone.success)
                    else
                      DsCheckbox(
                        label: l10n.utilitiesInclude,
                        value: state.selectedIds.contains(bill.id),
                        onChanged: (value) =>
                            _controller.toggle(bill.id, value),
                      ),
                  ],
                ),
              ),
            if (state.bills.isNotEmpty)
              DsSection(
                title: l10n.utilitiesSelected,
                child: DsColumn(
                  children: [
                    DsMoneyText(formats.money(state.selectedTotal)),
                    DsText(
                      l10n.utilitiesFeeNotice,
                      style: DsTextStyle.caption,
                      tone: DsTone.muted,
                    ),
                    DsButton(
                      label: l10n.commonContinue,
                      onPressed: state.selectedBills.isEmpty
                          ? null
                          : () => setState(
                              () => _intent = _controller.intent(
                                widget.accountId,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
