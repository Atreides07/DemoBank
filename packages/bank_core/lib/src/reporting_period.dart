import 'ledger.dart';

/// Reporting boundaries are Moscow midnight, independent of the device timezone.
abstract final class ReportingPeriod {
  static DateTime midnight(int year, int month, int day) =>
      DateTime.utc(year, month, day).subtract(const Duration(hours: 3));
  static LedgerFilter month(DateTime now, {int offset = 0}) => LedgerFilter(
    from: midnight(now.year, now.month + offset, 1),
    to: offset == 0
        ? midnight(now.year, now.month, now.day + 1)
        : midnight(now.year, now.month + offset + 1, 1),
    kind: EntryKind.expense,
  );
  static LedgerFilter year(DateTime now) => LedgerFilter(
    from: midnight(now.year, 1, 1),
    to: midnight(now.year, now.month, now.day + 1),
    kind: EntryKind.expense,
  );
  static LedgerFilter custom(DateTime start, DateTime inclusiveEnd) =>
      LedgerFilter(
        from: midnight(start.year, start.month, start.day),
        to: midnight(
          inclusiveEnd.year,
          inclusiveEnd.month,
          inclusiveEnd.day + 1,
        ),
        kind: EntryKind.expense,
      );
}
