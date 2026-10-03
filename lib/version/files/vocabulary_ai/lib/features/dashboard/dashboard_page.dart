import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/vocabulary_word.dart';

class DashboardPage extends StatelessWidget {
  final List<VocabularyWord> words;
  final VoidCallback onTest;
  final double mastery;
  final int trainingSamples;

  const DashboardPage({
    super.key,
    required this.words,
    required this.onTest,
    required this.mastery,
    required this.trainingSamples,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vocabulary AI-ML',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
              tooltip: 'Start Test',
              onPressed: onTest,
              icon: const Icon(Icons.play_circle)),
          IconButton(
              tooltip: 'Sign out',
              onPressed: () => FirebaseAuth.instance.signOut(),
              icon: const Icon(Icons.logout)),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final pad = constraints.maxWidth < 380 ? 12.0 : 20.0;
          return ListView(
            padding: EdgeInsets.all(pad),
            children: [
              _hero(),
              const SizedBox(height: 20),
              _stats(),
              const SizedBox(height: 16),
              _performanceCard(),
            ],
          );
        },
      ),
    );
  }

  Widget _hero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
            colors: [Color(0xFF2563EB), Color(0xFF87CEEB)]),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome, size: 40),
          const SizedBox(height: 16),
          const Text('AI Vocabulary Hub',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            '${words.length} words • GMAT • IELTS • Academic • Contemporary English',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onTest,
              icon: const Icon(Icons.quiz),
              label: const Text('Start Vocabulary Test',
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stats() {
    final advanced = words
        .where((e) =>
            e.difficultCefrStyle.toUpperCase() == 'C1' ||
            e.difficultCefrStyle.toUpperCase() == 'C2')
        .length;
    final gmat = words.where((e) => e.gmatRelevance.toLowerCase() == 'high').length;
    final ielts = words.where((e) => e.ieltsRelevance.toLowerCase() == 'high').length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cardWidth = width < 700 ? (width - 12) / 2 : 180.0;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _statCard('Total Words', '${words.length}', Icons.menu_book, cardWidth),
            _statCard('Advanced', '$advanced', Icons.trending_up, cardWidth),
            _statCard('GMAT High', '$gmat', Icons.school, cardWidth),
            _statCard('IELTS High', '$ielts', Icons.language, cardWidth),
          ],
        );
      },
    );
  }

  Widget _statCard(String title, String value, IconData icon, double width) {
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 21, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _performanceCard() {
    final m = mastery.clamp(0.0, 100.0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 330) {
              return Column(children: [
                _masteryCircle(m),
                const SizedBox(height: 16),
                _performanceText(),
              ]);
            }
            return Row(children: [
              _masteryCircle(m),
              const SizedBox(width: 16),
              Expanded(child: _performanceText()),
            ]);
          },
        ),
      ),
    );
  }

  Widget _masteryCircle(double m) {
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(value: m / 100, strokeWidth: 7),
          Center(
            child: Text('${m.round()}%',
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _performanceText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Student Performance ML',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        Text('$trainingSamples training samples',
            maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 3),
        const Text('Local adaptive learning model',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.white60, fontSize: 12)),
      ],
    );
  }
}
