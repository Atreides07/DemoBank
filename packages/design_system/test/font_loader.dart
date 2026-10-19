import 'dart:io';

import 'package:flutter/services.dart';

/// Widget tests normally use Ahem, whose metrics don't represent the app's
/// Cyrillic labels or money. Load the same offline Roboto shipped by the SDK.
Future<void> loadDsTestFonts() async {
  var directory = File(Platform.resolvedExecutable).parent;
  Directory? fonts;
  while (directory.parent.path != directory.path) {
    final candidate = Directory(
      '${directory.path}/bin/cache/artifacts/material_fonts',
    );
    if (candidate.existsSync()) {
      fonts = candidate;
      break;
    }
    directory = directory.parent;
  }
  if (fonts == null) throw StateError('Flutter SDK material_fonts not found');
  final roboto = FontLoader('packages/design_system/DsSans');
  for (final weight in ['Regular', 'Medium', 'Bold']) {
    roboto.addFont(
      File('${fonts.path}/Roboto-$weight.ttf')
          .readAsBytes()
          .then((bytes) => ByteData.sublistView(Uint8List.fromList(bytes))),
    );
  }
  await roboto.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(
      File('${fonts.path}/MaterialIcons-Regular.otf')
          .readAsBytes()
          .then((bytes) => ByteData.sublistView(Uint8List.fromList(bytes))),
    );
  await icons.load();
}
