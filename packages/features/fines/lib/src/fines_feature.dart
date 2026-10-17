import 'dart:async';

import 'package:bank_core/bank_core.dart';
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
      builder: (context, state) => DsPage(
        title: state.selected == null ? 'Штрафы' : 'Подробности штрафа',
        actions: widget.actions,
        onBack: state.selected == null ? null : () => _controller.select(null),
        subtitle: 'Проверка начислений и оплата без комиссии',
        children: [
          if (state.selected == null)
            DsSection(
              title: 'Найти по документу',
              child: DsColumn(
                children: [
                  DsField(
                    label: 'СТС или водительское удостоверение',
                    hint: 'Например, 7712345678',
                    controller: _document,
                    keyboardType: TextInputType.number,
                  ),
                  DsButton(
                    label: 'Найти штрафы',
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
            const DsLoading(label: 'Проверяем государственные начисления…'),
          if (state.error != null)
            DsStatus(
              title: 'Не удалось выполнить поиск',
              message: state.error,
              kind: DsStatusKind.error,
              action: DsButton(
                label: 'Повторить',
                onPressed: () => _controller.search(_document.text),
              ),
            ),
          if (state.phase == FinesPhase.ready && state.bills.isEmpty)
            const DsStatus(
              title: 'Штрафов нет',
              message: 'По этому документу начисления не найдены.',
              kind: DsStatusKind.empty,
            ),
          if (state.selected case final bill?) _detail(bill),
          if (state.bills.isNotEmpty && state.selected == null)
            DsSection(
              title: 'Начисления',
              child: DsColumn(
                children: [
                  for (final bill in state.bills)
                    DsListTile(
                      title: bill.title,
                      subtitle: bill.paid ? 'Оплачен' : bill.description,
                      trailing: DsMoneyText(
                        bill.amount.format(),
                        prominent: false,
                      ),
                      icon: bill.paid ? DsIcons.success : DsIcons.receipt,
                      onTap: () => _controller.select(bill),
                    ),
                ],
              ),
            ),
          if (state.phase == FinesPhase.initial)
            const DsStatus(
              title: 'Документ нужен только для поиска',
              message:
                  'Демонстрационные начисления: 7712345678. '
                  'Для пустого результата используйте 0000000000.',
            ),
        ],
      ),
    );
  }

  Widget _detail(FineBill bill) => DsColumn(
    children: [
      DsPaymentSummary(
        title: bill.title,
        amount: bill.amount.format(),
        details: [
          DsDetail('Основание', bill.description),
          DsDetail('УИН', bill.id),
          DsDetail('Оплатить до', _date(bill.dueDate)),
          DsDetail('Статус', bill.paid ? 'Оплачен' : 'К оплате'),
        ],
      ),
      if (!bill.paid)
        DsButton(
          label: 'Перейти к оплате',
          onPressed: () =>
              setState(() => _intent = _controller.intent(widget.accountId)),
        ),
      DsButton(
        label: 'Все начисления',
        onPressed: () => _controller.select(null),
        variant: DsButtonVariant.quiet,
      ),
    ],
  );

  String _date(DateTime date) => ReportingPeriod.date(date);
}
