import 'dart:async';

import 'package:bank_core/bank_core.dart';
import 'package:cinema/cinema.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payment_domain/payment_domain.dart';

const _movie = Movie(
  id: 'm',
  title: 'Орбита',
  description: 'Фантастика',
  durationMinutes: 120,
);
final _session = CinemaSession(
  id: 'session',
  movieId: 'm',
  startsAt: DateTime.utc(2026, 10, 16, 16),
  cinema: 'Кино',
  price: const Money(55000),
);
CinemaSeat _seat(String id, {bool available = true}) => CinemaSeat(
  id: id,
  label: id,
  available: available,
  price: const Money(55000),
);

final class _Repository implements CinemaRepository {
  bool sold = false;
  Future<List<CinemaSession>> Function(String)? getSessions;
  @override
  Future<List<Movie>> movies() async => [_movie];
  @override
  Future<List<CinemaSession>> sessions(String movieId) async =>
      getSessions == null ? [_session] : getSessions!(movieId);
  @override
  Future<SeatAvailability> seats(String sessionId) async => SeatAvailability(
    version: sold ? '2' : '1',
    seats: [
      _seat('a', available: !sold),
      _seat('b'),
    ],
  );
}

void main() {
  test(
    'seat availability refresh removes sold selections and explains change',
    () async {
      final repository = _Repository();
      final controller = CinemaCubit(repository);
      await controller.loadMovies();
      await controller.selectMovie(_movie);
      await controller.selectSession(_session);
      controller.toggleSeat('a', true);
      controller.toggleSeat('b', true);
      expect(controller.state.total, const Money(110000));
      repository.sold = true;
      await controller.selectSession(_session);
      expect(controller.state.selectedIds, {'b'});
      expect(controller.state.notice, isNotNull);
      controller.toggleSeat('a', true);
      expect(controller.state.selectedIds, {'b'});
      final intent = controller.intent('source');
      expect(intent.details['seatVersion'], '2');
      expect(intent.details['sessionId'], 'session');
      await controller.close();
    },
  );

  test(
    'stale session responses cannot replace a more recent movie choice',
    () async {
      final response = Completer<List<CinemaSession>>();
      final repository = _Repository()
        ..getSessions = (id) => id == 'm' ? response.future : Future.value([]);
      final controller = CinemaCubit(repository);
      await controller.loadMovies();
      final older = controller.selectMovie(_movie);
      await controller.selectMovie(
        const Movie(
          id: 'other',
          title: 'Другой',
          description: 'Драма',
          durationMinutes: 90,
        ),
      );
      response.complete([_session]);
      await older;
      expect(controller.state.movie!.id, 'other');
      expect(controller.state.sessions, isEmpty);
      expect(() => controller.intent('source'), throwsA(isA<PaymentFailure>()));
      await controller.close();
    },
  );
}
