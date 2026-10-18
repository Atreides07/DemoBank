import 'dart:async';

import 'package:app_localizations/app_localizations.dart';
import 'package:bank_core/bank_core.dart';
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
  final TextEditingController _amount = TextEditingController();
  PaymentIntent? _intent;
  String? _amountLanguage;

  @override
  void initState() {
    super.initState();
    _controller = MobileCubit(widget.repository);
  }

  /// The amount field is written in the person's language; when the language
  /// changes the current amount is rewritten with the new decimal separator.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final formats = context.formats;
    if (_amountLanguage == formats.languageCode) return;
    _amountLanguage = formats.languageCode;
    final amount = _controller.state.amount;
    if (amount != null) _amount.text = formats.amountInput(amount.minor);
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
      builder: (context, state) => _content(context, state),
    );
  }

  Widget _content(BuildContext context, MobileState state) {
    final l10n = context.l10n;
    final formats = context.formats;
    return DsPage(
      title: l10n.mobileTitle,
      subtitle: l10n.mobileSubtitle,
      children: [
        DsSection(
          title: l10n.mobilePhoneSection,
          child: DsColumn(
            children: [
              DsField(
                label: l10n.mobilePhoneLabel,
                controller: _phone,
                onChanged: _controller.changePhone,
                hint: '+7 916 123-45-67',
                error: _phoneError(l10n, state),
                keyboardType: TextInputType.phone,
              ),
              DsButton(
                label: l10n.mobileLookup,
                loading: state.loading,
                onPressed: state.loading ? null : _controller.lookup,
              ),
            ],
          ),
        ),
        if (state.loading) DsLoading(label: l10n.mobileLookingUp),
        if (state.lookedUp && state.operators.isEmpty)
          DsStatus(
            title: l10n.mobileNoOperatorsTitle,
            message: l10n.mobileNoOperatorsMessage,
            kind: DsStatusKind.empty,
          ),
        if (state.operators.isNotEmpty)
          DsSection(
            title: l10n.mobileOperator,
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
          title: l10n.mobileAmountSection,
          child: DsColumn(
            children: [
              DsField(
                label: l10n.mobileAmountLabel,
                controller: _amount,
                onChanged: (text) => _controller.changeAmount(
                  formats.parseAmount(text, maxIntegerDigits: 6),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                error: switch (state.amountError) {
                  MobileInputError.amountRange => l10n.mobileAmountRange(
                    formats.money(mobileMinimumAmount),
                    formats.money(mobileMaximumAmount),
                  ),
                  null => null,
                  _ => l10n.mobileAmountFormat,
                },
              ),
              DsText(
                l10n.mobileLimits(
                  formats.money(mobileMinimumAmount),
                  formats.money(mobileMaximumAmount),
                  formats.money(const Money(0)),
                ),
                style: DsTextStyle.caption,
                tone: DsTone.muted,
              ),
              DsButton(
                label: l10n.commonContinue,
                onPressed: state.canContinue
                    ? () {
                        if (!_controller.state.canContinue) return;
                        setState(
                          () => _intent = _controller.intent(widget.accountId),
                        );
                      }
                    : null,
              ),
            ],
          ),
        ),
        DsStatus(
          title: l10n.mobileCheckTitle,
          message: l10n.mobileCheckMessage,
        ),
      ],
    );
  }

  static String? _phoneError(AppLocalizations l10n, MobileState state) =>
      switch (state.phoneProblem) {
        null => null,
        MobilePhoneProblem.characters => l10n.mobilePhoneCharacters,
        MobilePhoneProblem.length => l10n.mobilePhoneLength,
        MobilePhoneProblem.lookupFailed =>
          state.lookupFailure?.serverMessage ?? l10n.mobileLookupFailed,
      };
}
