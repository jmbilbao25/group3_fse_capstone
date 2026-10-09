import 'dart:typed_data';

Future<String> saveStatementPdfImpl({
  required Uint8List bytes,
  required String filename,
}) {
  throw UnsupportedError('Saving a statement PDF is not supported on this platform.');
}
