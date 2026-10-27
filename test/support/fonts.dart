import 'dart:io';

import 'package:flutter/services.dart';

/// Loads Roboto so widget tests measure text like a phone would. The default
/// test font is a wide placeholder that makes layouts look like they overflow.
Future<void> loadRoboto() async {
  final loader = FontLoader('Roboto');
  for (final f in ['Regular', 'Medium', 'Bold', 'Black']) {
    final bytes = await File('test/fonts/Roboto-$f.ttf').readAsBytes();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}
