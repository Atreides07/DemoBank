import 'generated/app_localizations.g.dart';

/// Spending categories of the client taxonomy, in display order.
const spendingCategories = [
  'groceries',
  'transport',
  'dining',
  'shopping',
  'utilities',
  'health',
  'entertainment',
  'other',
];

extension AppLocalizationsLabels on AppLocalizations {
  /// Name of a known category in the interface language. A category this
  /// version does not know keeps the name the server sent, if any.
  String category(String id, [String? serverName]) =>
      spendingCategories.contains(id)
      ? categoryName(id)
      : serverName ?? categoryName('other');
}
