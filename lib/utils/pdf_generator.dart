import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/work_entry.dart';

class PdfGenerator {
  // Hårdkodad e-postadress för att skicka rapport
  static const String defaultEmail = 'phuong.lindholm@gmail.com';

  // Svenska månader
  static final _monthNames = [
    '', 'Januari', 'Februari', 'Mars', 'April', 'Maj', 'Juni',
    'Juli', 'Augusti', 'September', 'Oktober', 'November', 'December'
  ];

  // Svenska veckodagar
  static final _weekDays = ['Måndag', 'Tisdag', 'Onsdag', 'Torsdag', 'Fredag', 'Lördag', 'Söndag'];

  /// Genererar PDF och skickar via e-post till hårdkodad adress
  static Future<void> generateAndSendEmail(
    List<WorkEntry> entries,
    int year,
    int month,
  ) async {
    // Generera PDF
    final pdfBytes = await _generatePdfBytes(entries, year, month);
    final fileName = 'arbetsrapport_$year-${month.toString().padLeft(2, '0')}.pdf';
    
    // Spara PDF temporärt
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(pdfBytes);
    
    // Beräkna total timmar för ämnesrad
    final totalHours = entries.fold<double>(0, (sum, entry) => sum + entry.hours);
    
    // Skapa e-postämne och brödtext
    final subject = 'Arbetsrapport ${_monthNames[month]} $year';
    final body = '''Hej!

Här kommer arbetsrapporten för ${_monthNames[month]} $year.

Totalt: ${totalHours.toStringAsFixed(1)} timmar
Antal arbetspass: ${entries.length}

Med vänliga hälsningar''';

    // Dela filen - öppnar dela-dialogen med e-post förifylld
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: subject,
      text: body,
    );
  }

  /// Genererar PDF och delar via systemets dela-funktion
  static Future<void> generateAndSharePdf(
    List<WorkEntry> entries,
    int year,
    int month,
  ) async {
    final pdfBytes = await _generatePdfBytes(entries, year, month);
    final fileName = 'arbetsrapport_$year-${month.toString().padLeft(2, '0')}.pdf';
    
    await Printing.sharePdf(
      bytes: Uint8List.fromList(pdfBytes),
      filename: fileName,
    );
  }

  /// Intern funktion som genererar PDF-bytes
  static Future<List<int>> _generatePdfBytes(
    List<WorkEntry> entries,
    int year,
    int month,
  ) async {
    final pdf = pw.Document();
    
    // Beräkna total timmar
    final totalHours = entries.fold<double>(0, (sum, entry) => sum + entry.hours);
    
    // Datumformaterare
    final dateFormat = DateFormat('yyyy-MM-dd');
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          // Rubrik
          pw.Center(
            child: pw.Text(
              'Arbetsrapport',
              style: pw.TextStyle(
                fontSize: 28,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Center(
            child: pw.Text(
              '${_monthNames[month]} $year',
              style: const pw.TextStyle(
                fontSize: 20,
              ),
            ),
          ),
          pw.SizedBox(height: 30),
          
          // Tabell med arbetspass
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(3),
              3: const pw.FlexColumnWidth(1.5),
            },
            children: [
              // Header rad
              pw.TableRow(
                decoration: const pw.BoxDecoration(
                  color: PdfColors.grey300,
                ),
                children: [
                  _buildHeaderCell('Datum'),
                  _buildHeaderCell('Veckodag'),
                  _buildHeaderCell('Kund/Arbetsplats'),
                  _buildHeaderCell('Timmar'),
                ],
              ),
              // Data rader
              ...entries.map((entry) {
                final weekDay = _weekDays[entry.date.weekday - 1];
                return pw.TableRow(
                  children: [
                    _buildDataCell(dateFormat.format(entry.date)),
                    _buildDataCell(weekDay),
                    _buildDataCell(entry.customer),
                    _buildDataCell(entry.hours.toStringAsFixed(1)),
                  ],
                );
              }),
            ],
          ),
          
          pw.SizedBox(height: 20),
          
          // Summering
          pw.Container(
            padding: const pw.EdgeInsets.all(15),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue50,
              border: pw.Border.all(color: PdfColors.blue200),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Totalt antal timmar:',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  '${totalHours.toStringAsFixed(1)} timmar',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue800,
                  ),
                ),
              ],
            ),
          ),
          
          pw.SizedBox(height: 20),
          
          // Antal arbetspass
          pw.Text(
            'Antal arbetspass: ${entries.length}',
            style: const pw.TextStyle(
              fontSize: 14,
              color: PdfColors.grey700,
            ),
          ),
          
          pw.Spacer(),
          
          // Footer
          pw.Divider(color: PdfColors.grey400),
          pw.SizedBox(height: 10),
          pw.Text(
            'Genererad: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
            style: const pw.TextStyle(
              fontSize: 10,
              color: PdfColors.grey600,
            ),
          ),
        ],
      ),
    );
    
    return await pdf.save();
  }
  
  static pw.Widget _buildHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          fontSize: 12,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }
  
  static pw.Widget _buildDataCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 11),
        textAlign: pw.TextAlign.center,
      ),
    );
  }
}
