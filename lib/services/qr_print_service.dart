import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class QrPrintService {
  static Future<void> printOrSaveQr({
    required String code,
    required int points,
    required String companyName,
    String? companyLogoUrl,
  }) async {
    final pdf = pw.Document();
    final brandBytes = (await rootBundle.load('assets/images/vanty_logo.png'))
        .buffer
        .asUint8List();
    final brandImage = pw.MemoryImage(brandBytes);
    pw.MemoryImage? companyImage;
    final logoUrl = companyLogoUrl?.trim() ?? '';
    if (logoUrl.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(logoUrl)).timeout(const Duration(seconds: 8));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          companyImage = pw.MemoryImage(response.bodyBytes);
        }
      } catch (_) {}
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(22),
        build: (context) => pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColor.fromHex('#D9E9DF'), width: 2),
            borderRadius: pw.BorderRadius.circular(18),
          ),
          padding: const pw.EdgeInsets.all(18),
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Image(brandImage, width: 38, height: 38),
                  pw.SizedBox(width: 8),
                  pw.Text('Vanty', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#176B45'))),
                ],
              ),
              pw.Column(
                children: [
                  if (companyImage != null)
                    pw.Container(
                      width: 70,
                      height: 70,
                      decoration: pw.BoxDecoration(shape: pw.BoxShape.circle),
                      child: pw.ClipOval(child: pw.Image(companyImage, fit: pw.BoxFit.cover)),
                    )
                  else
                    pw.Container(
                      width: 70,
                      height: 70,
                      decoration: pw.BoxDecoration(color: PdfColor.fromHex('#EAF4EE'), shape: pw.BoxShape.circle),
                      child: pw.Center(child: pw.Text(companyName.isNotEmpty ? companyName[0].toUpperCase() : 'F', style: pw.TextStyle(fontSize: 30, color: PdfColor.fromHex('#176B45'), fontWeight: pw.FontWeight.bold))),
                    ),
                  pw.SizedBox(height: 10),
                  pw.Text(companyName, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  pw.Text('Escaneie e ganhe pontos!', style: pw.TextStyle(fontSize: 13, color: PdfColor.fromHex('#555555'))),
                ],
              ),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(color: PdfColors.white, border: pw.Border.all(color: PdfColor.fromHex('#E4E4E4')), borderRadius: pw.BorderRadius.circular(12)),
                child: pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: code, width: 180, height: 180),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: pw.BoxDecoration(color: PdfColor.fromHex('#176B45'), borderRadius: pw.BorderRadius.circular(30)),
                child: pw.Text('$points PONTOS', style: pw.TextStyle(fontSize: 20, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
              ),
              pw.Text('Aponte a câmera e acumule pontos no seu programa de fidelidade.', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#555555'))),
              pw.Text('Powered by Vanty', style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#777777'))),
            ],
          ),
        ),
      ),
    );

    await Printing.layoutPdf(
      name: 'QR Vanty - $companyName',
      onLayout: (_) async => Uint8List.fromList(await pdf.save()),
    );
  }
}
