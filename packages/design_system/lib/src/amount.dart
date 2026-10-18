import 'package:flutter/material.dart';

/// Internal amount composition. A fractional group and currency are one child
/// so Flutter cannot wrap between a comma and the remaining cents. Digit
/// groups remain break opportunities whatever the grouping symbol is: spaces
/// (`1 250 000,00 ₽`) or commas (`₽1,250,000.00`). A currency written as a
/// word stays with its neighbouring digits (`UZS 12,750,000`). No value or
/// currency is calculated.
class DsAmountLayout extends StatelessWidget {
  const DsAmountLayout({super.key, required this.text, required this.style});
  final String text;
  final TextStyle? style;

  /// Pieces in display order; each keeps the separator that follows it.
  static List<String> pieces(String text) {
    final result = <String>[];
    for (final word in RegExp(r'\S+\s*').allMatches(text.trim())) {
      result.addAll(word[0]!.split(RegExp(r'(?<=,)(?=\d{3})')));
    }
    bool hasDigit(String piece) => RegExp(r'\d').hasMatch(piece);
    // A trailing currency word joins the last group; a leading one the first.
    if (result.length > 1 && !hasDigit(result.last)) {
      final currency = result.removeLast();
      result[result.length - 1] = '${result.last}$currency';
    }
    if (result.length > 1 && !hasDigit(result.first)) {
      final currency = result.removeAt(0);
      result[0] = '$currency${result.first}';
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final parts = pieces(text);
    return Semantics(
      label: text,
      excludeSemantics: true,
      child: Wrap(
        children: [
          for (final part in parts) Text(part, style: style, softWrap: false),
        ],
      ),
    );
  }
}
