import 'dart:io';

import 'package:veritium/cli_hash_export.dart';

void main(List<String> args) async {
  exitCode = await runCliHashExportCommand(
    args,
    command: 'dart run bin/export_empty_corrected_hashes.dart',
  );
}
