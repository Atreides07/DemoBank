import 'dart:async';

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
    final confirmed = await dsShowDialog<bool>(
      context: context,
      title: 'Удалить повреждённую запись?',
      child: const DsText(
        'Запись будет перенесена в архив для разбора, а новые оплаты '
        'разблокируются. Если эта операция уже отправлялась, сначала '
        'проверьте историю, чтобы не оплатить её повторно.',
      ),
      actions: [
        DsButton(
          label: 'Отмена',
          onPressed: () => close(false),
          variant: DsButtonVariant.quiet,
        ),
        DsButton(label: 'Удалить запись', onPressed: () => close(true)),
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
      builder: (context, state) => DsPage(
        onBack: switch (state.phase) {
          CheckoutPhase.loadingQuote ||
          CheckoutPhase.review => widget.onBack ?? widget.onFinished,
          _ => widget.onFinished,
        },
        title: switch (state.phase) {
          CheckoutPhase.succeeded =>
            state.payment?.ticket == null ? 'Квитанция' : 'Ваш билет',
          CheckoutPhase.processing ||
          CheckoutPhase.uncertain => 'Статус платежа',
          _ => 'Подтверждение оплаты',
        },
        subtitle:
            'Демонстрационный процессинг · реальные деньги не списываются',
        children: [
          if (state.quote case final quote?)
            DsPaymentSummary(
              title: quote.recipient,
              amount: quote.total.format(),
              details: [
                DsDetail('Назначение', quote.description),
                DsDetail('Сумма', quote.amount.format()),
                DsDetail('Комиссия', quote.fee.format()),
                DsDetail(
                  'Счёт списания',
                  widget.dependencies.accountLabel?.call(
                        quote.intent.accountId,
                      ) ??
                      (quote.intent.accountId == 'main'
                          ? 'Основной счёт'
                          : quote.intent.accountId == 'savings'
                          ? 'Накопительный счёт'
                          : 'Выбранный счёт'),
                ),
              ],
              notice: 'Сумма и комиссия подтверждены сервером.',
            ),
          ..._content(state),
          if (widget.onBack != null && state.phase == CheckoutPhase.review)
            DsButton(
              label: 'Изменить данные',
              onPressed: widget.onBack,
              variant: DsButtonVariant.quiet,
            ),
        ],
      ),
    ),
  );

  List<Widget> _content(CheckoutState state) => switch (state.phase) {
    CheckoutPhase.idle => [
      DsStatus(
        title: 'Незавершённых платежей нет',
        kind: DsStatusKind.empty,
        action: DsButton(label: 'Готово', onPressed: widget.onFinished),
      ),
    ],
    CheckoutPhase.loadingQuote => [
      const DsLoading(label: 'Проверяем условия и сохранённые операции…'),
    ],
    CheckoutPhase.review => [
      DsButton(label: 'Подтвердить оплату', onPressed: _controller.confirm),
    ],
    CheckoutPhase.submitting => [
      const DsStatus(
        title: 'Получаем подтверждение',
        message:
            'Можно покинуть экран. Сохранённый платёж восстановится '
            'при следующем открытии.',
        kind: DsStatusKind.loading,
      ),
    ],
    CheckoutPhase.processing => [
      DsStatus(
        title: 'Платёж принят и обрабатывается',
        message:
            'Это ещё не окончательный результат. Проверяем его по '
            'сохранённому идентификатору.',
        action: DsButton(
          label: 'Проверить статус',
          onPressed: _controller.checkStatus,
        ),
      ),
    ],
    CheckoutPhase.uncertain => [
      DsStatus(
        title: 'Ответ пока не получен',
        message: state.failure?.message,
        action: DsButton(
          label: 'Проверить статус',
          onPressed: _controller.checkStatus,
        ),
      ),
      DsButton(
        label: 'Повторить с сохранённым ключом',
        onPressed: _controller.retrySamePayment,
        variant: DsButtonVariant.secondary,
      ),
    ],
    CheckoutPhase.succeeded => [
      DsStatus(
        title: 'Оплата выполнена',
        message: 'Квитанция № ${state.payment?.receiptId ?? state.payment?.id}',
        kind: DsStatusKind.success,
      ),
      if (state.payment?.ticket case final ticket?)
        DsCard(child: DsText(ticket, style: DsTextStyle.title)),
      DsButton(label: 'Готово', onPressed: widget.onFinished),
    ],
    CheckoutPhase.failed => [
      DsStatus(
        title: 'Оплата не выполнена',
        message: state.failure?.message,
        kind: DsStatusKind.error,
        action: switch (state.failure?.code) {
          PaymentFailureCode.seatConflict || PaymentFailureCode.billStale =>
            DsButton(label: 'Обновить выбор', onPressed: widget.onFinished),
          PaymentFailureCode.storage ||
          PaymentFailureCode.journalUnreadable => DsButton(
            label: 'Повторить проверку',
            onPressed: _controller.restore,
          ),
          _ => DsButton(
            label: 'Обновить условия',
            onPressed: widget.intent == null
                ? _controller.restore
                : _controller.refreshQuote,
          ),
        },
      ),
      if (state.failure?.code == PaymentFailureCode.journalUnreadable)
        DsButton(
          label: 'Удалить повреждённую запись',
          onPressed: () => unawaited(_confirmDiscard()),
          variant: DsButtonVariant.secondary,
        ),
      DsButton(
        label: 'Вернуться',
        onPressed: widget.onFinished,
        variant: DsButtonVariant.quiet,
      ),
    ],
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
      return const DsPage(
        children: [DsLoading(label: 'Проверяем сохранённые операции…')],
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
