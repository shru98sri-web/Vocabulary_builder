import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/assessment_record.dart';
import '../../models/test_models.dart';

class ResultsPage extends StatelessWidget {
  final List<TestAnswer> results;
  final AssessmentRecord record;

  const ResultsPage({super.key, required this.results, required this.record});

  double get accuracy => record.percentage;

  double get mastery {
    final speedFactor = record.averageTime <= 8
        ? 10
        : record.averageTime <= 15
            ? 5
            : -5;
    return max(0, min(100, accuracy + speedFactor)).toDouble();
  }

  String get feedback {
    if (accuracy >= 90) {
      return 'Excellent vocabulary mastery. Continue with advanced and context-heavy questions.';
    }
    if (accuracy >= 75) {
      return 'Strong performance. Focus on subtle meanings, synonyms and contextual usage.';
    }
    if (accuracy >= 60) {
      return 'Developing proficiency. Review incorrect answers and practise active recall.';
    }
    return 'Build your foundation by reviewing definitions, meanings and examples before retesting.';
  }

  @override
  Widget build(BuildContext context) {
    final mistakes = results.where((e) => !e.correct).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Assessment Results')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _scoreCard(),
          const SizedBox(height: 20),
          _analytics(),
          const SizedBox(height: 20),
          _feedbackCard(),
          const SizedBox(height: 20),
          Text('Mistake Analysis', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (mistakes.isEmpty)
            const Card(
                child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('No mistakes. Excellent!')))
          else
            ...mistakes.map(_mistakeCard),
          const SizedBox(height: 20),
          Text('Question Review', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          ...results.map(_reviewCard),
        ],
      ),
    );
  }

  Widget _scoreCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            const Text('YOUR SCORE',
                style: TextStyle(color: Colors.white, letterSpacing: 2)),
            const SizedBox(height: 10),
            Text('${record.score}/${record.total}',
                style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
            Text('${accuracy.toStringAsFixed(1)}%',
                style: const TextStyle(fontSize: 24, color: Color(0xFF60A5FA))),
            const SizedBox(height: 12),
            Chip(label: Text(record.level)),
          ],
        ),
      ),
    );
  }

  Widget _analytics() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _metric('Accuracy', '${accuracy.toStringAsFixed(1)}%', Icons.percent),
        _metric('Avg Time', '${record.averageTime.toStringAsFixed(1)} sec', Icons.timer),
        _metric('AI Mastery', '${mastery.toStringAsFixed(1)}%', Icons.auto_awesome),
        _metric('Mistakes', '${results.where((e) => !e.correct).length}',
            Icons.error_outline),
      ],
    );
  }

  Widget _metric(String title, String value, IconData icon) {
    return SizedBox(
      width: 170,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon),
              const SizedBox(height: 8),
              Text(value,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text(title),
            ],
          ),
        ),
      ),
    );
  }

  Widget _feedbackCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.smart_toy, color: Color(0xFF60A5FA)),
            const SizedBox(width: 12),
            Expanded(child: Text(feedback, style: const TextStyle(height: 1.5))),
          ],
        ),
      ),
    );
  }

  Widget _mistakeCard(TestAnswer answer) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(answer.question.word.word,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Your answer: ${answer.selectedAnswer}',
                style: const TextStyle(color: Colors.redAccent)),
            const SizedBox(height: 5),
            Text('Correct answer: ${answer.question.correctAnswer}',
                style: const TextStyle(color: Colors.greenAccent)),
          ],
        ),
      ),
    );
  }

  Widget _reviewCard(TestAnswer answer) {
    return Card(
      child: ExpansionTile(
        title: Text(answer.question.word.word),
        subtitle: Text(answer.correct
            ? 'Correct • ${answer.seconds}s'
            : 'Incorrect • ${answer.seconds}s'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(answer.question.word.definition),
                const SizedBox(height: 10),
                Text(answer.question.word.example),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
