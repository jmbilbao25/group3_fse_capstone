import 'dart:io';
import 'dart:typed_data';

Future<String> saveStatementPdfImpl({
  required Uint8List bytes,
  required String filename,
}) async {
  final downloads = _downloadsDirectory();
  final directory = await downloads.exists() ? downloads : Directory.systemTemp;
  final file = File('${directory.path}${Platform.pathSeparator}$filename');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

Directory _downloadsDirectory() {
  final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
  if (home == null || home.isEmpty) return Directory.systemTemp;
  return Directory('$home${Platform.pathSeparator}Downloads');
}
