import 'dart:async';

import 'package:bank_core/bank_core.dart';
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
      builder: (context, state) => DsPage(
        title: 'Коммунальные услуги',
        subtitle: 'Проверяйте начисления и оплачивайте выбранные счета вместе',
        children: [
          DsSection(
            title: 'Ваш лицевой счёт',
            child: DsColumn(
              children: [
                DsField(
                  label: 'Лицевой счёт',
                  controller: _account,
                  hint: 'Демонстрационный: 1234567890',
                  keyboardType: TextInputType.number,
                ),
                DsButton(
                  label: 'Получить начисления',
                  loading: state.phase == UtilitiesPhase.loading,
                  onPressed: state.phase == UtilitiesPhase.loading
                      ? null
                      : () => _controller.load(_account.text),
                ),
              ],
            ),
          ),
          if (state.phase == UtilitiesPhase.loading)
            const DsLoading(label: 'Запрашиваем счета у поставщиков…'),
          if (state.error != null)
            DsStatus(
              title: 'Начисления недоступны',
              message: state.error,
              kind: DsStatusKind.error,
              action: DsButton(
                label: 'Повторить',
                onPressed: () => _controller.load(_account.text),
              ),
            ),
          if (state.phase == UtilitiesPhase.ready && state.bills.isEmpty)
            const DsStatus(
              title: 'Начислений нет',
              message: 'Уточните лицевой счёт или проверьте позже.',
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
                      bill.amount.format(),
                      prominent: false,
                    ),
                    icon: bill.paid ? DsIcons.success : DsIcons.home,
                  ),
                  DsText(
                    'До ${ReportingPeriod.date(bill.dueDate)}',
                    style: DsTextStyle.caption,
                    tone: DsTone.muted,
                  ),
                  if (bill.paid)
                    const DsText('Оплачен', tone: DsTone.success)
                  else
                    DsCheckbox(
                      label: 'Включить в оплату',
                      value: state.selectedIds.contains(bill.id),
                      onChanged: (value) => _controller.toggle(bill.id, value),
                    ),
                ],
              ),
            ),
          if (state.bills.isNotEmpty)
            DsSection(
              title: 'Выбрано к оплате',
              child: DsColumn(
                children: [
                  DsMoneyText(state.selectedTotal.format()),
                  const DsText(
                    'Точная комиссия будет показана перед подтверждением.',
                    style: DsTextStyle.caption,
                    tone: DsTone.muted,
                  ),
                  DsButton(
                    label: 'Продолжить',
                    onPressed: state.selectedBills.isEmpty
                        ? null
                        : () => setState(
                            () =>
                                _intent = _controller.intent(widget.accountId),
                          ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
