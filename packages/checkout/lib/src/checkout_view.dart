import 'dart:async';

import 'package:app_localizations/app_localizations.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:payment_domain/payment_domain.dart';

import 'checkout_cubit.dart';

/// The same screen is mounted by all four features and the standalone app.
final class CheckoutView extends StatefulWidget {
  const CheckoutView({
    required this.dependencies,
    required this.onFinished,
    this.intent,
    this.onPaymentChanged,
    this.onBack,
    super.key,
  });

  final CheckoutDependencies dependencies;
  final PaymentIntent? intent;
  final ValueChanged<PaymentRecord>? onPaymentChanged;
  final VoidCallback onFinished;
  final VoidCallback? onBack;

  @override
  State<CheckoutView> createState() => _CheckoutViewState();
}

final class _CheckoutViewState extends State<CheckoutView> {
  late final CheckoutCubit _controller;
  String? _notifiedPayment;

  @override
  void initState() {
    super.initState();
    _controller = widget.dependencies.createController();
    final intent = widget.intent;
    unawaited(
      intent == null ? _controller.restore() : _controller.begin(intent),
    );
  }

  @override
  void dispose() {
    unawaited(_controller.close());
    super.dispose();
  }

  /// Setting the journal aside unblocks new payments, so it needs an explicit
  /// second confirmation. The dialog lives on the root navigator.
  Future<void> _confirmDiscard() async {
    void close(bool confirmed) =>
        Navigator.of(context, rootNavigator: true).pop(confirmed);
    final l10n = context.l10n;
    final confirmed = await dsShowDialog<bool>(
      context: context,
      title: l10n.checkoutDiscardTitle,
      child: DsText(l10n.checkoutDiscardMessage),
      actions: [
        DsButton(
          label: l10n.commonCancel,
          onPressed: () => close(false),
          variant: DsButtonVariant.quiet,
        ),
        DsButton(
          label: l10n.checkoutDiscardConfirm,
          onPressed: () => close(true),
        ),
      ],
    );
    if (!mounted || confirmed != true) return;
    await _controller.discardUnreadableJournal();
  }

  @override
  Widget build(BuildContext context) => BlocProvider.value(
    value: _controller,
    child: BlocConsumer<CheckoutCubit, CheckoutState>(
      listener: (context, state) {
        final payment = state.payment;
        if (payment != null &&
            payment.status == PaymentStatus.succeeded &&
            payment.id != _notifiedPayment) {
          _notifiedPayment = payment.id;
          widget.onPaymentChanged?.call(payment);
        }
      },
      builder: (context, state) {
        final l10n = context.l10n;
        final formats = context.formats;
        return DsPage(
          onBack: _back(state),
          // Leaving while the request is on its way would hide its outcome;
          // the journal keeps it, but the person should see it settle.
          backEnabled: state.phase != CheckoutPhase.submitting,
          title: switch (state.phase) {
            CheckoutPhase.succeeded =>
              state.payment?.ticket == null
                  ? l10n.checkoutReceiptTitle
                  : l10n.checkoutTicketTitle,
            CheckoutPhase.processing ||
            CheckoutPhase.uncertain => l10n.checkoutStatusTitle,
            _ => l10n.checkoutConfirmTitle,
          },
          subtitle: l10n.commonDemoDisclaimer,
          children: [
            if (state.resumed)
              DsStatus(
                title: l10n.checkoutPreviousPaymentTitle,
                message: l10n.checkoutPreviousPaymentMessage,
              ),
            if (state.quote case final quote?)
              DsPaymentSummary(
                title: quote.recipient,
                amount: formats.money(quote.total),
                details: [
                  DsDetail(l10n.checkoutPurpose, quote.description),
                  DsDetail(l10n.commonAmount, formats.money(quote.amount)),
                  DsDetail(l10n.commonFee, formats.money(quote.fee)),
                  DsDetail(
                    l10n.checkoutDebitAccount,
                    widget.dependencies.accountLabel?.call(
                          quote.intent.accountId,
                        ) ??
                        l10n.checkoutAccountFallback(quote.intent.accountId),
                  ),
                ],
                notice: l10n.checkoutServerConfirmed,
              ),
            ..._content(l10n, state),
            if (widget.onBack != null && state.phase == CheckoutPhase.review)
              DsButton(
                label: l10n.checkoutChangeDetails,
                onPressed: widget.onBack,
                variant: DsButtonVariant.quiet,
              ),
          ],
        );
      },
    ),
  );

  List<Widget> _content(
    AppLocalizations l10n,
    CheckoutState state,
  ) => switch (state.phase) {
    CheckoutPhase.idle => [
      DsStatus(
        title: l10n.checkoutNoPending,
        kind: DsStatusKind.empty,
        action: DsButton(label: l10n.commonDone, onPressed: widget.onFinished),
      ),
    ],
    CheckoutPhase.loadingQuote => [DsLoading(label: l10n.checkoutLoadingTerms)],
    CheckoutPhase.review => [
      DsButton(label: l10n.checkoutConfirm, onPressed: _controller.confirm),
    ],
    CheckoutPhase.submitting => [
      DsStatus(
        title: l10n.checkoutSubmittingTitle,
        message: l10n.checkoutSubmittingMessage,
        kind: DsStatusKind.loading,
      ),
    ],
    CheckoutPhase.processing => [
      DsStatus(
        title: l10n.checkoutProcessingTitle,
        message: l10n.checkoutProcessingMessage,
        action: DsButton(
          label: l10n.checkoutCheckStatus,
          onPressed: _controller.checkStatus,
        ),
      ),
    ],
    CheckoutPhase.uncertain => [
      DsStatus(
        title: l10n.checkoutUncertainTitle,
        message: switch (state.failure) {
          final failure? => l10n.paymentFailure(failure),
          null => null,
        },
        action: DsButton(
          label: l10n.checkoutCheckStatus,
          onPressed: _controller.checkStatus,
        ),
      ),
      DsButton(
        label: l10n.checkoutRetrySameKey,
        onPressed: _controller.retrySamePayment,
        variant: DsButtonVariant.secondary,
      ),
    ],
    CheckoutPhase.succeeded => [
      DsStatus(
        title: l10n.checkoutSucceeded,
        message: state.payment?.ticket == null
            ? l10n.checkoutReceiptNumber(
                state.payment?.receiptId ?? state.payment?.id ?? '',
              )
            : null,
        kind: DsStatusKind.success,
      ),
      if (state.payment?.ticket case final ticket?)
        DsCard(child: DsText(ticket, style: DsTextStyle.title)),
      if (_canContinueWithNew(state))
        DsButton(
          label: l10n.checkoutContinueNew,
          onPressed: _controller.continueWithNew,
        ),
      DsButton(
        label: l10n.commonDone,
        onPressed: widget.onFinished,
        variant: _canContinueWithNew(state)
            ? DsButtonVariant.quiet
            : DsButtonVariant.primary,
      ),
    ],
    CheckoutPhase.failed => [
      DsStatus(
        title: l10n.checkoutFailed,
        message: switch (state.failure) {
          final failure? => l10n.paymentFailure(failure),
          null => null,
        },
        kind: DsStatusKind.error,
        action: _canContinueWithNew(state)
            ? DsButton(
                label: l10n.checkoutContinueNew,
                onPressed: _controller.continueWithNew,
              )
            : switch (state.failure?.code) {
                PaymentFailureCode.seatConflict ||
                PaymentFailureCode.billStale => DsButton(
                  label: l10n.checkoutRefreshSelection,
                  onPressed: widget.onFinished,
                ),
                PaymentFailureCode.storage ||
                PaymentFailureCode.journalUnreadable ||
                PaymentFailureCode.journalDiscardFailed => DsButton(
                  label: l10n.checkoutRecheck,
                  onPressed: widget.intent == null
                      ? _controller.restore
                      : _controller.refreshQuote,
                ),
                // Fresh terms cannot fix these: the details or the balance
                // have to change first.
                PaymentFailureCode.insufficientFunds ||
                PaymentFailureCode.validation ||
                PaymentFailureCode.declined => switch (widget.onBack) {
                  final onBack? => DsButton(
                    label: l10n.checkoutChangeDetails,
                    onPressed: onBack,
                  ),
                  null => null,
                },
                _ => DsButton(
                  label: l10n.checkoutRefreshTerms,
                  onPressed: widget.intent == null
                      ? _controller.restore
                      : _controller.refreshQuote,
                ),
              },
      ),
      if (state.failure?.code == PaymentFailureCode.journalUnreadable)
        DsButton(
          label: l10n.checkoutDiscard,
          onPressed: () => unawaited(_confirmDiscard()),
          variant: DsButtonVariant.secondary,
        ),
      DsButton(
        label: l10n.commonBack,
        onPressed: _back(state),
        variant: DsButtonVariant.quiet,
      ),
    ],
  };

  /// The resolved earlier payment no longer blocks the one this screen was
  /// opened for.
  bool _canContinueWithNew(CheckoutState state) =>
      state.resumed && state.pending == null && widget.intent != null;

  /// Before anything was charged, back returns to the details the person
  /// entered; once a payment exists, the flow is finished.
  VoidCallback _back(CheckoutState state) => switch (state.phase) {
    CheckoutPhase.loadingQuote ||
    CheckoutPhase.review => widget.onBack ?? widget.onFinished,
    CheckoutPhase.failed when state.payment == null && !state.resumed =>
      widget.onBack ?? widget.onFinished,
    _ => widget.onFinished,
  };
}

/// Checks the durable journal whenever a feature is opened, including after
/// process restart. Feature constructors never need a banking-global singleton.
final class RecoverablePaymentFeature extends StatefulWidget {
  const RecoverablePaymentFeature({
    required this.dependencies,
    required this.child,
    this.onPaymentChanged,
    super.key,
  });

  final CheckoutDependencies dependencies;
  final Widget child;
  final ValueChanged<PaymentRecord>? onPaymentChanged;

  @override
  State<RecoverablePaymentFeature> createState() =>
      _RecoverablePaymentFeatureState();
}

final class _RecoverablePaymentFeatureState
    extends State<RecoverablePaymentFeature> {
  bool _recover = false;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    unawaited(_check());
  }

  Future<void> _check() async {
    bool recover;
    try {
      recover = await widget.dependencies.pendingStore.load() != null;
    } catch (_) {
      recover = true;
    }
    if (mounted) {
      setState(() {
        _recover = recover;
        _checked = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) {
      return DsPage(
        children: [DsLoading(label: context.l10n.checkoutCheckingSaved)],
      );
    }
    if (!_recover) return widget.child;
    return CheckoutView(
      dependencies: widget.dependencies,
      onPaymentChanged: widget.onPaymentChanged,
      onFinished: () => setState(() => _recover = false),
    );
  }
}
