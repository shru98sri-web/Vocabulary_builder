import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../etl/report_etl.dart';
import '../models/assessment_record.dart';

/// Delivery layer: report data comes from ReportEtl, this class hands it to
/// the OS (save/share, Drive share sheet, Gmail share sheet).
class ReportService {
  static Future<Uint8List> buildPdf(
          List<AssessmentRecord> history, String student) =>
      ReportEtl.pdf(history, student);

  static Future<String> buildCsv(
          List<AssessmentRecord> history, String student) =>
      ReportEtl.csv(history, student);

  static Future<String> _saveTemp(String name, List<int> bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  static Future<void> download(Uint8List pdf) =>
      Printing.sharePdf(bytes: pdf, filename: 'vocabulary_report.pdf');

  /// Share pop-up with the score sheet; choose "Drive" and pick the account.
  static Future<void> uploadToDrive(
      List<AssessmentRecord> history, String student) async {
    final csv = await buildCsv(history, student);
    final path =
        await _saveTemp('Vocabulary_Assessment_Scores.csv', utf8.encode(csv));
    await Share.shareXFiles(
      [XFile(path, mimeType: 'text/csv')],
      subject: 'Vocabulary Assessment Scores',
    );
  }

  /// Share pop-up with the PDF attached; choose Gmail for a compose window.
  /// The typed address is copied to the clipboard to paste into "To".
  static Future<void> emailPdf(String to, Uint8List pdf) async {
    if (to.contains(RegExp(r'[\r\n,;<>]'))) throw 'Invalid email address.';
    await Clipboard.setData(ClipboardData(text: to));
    final path = await _saveTemp('vocabulary_report.pdf', pdf);
    await Share.shareXFiles(
      [XFile(path, mimeType: 'application/pdf')],
      subject: 'Vocabulary Assessment Report',
      text: 'Please find the vocabulary assessment report attached.\n\nTo: $to',
    );
  }
}
