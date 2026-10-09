import 'dart:typed_data';

import 'statement_file_saver_stub.dart'
    if (dart.library.io) 'statement_file_saver_io.dart'
    if (dart.library.html) 'statement_file_saver_web.dart';

Future<String> saveStatementPdf({
  required Uint8List bytes,
  required String filename,
}) {
  return saveStatementPdfImpl(bytes: bytes, filename: filename);
}
