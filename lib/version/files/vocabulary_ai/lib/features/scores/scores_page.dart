import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/formatters.dart';
import '../../models/assessment_record.dart';
import '../../services/report_service.dart';

class ScoresPage extends StatefulWidget {
  final List<AssessmentRecord> history;
  const ScoresPage({super.key, required this.history});

  @override
  State<ScoresPage> createState() => _ScoresPageState();
}

class _ScoresPageState extends State<ScoresPage> {
  final _email = TextEditingController();
  bool _busy = false;

  String get _student => FirebaseAuth.instance.currentUser?.email ?? 'Student';

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _run(Future<String?> Function() task) async {
    if (widget.history.isEmpty) {
      _toast('No assessments to export yet.');
      return;
    }
    setState(() => _busy = true);
    try {
      final msg = await task();
      if (msg != null) _toast(msg);
    } catch (e) {
      _toast('Failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _downloadPdf() => _run(() async {
        await ReportService.download(
            await ReportService.buildPdf(widget.history, _student));
        return null;
      });

  Future<void> _uploadSheet() => _run(() async {
        await ReportService.uploadToDrive(widget.history, _student);
        return null;
      });

  Future<void> _sendEmail() {
    final to = _email.text.trim();
    if (!RegExp(r'^[^@\s,;<>]+@[^@\s,;<>]+\.[^@\s,;<>]+$').hasMatch(to)) {
      _toast('Enter a valid email address.');
      return Future.value();
    }
    return _run(() async {
      await ReportService.emailPdf(
          to, await ReportService.buildPdf(widget.history, _student));
      return '$to copied. Paste it in the To field if Gmail left it empty.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.history;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assessment Scores'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Signed in as $_student',
                      style: const TextStyle(color: Colors.white60)),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _busy ? null : _downloadPdf,
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Download PDF'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _uploadSheet,
                    icon: const Icon(Icons.cloud_upload),
                    label: const Text('Upload sheet to Google Drive'),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Send PDF to email',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _sendEmail,
                    icon: const Icon(Icons.send),
                    label: const Text('Email PDF (choose Gmail)'),
                  ),
                  if (_busy) ...[
                    const SizedBox(height: 14),
                    const LinearProgressIndicator(),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('${h.length} assessments',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final r in h)
            Card(
              child: ListTile(
                leading: CircleAvatar(child: Text('${r.score}')),
                title: Text('${r.percentage.toStringAsFixed(1)}% • ${r.level}'),
                subtitle: Text(
                    '${formatDate(r.date)} • Avg ${r.averageTime.toStringAsFixed(1)}s'),
                trailing: r.voiceScore > 0 ? Text('Voice ${r.voiceScore}') : null,
              ),
            ),
        ],
      ),
    );
  }
}
