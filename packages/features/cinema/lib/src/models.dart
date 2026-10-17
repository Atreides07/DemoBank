import 'package:bank_core/bank_core.dart';

final class Movie {
  const Movie({
    required this.id,
    required this.title,
    required this.description,
    required this.durationMinutes,
  });
  final String id;
  final String title;
  final String description;
  final int durationMinutes;
}

final class CinemaSession {
  const CinemaSession({
    required this.id,
    required this.movieId,
    required this.startsAt,
    required this.cinema,
    required this.price,
  });
  final String id;
  final String movieId;
  final DateTime startsAt;
  final String cinema;
  final Money price;
}

final class CinemaSeat {
  const CinemaSeat({
    required this.id,
    required this.label,
    required this.available,
    required this.price,
  });
  final String id;
  final String label;
  final bool available;
  final Money price;
}

final class SeatAvailability {
  SeatAvailability({required this.version, required List<CinemaSeat> seats})
    : seats = List.unmodifiable(seats);
  final String version;
  final List<CinemaSeat> seats;
}

abstract interface class CinemaRepository {
  Future<List<Movie>> movies();
  Future<List<CinemaSession>> sessions(String movieId);
  Future<SeatAvailability> seats(String sessionId);
}
