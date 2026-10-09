import 'dart:convert';
import 'dart:typed_data';

import '../models/bank_models.dart';

Uint8List buildStatementPdf({
  required MonthlyStatement statement,
  required String accountHolder,
}) {
  final lines = <_PdfLine>[
    const _PdfLine('Aura Bank (PH)', size: 16, bold: true),
    const _PdfLine('BSP Regulated - Member: PDIC', size: 10),
    const _PdfLine(''),
    const _PdfLine('Statement of Account', size: 14, bold: true),
    _PdfLine(statement.title, size: 12),
    _PdfLine(statement.dateRange, size: 11),
    const _PdfLine(''),
    _PdfLine('Account holder: $accountHolder', size: 11),
    _PdfLine('Total received: ${_php(statement.totalReceived)}', size: 11),
    _PdfLine('Total sent: ${_php(statement.totalSent)}', size: 11),
    _PdfLine('Transactions: ${statement.allCount}', size: 11),
    const _PdfLine(''),
    const _PdfLine('Date                  Counterparty                         Amount', size: 10, bold: true),
    for (final transaction in statement.transactions)
      _PdfLine(
        '${_pad(transaction.displayTime, 22)}${_pad(transaction.counterparty, 36)}${_pdfAmount(transaction.formattedAmount)}',
        size: 10,
      ),
  ];

  return _encodePdf(lines);
}

String statementPdfFilename(String title) {
  final cleaned = title
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '')
      .replaceAll(RegExp(r'\s+'), '_');
  return 'Aura_Statement_$cleaned.pdf';
}

String _php(double amount) {
  final parts = amount.toStringAsFixed(2).split('.');
  final intPart = parts[0].replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]},',
  );
  return 'PHP $intPart.${parts[1]}';
}

String _pdfAmount(String formatted) {
  return formatted.replaceAll('₱', 'PHP ');
}

String _pad(String value, int width) {
  final text = value.length <= width ? value : '${value.substring(0, width - 1)}…';
  return text.padRight(width);
}

class _PdfLine {
  final String text;
  final double size;
  final bool bold;

  const _PdfLine(this.text, {this.size = 11, this.bold = false});
}

Uint8List _encodePdf(List<_PdfLine> lines) {
  const linesPerPage = 40;
  final pages = <List<_PdfLine>>[];
  for (var i = 0; i < lines.length; i += linesPerPage) {
    final end = i + linesPerPage > lines.length ? lines.length : i + linesPerPage;
    pages.add(lines.sublist(i, end));
  }
  if (pages.isEmpty) pages.add(const []);

  final pageCount = pages.length;
  final fontRegularId = 3 + pageCount * 2;
  final fontBoldId = fontRegularId + 1;
  final objects = <String>[];

  objects.add('<< /Type /Catalog /Pages 2 0 R >>');

  final kids = List.generate(pageCount, (index) => '${3 + index * 2} 0 R').join(' ');
  objects.add('<< /Type /Pages /Kids [$kids] /Count $pageCount >>');

  for (var i = 0; i < pageCount; i++) {
    final pageId = 3 + i * 2;
    final contentId = pageId + 1;
    objects.add(
      '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] '
      '/Contents $contentId 0 R /Resources << /Font << '
      '/F1 $fontRegularId 0 R /F2 $fontBoldId 0 R >> >> >>',
    );
    final stream = _pageStream(pages[i]);
    objects.add('<< /Length ${latin1.encode(stream).length} >>\nstream\n$stream\nendstream');
  }

  objects.add('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>');
  objects.add('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>');

  final builder = BytesBuilder(copy: false);
  void write(String value) => builder.add(latin1.encode(value));

  write('%PDF-1.4\n');
  final offsets = <int>[0];
  for (var i = 0; i < objects.length; i++) {
    offsets.add(builder.length);
    final body = objects[i].contains('stream') ? objects[i] : '${objects[i]}\n';
    write('${i + 1} 0 obj\n$body\nendobj\n');
  }

  final xrefAt = builder.length;
  write('xref\n0 ${objects.length + 1}\n');
  write('0000000000 65535 f \n');
  for (var i = 1; i < offsets.length; i++) {
    write('${offsets[i].toString().padLeft(10, '0')} 00000 n \n');
  }
  write('trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\n');
  write('startxref\n$xrefAt\n%%EOF');
  return builder.toBytes();
}

String _pageStream(List<_PdfLine> lines) {
  final buffer = StringBuffer('BT\n50 750 Td\n');
  for (final line in lines) {
    final font = line.bold ? 'F2' : 'F1';
    buffer.write('/$font ${line.size.toStringAsFixed(0)} Tf\n');
    buffer.write('(${_escapePdf(line.text)}) Tj\n');
    buffer.write('0 -16 Td\n');
  }
  buffer.write('ET');
  return buffer.toString();
}

String _escapePdf(String value) {
  final safe = value.replaceAll('…', '...');
  return safe
      .replaceAll('\\', r'\\')
      .replaceAll('(', r'\(')
      .replaceAll(')', r'\)')
      .replaceAll(RegExp(r'[^\x20-\x7E]'), '?');
}
