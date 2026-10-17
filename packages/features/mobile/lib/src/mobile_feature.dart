import 'dart:async';

import 'package:checkout/checkout.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:payment_domain/payment_domain.dart';

import 'mobile_cubit.dart';
import 'models.dart';

final class MobileFeature extends StatelessWidget {
  const MobileFeature({
    required this.repository,
    required this.checkout,
    required this.accountId,
    this.onPaymentChanged,
    super.key,
  });

  final MobileRepository repository;
  final CheckoutDependencies checkout;
  final String accountId;
  final ValueChanged<PaymentRecord>? onPaymentChanged;

  @override
  Widget build(BuildContext context) => RecoverablePaymentFeature(
    dependencies: checkout,
    onPaymentChanged: onPaymentChanged,
    child: _MobileScreen(
      repository: repository,
      checkout: checkout,
      accountId: accountId,
      onPaymentChanged: onPaymentChanged,
    ),
  );
}

final class _MobileScreen extends StatefulWidget {
  const _MobileScreen({
    required this.repository,
    required this.checkout,
    required this.accountId,
    this.onPaymentChanged,
  });

  final MobileRepository repository;
  final CheckoutDependencies checkout;
  final String accountId;
  final ValueChanged<PaymentRecord>? onPaymentChanged;

  @override
  State<_MobileScreen> createState() => _MobileScreenState();
}

final class _MobileScreenState extends State<_MobileScreen> {
  late final MobileCubit _controller;
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _amount = TextEditingController(text: '500');
  PaymentIntent? _intent;

  @override
  void initState() {
    super.initState();
    _controller = MobileCubit(widget.repository);
  }

  @override
  void dispose() {
    _phone.dispose();
    _amount.dispose();
    unawaited(_controller.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_intent case final intent?) {
      return CheckoutView(
        dependencies: widget.checkout,
        intent: intent,
        onPaymentChanged: widget.onPaymentChanged,
        onFinished: () => setState(() => _intent = null),
        onBack: () => setState(() => _intent = null),
      );
    }
    return BlocBuilder<MobileCubit, MobileState>(
      bloc: _controller,
      builder: (context, state) => DsPage(
        title: 'Мобильная связь',
        subtitle: 'Пополните свой номер или номер близкого человека',
        children: [
          DsSection(
            title: 'Номер телефона',
            child: DsColumn(
              children: [
                DsField(
                  label: 'Телефон',
                  controller: _phone,
                  onChanged: _controller.changePhone,
                  hint: '+7 916 123-45-67',
                  error: state.phoneError,
                  keyboardType: TextInputType.phone,
                ),
                DsButton(
                  label: 'Определить оператора',
                  loading: state.loading,
                  onPressed: state.loading ? null : _controller.lookup,
                ),
              ],
            ),
          ),
          if (state.loading)
            const DsLoading(label: 'Уточняем оператора по номеру…'),
          if (state.lookedUp && state.operators.isEmpty)
            const DsStatus(
              title: 'Для этого номера нет доступных операторов',
              message: 'Проверьте номер или повторите запрос позже.',
              kind: DsStatusKind.empty,
            ),
          if (state.operators.isNotEmpty)
            DsSection(
              title: 'Оператор',
              child: DsFlow(
                children: [
                  for (final operator in state.operators)
                    DsChoice(
                      label: operator.name,
                      selected: state.selectedOperator?.id == operator.id,
                      onSelected: (_) => _controller.selectOperator(operator),
                    ),
                ],
              ),
            ),
          DsSection(
            title: 'Сумма пополнения',
            child: DsColumn(
              children: [
                DsField(
                  label: 'Сумма в рублях',
                  controller: _amount,
                  onChanged: _controller.changeAmount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  error: state.amountError,
                ),
                const DsText(
                  'От 100 до 15 000 ₽. Комиссия — 0 ₽.',
                  style: DsTextStyle.caption,
                  tone: DsTone.muted,
                ),
                DsButton(
                  label: 'Продолжить',
                  onPressed: state.canContinue
                      ? () {
                          if (!_controller.state.canContinue) return;
                          setState(
                            () =>
                                _intent = _controller.intent(widget.accountId),
                          );
                        }
                      : null,
                ),
              ],
            ),
          ),
          const DsStatus(
            title: 'Проверьте номер перед оплатой',
            message: 'После подтверждения зачисление выполняет оператор связи.',
          ),
        ],
      ),
    );
  }
}
