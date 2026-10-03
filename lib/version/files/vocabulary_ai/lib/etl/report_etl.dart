import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/formatters.dart';
import '../models/assessment_record.dart';
import 'etl_pipeline.dart';

class ReportDataset {
  final String student;
  final DateTime generatedAt;
  final List<AssessmentRecord> records;
  final double average;
  const ReportDataset({
    required this.student,
    required this.generatedAt,
    required this.records,
    required this.average,
  });

  static const pdfHeaders = [
    'Date', 'Score', '%', 'Avg time (s)', 'Voice', 'Level'
  ];

  List<List<String>> get pdfRows => [
        for (final r in records)
          [
            formatDate(r.date),
            '${r.score}/${r.total}',
            r.percentage.toStringAsFixed(1),
            r.averageTime.toStringAsFixed(1),
            '${r.voiceScore}',
            r.level,
          ]
      ];
}

/// EXTRACT: the in-memory assessment history.
class HistoryExtractor implements Extractor<List<AssessmentRecord>> {
  final List<AssessmentRecord> history;
  const HistoryExtractor(this.history);

  @override
  Future<List<AssessmentRecord>> extract() async => List.of(history);
}

/// TRANSFORM: records -> report dataset with summary statistics.
class ReportTransformer
    implements Transformer<List<AssessmentRecord>, ReportDataset> {
  final String student;
  const ReportTransformer(this.student);

  @override
  ReportDataset transform(List<AssessmentRecord> records) {
    final avg = records.isEmpty
        ? 0.0
        : records.map((e) => e.percentage).reduce((a, b) => a + b) /
            records.length;
    return ReportDataset(
      student: student,
      generatedAt: DateTime.now(),
      records: records,
      average: avg,
    );
  }
}

/// LOAD (PDF): dataset -> PDF bytes.
class PdfReportLoader implements Loader<ReportDataset, Uint8List> {
  @override
  Future<Uint8List> load(ReportDataset d) async {
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (_) => [
        pw.Text('Vocabulary Assessment Report',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Text('Student: ${d.student}'),
        pw.Text('Generated: ${formatDate(d.generatedAt)}'),
        pw.Text('Assessments: ${d.records.length}   '
            'Average: ${d.average.toStringAsFixed(1)}%'),
        pw.SizedBox(height: 16),
        pw.TableHelper.fromTextArray(
          headers: ReportDataset.pdfHeaders,
          data: d.pdfRows,
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.blue100),
          cellAlignment: pw.Alignment.centerLeft,
        ),
      ],
    ));
    return doc.save();
  }
}

/// LOAD (CSV): dataset -> CSV text (uploaded to Drive as the score sheet).
class CsvReportLoader implements Loader<ReportDataset, String> {
  String _q(String v) => '"${v.replaceAll('"', '""')}"';

  @override
  Future<String> load(ReportDataset d) async {
    final rows = <String>['Date,Score,Total,Percentage,AvgTimeSec,Voice,Level'];
    for (final r in d.records) {
      rows.add([
        formatDate(r.date),
        r.score,
        r.total,
        r.percentage.toStringAsFixed(1),
        r.averageTime.toStringAsFixed(1),
        r.voiceScore,
        _q(r.level),
      ].join(','));
    }
    return rows.join('\n');
  }
}

class ReportEtl {
  static Future<Uint8List> pdf(List<AssessmentRecord> h, String student) =>
      EtlPipeline<List<AssessmentRecord>, ReportDataset, Uint8List>(
        name: 'report-pdf',
        extractor: HistoryExtractor(h),
        transformer: ReportTransformer(student),
        loader: PdfReportLoader(),
      ).run();

  static Future<String> csv(List<AssessmentRecord> h, String student) =>
      EtlPipeline<List<AssessmentRecord>, ReportDataset, String>(
        name: 'report-csv',
        extractor: HistoryExtractor(h),
        transformer: ReportTransformer(student),
        loader: CsvReportLoader(),
      ).run();
}
