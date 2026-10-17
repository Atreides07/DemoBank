import 'package:bank_core/bank_core.dart';
import 'package:checkout/checkout.dart';
import 'package:network_client/network_client.dart';

import 'models.dart';

final class ApiFinesRepository implements FinesRepository {
  ApiFinesRepository(this._client);

  final ApiClient _client;

  @override
  Future<List<FineBill>> search(String document) async {
    try {
      final json = await _client.get(
        '/services/fines',
        query: {'document': document},
      );
      return List.unmodifiable(
        (json['items'] as List).map((Object? value) {
          final row = Map<String, dynamic>.from(value! as Map);
          return FineBill(
            id: row['id'] as String,
            title: row['title'] as String,
            description: row['description'] as String,
            amount: Money(
              row['amountMinor'] as int,
              currency: row['currency'] as String,
            ),
            dueDate: DateTime.parse(row['dueDate'] as String),
            paid: row['paid'] as bool,
            version: row['version'] as String,
          );
        }),
      );
    } on ApiFailure catch (error) {
      throw paymentFailureFromApi(error);
    }
  }
}
