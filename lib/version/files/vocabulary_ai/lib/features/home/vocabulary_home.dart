import 'package:flutter/material.dart';

import '../../etl/student_etl.dart';
import '../../etl/vocabulary_etl.dart';
import '../../ml/performance_ml.dart';
import '../../models/assessment_record.dart';
import '../../models/vocabulary_word.dart';
import '../dashboard/dashboard_page.dart';
import '../notes/notes_page.dart';
import '../scores/scores_page.dart';
import '../test/test_launcher.dart';
import '../voice/voice_tutor_page.dart';

class VocabularyHome extends StatefulWidget {
  const VocabularyHome({super.key});

  @override
  State<VocabularyHome> createState() => _VocabularyHomeState();
}

class _VocabularyHomeState extends State<VocabularyHome> {
  int selectedIndex = 0;

  List<VocabularyWord> words = [];
  bool loading = true;
  String? error;

  final List<AssessmentRecord> history = [];
  StudentPerformanceML studentML = StudentPerformanceML();
  double currentMastery = 0;
  int totalTrainingSamples = 0;

  @override
  void initState() {
    super.initState();
    loadVocabulary();
    loadStudentData();
  }

  /// ETL: storage -> analytics
  Future<void> loadStudentData() async {
    try {
      final data = await StudentEtl.load();
      if (!mounted) return;
      setState(() {
        history
          ..clear()
          ..addAll(data.history);
        studentML = data.model;
        totalTrainingSamples = data.sampleCount;
        currentMastery = data.mastery;
      });
    } catch (_) {}
  }

  /// ETL: assets/vocab.json -> clean vocabulary
  Future<void> loadVocabulary() async {
    try {
      final batch = await VocabularyEtl.run();
      if (!mounted) return;
      setState(() {
        words = batch.words;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = e.toString();
      });
    }
  }

  /// ETL: finished assessment -> training sample -> storage + ML
  Future<void> addHistory(AssessmentRecord record) async {
    final mastery = await AssessmentIngestEtl.run(record, studentML);
    if (!mounted) return;
    setState(() {
      history.insert(0, record);
      if (history.length > 100) history.removeLast();
      totalTrainingSamples++;
      currentMastery = mastery;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Vocabulary AI')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Unable to load vocabulary.json\n\n$error',
                textAlign: TextAlign.center),
          ),
        ),
      );
    }

    final pages = [
      DashboardPage(
        words: words,
        mastery: currentMastery,
        trainingSamples: totalTrainingSamples,
        onTest: () => setState(() => selectedIndex = 1),
      ),
      TestLauncher(words: words, onCompleted: addHistory),
      VoiceTutorPage(words: words, onCompleted: addHistory),
      NotesPage(words: words),
      ScoresPage(history: history),
    ];

    const destinations = [
      NavigationRailDestination(
        icon: Icon(Icons.dashboard_outlined),
        selectedIcon: Icon(Icons.dashboard),
        label: Text('Dashboard'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.quiz_outlined),
        selectedIcon: Icon(Icons.quiz),
        label: Text('Test'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.mic_none),
        selectedIcon: Icon(Icons.mic),
        label: Text('Voice'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.sticky_note_2_outlined),
        selectedIcon: Icon(Icons.sticky_note_2),
        label: Text('Notes'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.download_outlined),
        selectedIcon: Icon(Icons.download),
        label: Text('Scores'),
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: (i) => setState(() => selectedIndex = i),
              labelType: NavigationRailLabelType.all,
              destinations: destinations,
            ),
            const VerticalDivider(width: 1),
            Expanded(child: pages[selectedIndex]),
          ],
        ),
      ),
    );
  }
}
