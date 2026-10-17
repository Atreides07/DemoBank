import 'package:flutter/material.dart';

/// Internal amount composition. A fractional group and currency are one child
/// so Flutter cannot wrap between a comma and the remaining cents. Thousands
/// groups remain valid break opportunities. No value or currency is calculated.
class DsAmountLayout extends StatelessWidget {
  const DsAmountLayout({super.key, required this.text, required this.style});
  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final groups = text.split(RegExp(r'[\s\u00a0\u202f]+'));
    if (groups.length > 1 && !RegExp(r'\d').hasMatch(groups.last)) {
      final currency = groups.removeLast();
      groups[groups.length - 1] = '${groups.last} $currency';
    }
    return Semantics(
      label: text,
      excludeSemantics: true,
      child: Wrap(
        children: [
          for (var index = 0; index < groups.length; index++)
            Text(
              '${groups[index]}${index == groups.length - 1 ? '' : ' '}',
              style: style,
              softWrap: false,
            ),
        ],
      ),
    );
  }
}
