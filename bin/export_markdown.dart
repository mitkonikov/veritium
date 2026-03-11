import 'dart:io';

import 'package:veritium/cli_export.dart';

void main(List<String> args) async {
  exitCode = await runCliExportCommand(
    args,
    command: 'dart run bin/export_markdown.dart',
  );
}
