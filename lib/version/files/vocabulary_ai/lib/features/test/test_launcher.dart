import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/assessment_record.dart';
import '../../models/vocabulary_word.dart';
import 'test_page.dart';

class TestLauncher extends StatelessWidget {
  final List<VocabularyWord> words;
  final Function(AssessmentRecord) onCompleted;

  const TestLauncher({super.key, required this.words, required this.onCompleted});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vocabulary Assessment')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  children: [
                    const Icon(Icons.assignment, size: 70, color: Color(0xFF60A5FA)),
                    const SizedBox(height: 20),
                    const Text('AI Vocabulary Test',
                        style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    Text('${min(words.length, 10)} questions • 10 minutes',
                        style: const TextStyle(color: Colors.white60)),
                    const SizedBox(height: 25),
                    const Text('Question types',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    const Text('• Definition recognition\n'
                        '• Meaning recognition\n'
                        '• Context questions\n'
                        '• Synonym questions\n'
                        '• Adaptive difficulty\n'
                        '• Response-time analysis'),
                    const SizedBox(height: 30),
                    FilledButton.icon(
                      onPressed: words.length < 4
                          ? null
                          : () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TestPage(
                                      words: words, onCompleted: onCompleted),
                                ),
                              ),
                      icon: const Icon(Icons.play_arrow),
                      label: const Padding(
                          padding: EdgeInsets.all(8), child: Text('BEGIN TEST')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
