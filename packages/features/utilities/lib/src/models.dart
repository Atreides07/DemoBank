import 'package:bank_core/bank_core.dart';

final class UtilityBill {
  const UtilityBill({
    required this.id,
    required this.title,
    required this.provider,
    required this.description,
    required this.amount,
    required this.dueDate,
    required this.paid,
    required this.version,
  });

  final String id;
  final String title;
  final String provider;
  final String description;
  final Money amount;
  final DateTime dueDate;
  final bool paid;
  final String version;
}

abstract interface class UtilitiesRepository {
  Future<List<UtilityBill>> bills(String account);
}
