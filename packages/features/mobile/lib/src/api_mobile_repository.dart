import 'package:checkout/checkout.dart';
import 'package:network_client/network_client.dart';

import 'models.dart';

final class ApiMobileRepository implements MobileRepository {
  ApiMobileRepository(this._client);

  final ApiClient _client;

  @override
  Future<OperatorLookup> operators(String phone) async {
    try {
      final json = await _client.get(
        '/services/operators',
        query: {'phone': phone},
      );
      return OperatorLookup(
        operators: (json['items'] as List)
            .map((Object? value) {
              final row = Map<String, dynamic>.from(value! as Map);
              return MobileOperator(
                id: row['id'] as String,
                name: row['name'] as String,
              );
            })
            .toList(growable: false),
        suggestedId: json['suggestedId'] as String?,
      );
    } on ApiFailure catch (error) {
      throw paymentFailureFromApi(error);
    }
  }
}
