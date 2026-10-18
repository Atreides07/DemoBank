import 'dart:async';

import 'package:app_localizations/app_localizations.dart';
import 'package:checkout/checkout.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:payment_domain/payment_domain.dart';

import 'fines_cubit.dart';
import 'models.dart';

final class FinesFeature extends StatelessWidget {
  const FinesFeature({
    required this.repository,
    required this.checkout,
    required this.accountId,
    this.onPaymentChanged,
    this.actions,
    super.key,
  });

  final FinesRepository repository;
  final CheckoutDependencies checkout;
  final String accountId;
  final ValueChanged<PaymentRecord>? onPaymentChanged;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) => RecoverablePaymentFeature(
    dependencies: checkout,
    onPaymentChanged: onPaymentChanged,
    child: _FinesScreen(
      repository: repository,
      actions: actions,
      checkout: checkout,
      accountId: accountId,
      onPaymentChanged: onPaymentChanged,
    ),
  );
}

final class _FinesScreen extends StatefulWidget {
  const _FinesScreen({
    required this.repository,
    required this.checkout,
    required this.accountId,
    this.onPaymentChanged,
    this.actions,
  });

  final FinesRepository repository;
  final CheckoutDependencies checkout;
  final String accountId;
  final ValueChanged<PaymentRecord>? onPaymentChanged;
  final List<Widget>? actions;

  @override
  State<_FinesScreen> createState() => _FinesScreenState();
}

final class _FinesScreenState extends State<_FinesScreen> {
  late final FinesCubit _controller;
  final TextEditingController _document = TextEditingController();
  PaymentIntent? _intent;

  @override
  void initState() {
    super.initState();
    _controller = FinesCubit(widget.repository);
  }

  @override
  void dispose() {
    _document.dispose();
    unawaited(_controller.close());
    super.dispose();
  }

  void _finish() {
    setState(() => _intent = null);
    unawaited(_controller.search(_document.text));
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
    return BlocBuilder<FinesCubit, FinesState>(
      bloc: _controller,
      builder: (context, state) {
        final l10n = context.l10n;
        final formats = context.formats;
        return DsPage(
          title: state.selected == null
              ? l10n.finesTitle
              : l10n.finesDetailsTitle,
          actions: widget.actions,
          onBack: state.selected == null
              ? null
              : () => _controller.select(null),
          subtitle: l10n.finesSubtitle,
          children: [
            if (state.selected == null)
              DsSection(
                title: l10n.finesSearchSection,
                child: DsColumn(
                  children: [
                    DsField(
                      label: l10n.finesDocumentLabel,
                      hint: l10n.finesDocumentHint,
                      controller: _document,
                      onChanged: _controller.changeDocument,
                      keyboardType: TextInputType.number,
                    ),
                    DsButton(
                      label: l10n.finesSearch,
                      loading: state.phase == FinesPhase.loading,
                      onPressed: state.phase == FinesPhase.loading
                          ? null
                          : () => _controller.search(_document.text),
                      icon: DsIcons.search,
                    ),
                  ],
                ),
              ),
            if (state.phase == FinesPhase.loading)
              DsLoading(label: l10n.finesLoading),
            if (state.problem case final problem?)
              DsStatus(
                title: l10n.finesSearchFailedTitle,
                message: switch (problem) {
                  FinesProblem.invalidDocument => l10n.finesInvalidDocument,
                  FinesProblem.requestFailed => l10n.loadFailure(
                    state.failure,
                    l10n.finesSearchFailed,
                  ),
                },
                kind: DsStatusKind.error,
                // Repeating the same invalid input cannot help.
                action: problem == FinesProblem.invalidDocument
                    ? null
                    : DsButton(
                        label: l10n.commonRetry,
                        onPressed: () => _controller.search(_document.text),
                      ),
              ),
            if (state.phase == FinesPhase.ready && state.bills.isEmpty)
              DsStatus(
                title: l10n.finesEmptyTitle,
                message: l10n.finesEmptyMessage,
                kind: DsStatusKind.empty,
              ),
            if (state.selected case final bill?) _detail(context, bill),
            if (state.bills.isNotEmpty && state.selected == null)
              DsSection(
                title: l10n.finesBills,
                child: DsColumn(
                  children: [
                    for (final bill in state.bills)
                      DsListTile(
                        title: bill.title,
                        subtitle: bill.paid
                            ? l10n.commonPaid
                            : bill.description,
                        trailing: DsMoneyText(
                          formats.money(bill.amount),
                          prominent: false,
                        ),
                        icon: bill.paid ? DsIcons.success : DsIcons.receipt,
                        onTap: () => _controller.select(bill),
                      ),
                  ],
                ),
              ),
            if (state.phase == FinesPhase.initial)
              DsStatus(
                title: l10n.finesHintTitle,
                message: l10n.finesHintMessage,
              ),
          ],
        );
      },
    );
  }

  Widget _detail(BuildContext context, FineBill bill) {
    final l10n = context.l10n;
    final formats = context.formats;
    return DsColumn(
      children: [
        DsPaymentSummary(
          title: bill.title,
          amount: formats.money(bill.amount),
          details: [
            DsDetail(l10n.finesBasis, bill.description),
            DsDetail(l10n.finesUin, bill.id),
            DsDetail(l10n.finesPayBefore, formats.date(bill.dueDate)),
            DsDetail(
              l10n.finesStatus,
              bill.paid ? l10n.commonPaid : l10n.finesToPay,
            ),
          ],
        ),
        if (!bill.paid)
          DsButton(
            label: l10n.finesGoToPayment,
            onPressed: () =>
                setState(() => _intent = _controller.intent(widget.accountId)),
          ),
        DsButton(
          label: l10n.finesAllBills,
          onPressed: () => _controller.select(null),
          variant: DsButtonVariant.quiet,
        ),
      ],
    );
  }
}
