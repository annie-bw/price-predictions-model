import 'dart:async';

import 'package:google_fonts/google_fonts.dart';

/// Runs before every test file. Tests have no internet, so don't try to
/// download fonts; text falls back to the default font.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  await testMain();
}
