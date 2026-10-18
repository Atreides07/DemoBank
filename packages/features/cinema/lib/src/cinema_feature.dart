import 'dart:async';

import 'package:app_localizations/app_localizations.dart';
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
      builder: (context, state) => _content(context, state),
    );
  }

  Widget _content(BuildContext context, CinemaState state) {
    final l10n = context.l10n;
    final formats = context.formats;
    String sessionTime(DateTime value) =>
        l10n.cinemaSessionTime(formats.date(value), formats.time(value));
    return DsPage(
      title: l10n.cinemaTitle,
      onBack: state.movie == null
          ? null
          : state.session == null
          ? _controller.loadMovies
          : () => _controller.selectMovie(state.movie!),
      subtitle: l10n.cinemaSubtitle,
      children: [
        if (state.movie case final movie?)
          DsCard(
            child: DsColumn(
              children: [
                DsText(movie.title, style: DsTextStyle.headline),
                DsText(
                  l10n.cinemaMovieDetails(
                    movie.durationMinutes,
                    movie.description,
                  ),
                  tone: DsTone.muted,
                ),
                DsButton(
                  label: l10n.cinemaOtherMovie,
                  onPressed: _controller.loadMovies,
                  variant: DsButtonVariant.quiet,
                ),
              ],
            ),
          ),
        if (state.loading) DsLoading(label: l10n.cinemaLoading),
        if (state.failed)
          DsStatus(
            title: l10n.cinemaUnavailable,
            message: state.failure?.serverMessage ?? l10n.cinemaLoadFailed,
            kind: DsStatusKind.error,
            action: DsButton(
              label: l10n.commonRetry,
              onPressed: _controller.retry,
            ),
          ),
        if (state.seatsChanged)
          DsStatus(
            title: l10n.cinemaSeatsChangedTitle,
            message: l10n.paymentErrorSeatConflict,
          ),
        if (state.movie == null) ...[
          for (final movie in state.movies)
            DsListTile(
              title: movie.title,
              subtitle: l10n.cinemaMovieDetails(
                movie.durationMinutes,
                movie.description,
              ),
              icon: DsIcons.cinema,
              onTap: () => _controller.selectMovie(movie),
            ),
          if (state.loaded && state.movies.isEmpty && !state.failed)
            DsStatus(title: l10n.cinemaNoMovies, kind: DsStatusKind.empty),
        ],
        if (state.movie != null && state.session == null) ...[
          DsSection(
            title: l10n.cinemaChooseSession,
            child: DsColumn(
              children: [
                for (final session in state.sessions)
                  DsListTile(
                    title: sessionTime(session.startsAt),
                    subtitle: session.cinema,
                    trailing: DsMoneyText(
                      formats.money(session.price),
                      prominent: false,
                    ),
                    icon: DsIcons.schedule,
                    onTap: () => _controller.selectSession(session),
                  ),
                if (state.loaded && state.sessions.isEmpty && !state.failed)
                  DsStatus(
                    title: l10n.cinemaNoSessions,
                    kind: DsStatusKind.empty,
                  ),
              ],
            ),
          ),
        ],
        if (state.session case final session?) ...[
          DsSection(
            title: l10n.cinemaSeats,
            subtitle: l10n.cinemaSessionPlace(
              session.cinema,
              sessionTime(session.startsAt),
            ),
            action: DsButton(
              label: l10n.cinemaOtherSession,
              variant: DsButtonVariant.quiet,
              onPressed: () => _controller.selectMovie(state.movie!),
            ),
            child: DsColumn(
              children: [
                DsText(l10n.cinemaScreenHint, style: DsTextStyle.label),
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
                          label: l10n.cinemaSeatTaken(seat.label),
                          onPressed: null,
                          variant: DsButtonVariant.secondary,
                        ),
                  ],
                ),
                if (state.loaded &&
                    state.seats.every((seat) => !seat.available) &&
                    !state.failed)
                  DsStatus(
                    title: l10n.cinemaNoSeatsTitle,
                    message: l10n.cinemaNoSeatsMessage,
                    kind: DsStatusKind.empty,
                  ),
                DsButton(
                  label: l10n.cinemaRefreshSeats,
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
              title: l10n.cinemaYourChoice,
              amount: formats.money(state.total),
              details: [
                DsDetail(
                  l10n.cinemaSeatsLabel,
                  state.selectedSeats.map((seat) => seat.label).join(', '),
                ),
                DsDetail(
                  l10n.commonFee,
                  formats.money(Money(0, currency: state.total.currency)),
                ),
              ],
              notice: l10n.cinemaSeatsNotice,
            ),
          DsButton(
            label: l10n.cinemaToPayment,
            onPressed: state.selectedSeats.isEmpty || state.loading
                ? null
                : () => setState(
                    () => _intent = _controller.intent(widget.accountId),
                  ),
          ),
        ],
      ],
    );
  }
}
