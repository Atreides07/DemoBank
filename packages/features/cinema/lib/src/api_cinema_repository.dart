import 'package:bank_core/bank_core.dart';
import 'package:checkout/checkout.dart';
import 'package:network_client/network_client.dart';

import 'models.dart';

final class ApiCinemaRepository implements CinemaRepository {
  ApiCinemaRepository(this._client);
  final ApiClient _client;

  Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, dynamic> query = const {},
  }) async {
    try {
      return await _client.get(path, query: query);
    } on ApiFailure catch (error) {
      throw paymentFailureFromApi(error);
    }
  }

  @override
  Future<List<Movie>> movies() async {
    final json = await _get('/services/movies');
    return List.unmodifiable(
      (json['items'] as List).map((Object? value) {
        final row = Map<String, dynamic>.from(value! as Map);
        return Movie(
          id: row['id'] as String,
          title: row['title'] as String,
          description: row['description'] as String,
          durationMinutes: row['durationMinutes'] as int,
        );
      }),
    );
  }

  @override
  Future<List<CinemaSession>> sessions(String movieId) async {
    final json = await _get('/services/sessions', query: {'movieId': movieId});
    return List.unmodifiable(
      (json['items'] as List).map((Object? value) {
        final row = Map<String, dynamic>.from(value! as Map);
        return CinemaSession(
          id: row['id'] as String,
          movieId: row['movieId'] as String,
          startsAt: DateTime.parse(row['startsAt'] as String),
          cinema: row['cinema'] as String,
          price: Money(
            row['priceMinor'] as int,
            currency: row['currency'] as String,
          ),
        );
      }),
    );
  }

  @override
  Future<SeatAvailability> seats(String sessionId) async {
    final json = await _get('/services/seats', query: {'sessionId': sessionId});
    return SeatAvailability(
      version: json['version'] as String,
      seats: (json['items'] as List)
          .map((Object? value) {
            final row = Map<String, dynamic>.from(value! as Map);
            return CinemaSeat(
              id: row['id'] as String,
              label: row['label'] as String,
              available: row['available'] as bool,
              price: Money(
                row['priceMinor'] as int,
                currency: row['currency'] as String,
              ),
            );
          })
          .toList(growable: false),
    );
  }
}
