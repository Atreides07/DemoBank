import 'dart:async';

import 'package:bank_core/bank_core.dart';
import 'package:checkout/checkout.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:payment_domain/payment_domain.dart';

import 'cinema_cubit.dart';
import 'models.dart';

final class CinemaFeature extends StatelessWidget {
  const CinemaFeature({
    required this.repository,
    required this.checkout,
    required this.accountId,
    this.onPaymentChanged,
    super.key,
  });
  final CinemaRepository repository;
  final CheckoutDependencies checkout;
  final String accountId;
  final ValueChanged<PaymentRecord>? onPaymentChanged;

  @override
  Widget build(BuildContext context) => RecoverablePaymentFeature(
    dependencies: checkout,
    onPaymentChanged: onPaymentChanged,
    child: _CinemaScreen(
      repository: repository,
      checkout: checkout,
      accountId: accountId,
      onPaymentChanged: onPaymentChanged,
    ),
  );
}

final class _CinemaScreen extends StatefulWidget {
  const _CinemaScreen({
    required this.repository,
    required this.checkout,
    required this.accountId,
    this.onPaymentChanged,
  });
  final CinemaRepository repository;
  final CheckoutDependencies checkout;
  final String accountId;
  final ValueChanged<PaymentRecord>? onPaymentChanged;
  @override
  State<_CinemaScreen> createState() => _CinemaScreenState();
}

final class _CinemaScreenState extends State<_CinemaScreen> {
  late final CinemaCubit _controller;
  PaymentIntent? _intent;

  @override
  void initState() {
    super.initState();
    _controller = CinemaCubit(widget.repository);
    unawaited(_controller.loadMovies());
  }

  @override
  void dispose() {
    unawaited(_controller.close());
    super.dispose();
  }

  void _finish() {
    setState(() => _intent = null);
    unawaited(_controller.retry());
  }

  @override
  Widget build(BuildContext context) {
    if (_intent case final intent?) {
      return CheckoutView(
        dependencies: widget.checkout,
        intent: intent,
        onPaymentChanged: (payment) {
          _controller.clearSelection();
          widget.onPaymentChanged?.call(payment);
        },
        onFinished: _finish,
        onBack: () => setState(() => _intent = null),
      );
    }
    return BlocBuilder<CinemaCubit, CinemaState>(
      bloc: _controller,
      builder: (context, state) => DsPage(
        title: 'Кино',
        onBack: state.movie == null
            ? null
            : state.session == null
            ? _controller.loadMovies
            : () => _controller.selectMovie(state.movie!),
        subtitle: 'Фильм, удобный сеанс и ваши места',
        children: [
          if (state.movie case final movie?)
            DsCard(
              child: DsColumn(
                children: [
                  DsText(movie.title, style: DsTextStyle.headline),
                  DsText(
                    '${movie.durationMinutes} мин · ${movie.description}',
                    tone: DsTone.muted,
                  ),
                  DsButton(
                    label: 'Выбрать другой фильм',
                    onPressed: _controller.loadMovies,
                    variant: DsButtonVariant.quiet,
                  ),
                ],
              ),
            ),
          if (state.loading)
            const DsLoading(label: 'Уточняем расписание и доступность…'),
          if (state.error != null)
            DsStatus(
              title: 'Кинотеатр временно недоступен',
              message: state.error,
              kind: DsStatusKind.error,
              action: DsButton(
                label: 'Повторить',
                onPressed: _controller.retry,
              ),
            ),
          if (state.notice != null)
            DsStatus(
              title: 'Доступность мест изменилась',
              message: state.notice,
            ),
          if (state.movie == null) ...[
            for (final movie in state.movies)
              DsListTile(
                title: movie.title,
                subtitle: '${movie.durationMinutes} мин · ${movie.description}',
                icon: DsIcons.cinema,
                onTap: () => _controller.selectMovie(movie),
              ),
            if (state.loaded && state.movies.isEmpty && state.error == null)
              const DsStatus(
                title: 'Афиша пока пуста',
                kind: DsStatusKind.empty,
              ),
          ],
          if (state.movie != null && state.session == null) ...[
            DsSection(
              title: 'Выберите сеанс',
              child: DsColumn(
                children: [
                  for (final session in state.sessions)
                    DsListTile(
                      title: _date(session.startsAt),
                      subtitle: session.cinema,
                      trailing: DsMoneyText(
                        session.price.format(),
                        prominent: false,
                      ),
                      icon: DsIcons.schedule,
                      onTap: () => _controller.selectSession(session),
                    ),
                  if (state.loaded &&
                      state.sessions.isEmpty &&
                      state.error == null)
                    const DsStatus(
                      title: 'Для этого фильма сеансов нет',
                      kind: DsStatusKind.empty,
                    ),
                ],
              ),
            ),
          ],
          if (state.session case final session?) ...[
            DsSection(
              title: 'Места в зале',
              subtitle: '${session.cinema} · ${_date(session.startsAt)}',
              action: DsButton(
                label: 'Другой сеанс',
                variant: DsButtonVariant.quiet,
                onPressed: () => _controller.selectMovie(state.movie!),
              ),
              child: DsColumn(
                children: [
                  const DsText(
                    'Экран · выберите свободные места',
                    style: DsTextStyle.label,
                  ),
                  DsFlow(
                    children: [
                      for (final seat in state.seats)
                        if (seat.available)
                          DsChoice(
                            label: seat.label,
                            selected: state.selectedIds.contains(seat.id),
                            onSelected: (selected) =>
                                _controller.toggleSeat(seat.id, selected),
                          )
                        else
                          DsButton(
                            label: '${seat.label} · занято',
                            onPressed: null,
                            variant: DsButtonVariant.secondary,
                          ),
                    ],
                  ),
                  if (state.loaded &&
                      state.seats.every((seat) => !seat.available) &&
                      state.error == null)
                    const DsStatus(
                      title: 'Свободных мест нет',
                      message: 'Выберите другой сеанс.',
                      kind: DsStatusKind.empty,
                    ),
                  DsButton(
                    label: 'Обновить доступность',
                    variant: DsButtonVariant.quiet,
                    onPressed: state.loading
                        ? null
                        : () => _controller.selectSession(session),
                  ),
                ],
              ),
            ),
            if (state.selectedSeats.isNotEmpty)
              DsPaymentSummary(
                title: 'Ваш выбор',
                amount: state.total.format(),
                details: [
                  DsDetail(
                    'Места',
                    state.selectedSeats.map((seat) => seat.label).join(', '),
                  ),
                  const DsDetail('Комиссия', '0 ₽'),
                ],
                notice:
                    'Места закрепляются при подтверждении оплаты. '
                    'Если их займут, вы сможете изменить выбор.',
              ),
            DsButton(
              label: 'Перейти к оплате',
              onPressed: state.selectedSeats.isEmpty || state.loading
                  ? null
                  : () => setState(
                      () => _intent = _controller.intent(widget.accountId),
                    ),
            ),
          ],
        ],
      ),
    );
  }

  String _date(DateTime value) =>
      '${ReportingPeriod.date(value)} · ${ReportingPeriod.time(value)} МСК';
}
