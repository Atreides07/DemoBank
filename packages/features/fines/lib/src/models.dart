import 'package:bank_core/bank_core.dart';

final class FineBill {
  const FineBill({
    required this.id,
    required this.title,
    required this.description,
    required this.amount,
    required this.dueDate,
    required this.paid,
    required this.version,
  });

  final String id;
  final String title;
  final String description;
  final Money amount;
  final DateTime dueDate;
  final bool paid;
  final String version;
}

abstract interface class FinesRepository {
  Future<List<FineBill>> search(String document);
}
