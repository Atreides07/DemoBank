import 'package:bank_core/bank_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:payment_domain/payment_domain.dart';

import 'models.dart';

final class CinemaState {
  const CinemaState({
    this.movies = const [],
    this.sessions = const [],
    this.seats = const [],
    this.movie,
    this.session,
    this.selectedIds = const {},
    this.seatVersion,
    this.loading = false,
    this.loaded = false,
    this.failed = false,
    this.failure,
    this.seatsChanged = false,
  });
  final List<Movie> movies;
  final List<CinemaSession> sessions;
  final List<CinemaSeat> seats;
  final Movie? movie;
  final CinemaSession? session;
  final Set<String> selectedIds;
  final String? seatVersion;
  final bool loading;
  final bool loaded;

  /// The last request failed; [failure] carries the gateway's details.
  final bool failed;
  final PaymentFailure? failure;

  /// Some previously selected seats were taken while the person was choosing.
  final bool seatsChanged;

  List<CinemaSeat> get selectedSeats => seats
      .where((seat) => seat.available && selectedIds.contains(seat.id))
      .toList(growable: false);
  Money get total =>
      selectedSeats.fold(const Money(0), (sum, seat) => sum + seat.price);
}

final class CinemaCubit extends Cubit<CinemaState> {
  CinemaCubit(this._repository) : super(const CinemaState());
  final CinemaRepository _repository;
  int _generation = 0;

  Future<void> loadMovies() async {
    final generation = ++_generation;
    emit(const CinemaState(loading: true));
    try {
      final movies = await _repository.movies();
      if (!isClosed && generation == _generation) {
        emit(CinemaState(movies: List.unmodifiable(movies), loaded: true));
      }
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      if (!isClosed && generation == _generation) {
        emit(CinemaState(loaded: true, failed: true, failure: _failure(error)));
      }
    }
  }

  Future<void> selectMovie(Movie movie) async {
    final generation = ++_generation;
    final movies = state.movies;
    emit(CinemaState(movies: movies, movie: movie, loading: true));
    try {
      final sessions = await _repository.sessions(movie.id);
      if (!isClosed && generation == _generation) {
        emit(
          CinemaState(
            movies: movies,
            movie: movie,
            sessions: List.unmodifiable(sessions),
            loaded: true,
          ),
        );
      }
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      if (!isClosed && generation == _generation) {
        emit(
          CinemaState(
            movies: movies,
            movie: movie,
            loaded: true,
            failed: true,
            failure: _failure(error),
          ),
        );
      }
    }
  }

  Future<void> selectSession(CinemaSession session) async {
    final generation = ++_generation;
    final previous = state;
    final oldSelection = previous.session?.id == session.id
        ? previous.selectedIds
        : const <String>{};
    emit(
      CinemaState(
        movies: previous.movies,
        movie: previous.movie,
        sessions: previous.sessions,
        session: session,
        loading: true,
      ),
    );
    try {
      final available = await _repository.seats(session.id);
      final availableIds = available.seats
          .where((seat) => seat.available)
          .map((seat) => seat.id)
          .toSet();
      final selected = oldSelection.intersection(availableIds);
      if (!isClosed && generation == _generation) {
        emit(
          CinemaState(
            movies: previous.movies,
            movie: previous.movie,
            sessions: previous.sessions,
            session: session,
            seats: available.seats,
            seatVersion: available.version,
            selectedIds: Set.unmodifiable(selected),
            loaded: true,
            seatsChanged: oldSelection.difference(availableIds).isNotEmpty,
          ),
        );
      }
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      if (!isClosed && generation == _generation) {
        emit(
          CinemaState(
            movies: previous.movies,
            movie: previous.movie,
            sessions: previous.sessions,
            session: session,
            loaded: true,
            failed: true,
            failure: _failure(error),
          ),
        );
      }
    }
  }

  void toggleSeat(String id, bool selected) {
    if (!state.seats.any((seat) => seat.id == id && seat.available)) return;
    final ids = {...state.selectedIds};
    selected ? ids.add(id) : ids.remove(id);
    emit(
      CinemaState(
        movies: state.movies,
        movie: state.movie,
        sessions: state.sessions,
        session: state.session,
        seats: state.seats,
        seatVersion: state.seatVersion,
        selectedIds: Set.unmodifiable(ids),
        loaded: true,
      ),
    );
  }

  void clearSelection() => emit(
    CinemaState(
      movies: state.movies,
      movie: state.movie,
      sessions: state.sessions,
      session: state.session,
      seats: state.seats,
      seatVersion: state.seatVersion,
      loaded: state.loaded,
    ),
  );

  PaymentIntent intent(String accountId) {
    final session = state.session;
    final movie = state.movie;
    if (session == null ||
        movie == null ||
        state.selectedSeats.isEmpty ||
        state.seatVersion == null) {
      throw const PaymentFailure(PaymentFailureCode.validation);
    }
    return PaymentIntent(
      kind: PaymentKind.cinema,
      accountId: accountId,
      // The server names the cinema and film in the language of the request.
      recipient: session.id,
      referenceIds: state.selectedSeats
          .map((seat) => seat.id)
          .toList(growable: false),
      details: {'sessionId': session.id, 'seatVersion': state.seatVersion},
    );
  }

  Future<void> retry() async {
    final session = state.session;
    final movie = state.movie;
    if (session != null) {
      await selectSession(session);
    } else if (movie != null) {
      await selectMovie(movie);
    } else {
      await loadMovies();
    }
  }

  static PaymentFailure? _failure(Object error) =>
      error is PaymentFailure ? error : null;
}
