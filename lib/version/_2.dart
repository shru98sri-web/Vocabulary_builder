import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const VocabularyAIApp());
}

// ============================================================
// APP
// ============================================================

class VocabularyAIApp extends StatelessWidget {
  const VocabularyAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vocabulary AI-ML App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF08111F),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.dark,
        ),
        fontFamily: 'Roboto',
      ),
      home: const AuthGate(child: VocabularyHome()),
    );
  }
}

// ============================================================
// VOCABULARY MODEL
// ============================================================

class VocabularyWord {
  final dynamic id;
  final String word;
  final String letter;
  final String difficultCefrStyle;
  final String difficulty;
  final String partsOfSpeech;
  final String definition;
  final String meaning;
  final List<String> synonyms;
  final String example;
  final String gmatRelevance;
  final String ieltsRelevance;
  final String usage;
  final String currentStatus;
  final String yearFocus;
  final List<String> sourceReference;
  final String sourceNote;

  VocabularyWord({
    required this.id,
    required this.word,
    required this.letter,
    required this.difficultCefrStyle,
    required this.difficulty,
    required this.partsOfSpeech,
    required this.definition,
    required this.meaning,
    required this.synonyms,
    required this.example,
    required this.gmatRelevance,
    required this.ieltsRelevance,
    required this.usage,
    required this.currentStatus,
    required this.yearFocus,
    required this.sourceReference,
    required this.sourceNote,
  });

  factory VocabularyWord.fromJson(Map<String, dynamic> json) {
    return VocabularyWord(
      id: json['id'],
      word: '${json['word'] ?? ''}',
      letter: '${json['letter'] ?? ''}',
      difficultCefrStyle:
      '${json['difficult_cefr_style'] ?? json['difficulty_cefr_style'] ?? ''}',
      difficulty: '${json['difficulty'] ?? ''}',
      partsOfSpeech:
      '${json['parts_of_speech'] ?? json['part_of_speech'] ?? ''}',
      definition: '${json['definition'] ?? ''}',
      meaning: '${json['meaning'] ?? ''}',
      synonyms: _stringList(json['synonyms']),
      example: '${json['example'] ?? ''}',
      gmatRelevance:
      '${json['gmat_relavance'] ?? json['gmat_relevance'] ?? ''}',
      ieltsRelevance:
      '${json['ielts_relavance'] ?? json['ielts_relevance'] ?? ''}',
      usage: '${json['usage'] ?? ''}',
      currentStatus: '${json['current_status'] ?? ''}',
      yearFocus: '${json['year_focus'] ?? ''}',
      sourceReference: _stringList(json['source_reference']),
      sourceNote: '${json['source_note'] ?? ''}',
    );
  }

  static List<String> _stringList(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.map((e) => '$e').toList();
    if (value is String && value.trim().isNotEmpty) return [value];
    return [];
  }
}

// ============================================================
// TEST MODELS
// ============================================================

enum QuestionType { definition, meaning, example, synonym }

class TestQuestion {
  final VocabularyWord word;
  final QuestionType type;
  final List<String> options;
  final String correctAnswer;

  TestQuestion({
    required this.word,
    required this.type,
    required this.options,
    required this.correctAnswer,
  });

  String get questionText {
    switch (type) {
      case QuestionType.definition:
        return 'Which word matches this definition?\n\n${word.definition}';
      case QuestionType.meaning:
        return 'What is the meaning of "${word.word}"?';
      case QuestionType.example:
        return 'Which word best completes this context?\n\n"${word.example}"';
      case QuestionType.synonym:
        return 'Which option is closest in meaning to "${word.word}"?';
    }
  }
}

class TestAnswer {
  final TestQuestion question;
  final String selectedAnswer;
  final bool correct;
  final int seconds;

  TestAnswer({
    required this.question,
    required this.selectedAnswer,
    required this.correct,
    required this.seconds,
  });
}

class AssessmentRecord {
  final DateTime date;
  final int score;
  final int total;
  final double averageTime;
  final int voiceScore;
  final String level;

  AssessmentRecord({
    required this.date,
    required this.score,
    required this.total,
    required this.averageTime,
    required this.voiceScore,
    required this.level,
  });

  double get percentage => total == 0 ? 0 : score / total * 100;

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'score': score,
    'total': total,
    'averageTime': averageTime,
    'voiceScore': voiceScore,
    'level': level,
  };

  factory AssessmentRecord.fromJson(Map<String, dynamic> json) {
    double n(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
    int i(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
    return AssessmentRecord(
      date: DateTime.tryParse('${json['date']}') ?? DateTime.now(),
      score: i(json['score']),
      total: i(json['total']),
      averageTime: n(json['averageTime']),
      voiceScore: i(json['voiceScore']),
      level: '${json['level'] ?? 'Developing'}',
    );
  }
}

// ============================================================
// PERSISTENT STUDENT PERFORMANCE + LOCAL ML
// ============================================================

class PerformanceSample {
  final double accuracy;
  final double speed;
  final double voiceScore;
  final double target;

  PerformanceSample({
    required this.accuracy,
    required this.speed,
    required this.voiceScore,
    required this.target,
  });

  Map<String, dynamic> toJson() => {
    'accuracy': accuracy,
    'speed': speed,
    'voiceScore': voiceScore,
    'target': target,
  };

  factory PerformanceSample.fromJson(Map<String, dynamic> json) {
    double n(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
    return PerformanceSample(
      accuracy: n(json['accuracy']).clamp(0.0, 1.0).toDouble(),
      speed: n(json['speed']).clamp(0.0, 1.0).toDouble(),
      voiceScore: n(json['voiceScore']).clamp(0.0, 1.0).toDouble(),
      target: n(json['target']).clamp(0.0, 1.0).toDouble(),
    );
  }
}

class StudentPerformanceML {
  double bias = 0;
  double accuracyWeight = 1.4;
  double speedWeight = .35;
  double voiceWeight = .55;
  int trainingSteps = 0;

  double _sigmoid(double x) {
    if (x < -30) return 0;
    if (x > 30) return 1;
    return 1 / (1 + exp(-x));
  }

  double _speedFeature(double averageTime) {
    if (averageTime <= 0) return 1;
    return 1 / (1 + averageTime / 15);
  }

  double predict({
    required double accuracy,
    required double averageTime,
    required double voiceScore,
  }) {
    final a = (accuracy / 100).clamp(0.0, 1.0);
    final s = _speedFeature(averageTime);
    final v = (voiceScore / 100).clamp(0.0, 1.0);
    final z = bias + accuracyWeight * a + speedWeight * s + voiceWeight * v;
    return (_sigmoid(z) * 100).clamp(0.0, 100.0).toDouble();
  }

  void train(PerformanceSample sample) {
    const learningRate = .08;
    final prediction = _sigmoid(
      bias +
          accuracyWeight * sample.accuracy +
          speedWeight * sample.speed +
          voiceWeight * sample.voiceScore,
    );
    final error = sample.target - prediction;
    bias += learningRate * error;
    accuracyWeight += learningRate * error * sample.accuracy;
    speedWeight += learningRate * error * sample.speed;
    voiceWeight += learningRate * error * sample.voiceScore;
    trainingSteps++;
  }

  void trainMany(List<PerformanceSample> samples) {
    for (final sample in samples) {
      train(sample);
    }
  }

  Map<String, dynamic> toJson() => {
    'bias': bias,
    'accuracyWeight': accuracyWeight,
    'speedWeight': speedWeight,
    'voiceWeight': voiceWeight,
    'trainingSteps': trainingSteps,
  };

  void loadFromJson(Map<String, dynamic> json) {
    double n(dynamic v, double fallback) =>
        v is num ? v.toDouble() : double.tryParse('$v') ?? fallback;
    bias = n(json['bias'], bias);
    accuracyWeight = n(json['accuracyWeight'], accuracyWeight);
    speedWeight = n(json['speedWeight'], speedWeight);
    voiceWeight = n(json['voiceWeight'], voiceWeight);
    trainingSteps = (json['trainingSteps'] is num)
        ? (json['trainingSteps'] as num).toInt()
        : int.tryParse('${json['trainingSteps']}') ?? trainingSteps;
  }
}

/// Storage keys are prefixed with the signed-in user's uid, so students
/// sharing one device do not see each other's data.
class StudentStorage {
  static String _k(String base) =>
      '${base}_${FirebaseAuth.instance.currentUser?.uid ?? 'anon'}';

  static String get _historyKey => _k('vocabulary_assessment_history');
  static String get _samplesKey => _k('student_performance_samples');
  static String get _modelKey => _k('student_ml_model');

  static Future<void> saveAssessment(AssessmentRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await loadAssessments();
    list.insert(0, record);
    final trimmed = list.take(100).map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_historyKey, trimmed);
  }

  static Future<List<AssessmentRecord>> loadAssessments() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_historyKey) ?? [];
    final result = <AssessmentRecord>[];
    for (final item in raw) {
      try {
        result.add(AssessmentRecord.fromJson(
            Map<String, dynamic>.from(jsonDecode(item))));
      } catch (_) {}
    }
    result.sort((a, b) => b.date.compareTo(a.date));
    return result;
  }

  static Future<void> savePerformanceSample(PerformanceSample sample) async {
    final prefs = await SharedPreferences.getInstance();
    final samples = await loadPerformanceSamples();
    samples.add(sample);
    final trimmed =
    samples.length > 500 ? samples.sublist(samples.length - 500) : samples;
    await prefs.setStringList(
        _samplesKey, trimmed.map((e) => jsonEncode(e.toJson())).toList());
  }

  static Future<List<PerformanceSample>> loadPerformanceSamples() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_samplesKey) ?? [];
    final result = <PerformanceSample>[];
    for (final item in raw) {
      try {
        result.add(PerformanceSample.fromJson(
            Map<String, dynamic>.from(jsonDecode(item))));
      } catch (_) {}
    }
    return result;
  }

  static Future<void> saveModel(StudentPerformanceML model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modelKey, jsonEncode(model.toJson()));
  }

  static Future<StudentPerformanceML> loadModel() async {
    final prefs = await SharedPreferences.getInstance();
    final model = StudentPerformanceML();
    final raw = prefs.getString(_modelKey);
    if (raw != null) {
      try {
        model.loadFromJson(Map<String, dynamic>.from(jsonDecode(raw)));
      } catch (_) {}
    }
    return model;
  }

  static Future<void> clearStudentData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
    await prefs.remove(_samplesKey);
    await prefs.remove(_modelKey);
  }
}

// ============================================================
// HOME
// ============================================================

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

  Future<void> loadStudentData() async {
    try {
      final savedHistory = await StudentStorage.loadAssessments();
      final samples = await StudentStorage.loadPerformanceSamples();
      final model = await StudentStorage.loadModel();
      if (model.trainingSteps == 0 && samples.isNotEmpty) {
        model.trainMany(samples);
        await StudentStorage.saveModel(model);
      }
      final latest = savedHistory.isNotEmpty ? savedHistory.first : null;
      if (!mounted) return;
      setState(() {
        history
          ..clear()
          ..addAll(savedHistory);
        studentML = model;
        totalTrainingSamples = samples.length;
        currentMastery = latest == null
            ? 0
            : model.predict(
          accuracy: latest.percentage,
          averageTime: latest.averageTime,
          voiceScore: latest.voiceScore.toDouble(),
        );
      });
    } catch (_) {}
  }

  Future<void> loadVocabulary() async {
    try {
      final raw = await rootBundle.loadString('assets/vocab.json');
      final decoded = jsonDecode(raw);
      List<dynamic> list = [];
      if (decoded is Map<String, dynamic>) {
        if (decoded['words'] is List) list = decoded['words'];
      } else if (decoded is List) {
        list = decoded;
      }
      final loaded = list
          .whereType<Map>()
          .map((item) => VocabularyWord.fromJson(Map<String, dynamic>.from(item)))
          .where((item) => item.word.trim().isNotEmpty)
          .toList();
      if (!mounted) return;
      setState(() {
        words = loaded;
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

  Future<void> addHistory(AssessmentRecord record) async {
    final accuracy = (record.percentage / 100).clamp(0.0, 1.0).toDouble();
    final speed = record.averageTime <= 0
        ? 1.0
        : (1 / (1 + record.averageTime / 15)).clamp(0.0, 1.0).toDouble();
    final voice = (record.voiceScore / 100).clamp(0.0, 1.0).toDouble();
    final target = ((accuracy * .65) + (speed * .15) + (voice * .20))
        .clamp(0.0, 1.0)
        .toDouble();
    final sample = PerformanceSample(
        accuracy: accuracy, speed: speed, voiceScore: voice, target: target);
    studentML.train(sample);
    await StudentStorage.saveAssessment(record);
    await StudentStorage.savePerformanceSample(sample);
    await StudentStorage.saveModel(studentML);
    if (!mounted) return;
    setState(() {
      history.insert(0, record);
      if (history.length > 100) history.removeLast();
      totalTrainingSamples++;
      currentMastery = studentML.predict(
        accuracy: record.percentage,
        averageTime: record.averageTime,
        voiceScore: record.voiceScore.toDouble(),
      );
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

// ============================================================
// DASHBOARD (word list moved to Notes)
// ============================================================

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

// ============================================================
// TEST LAUNCHER
// ============================================================

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

// ============================================================
// TEST PAGE
// ============================================================

class TestPage extends StatefulWidget {
  final List<VocabularyWord> words;
  final Function(AssessmentRecord) onCompleted;

  const TestPage({super.key, required this.words, required this.onCompleted});

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  final Random random = Random();
  late List<TestQuestion> questions;
  final Map<int, String> answers = {};
  final Map<int, int> questionTimes = {};

  int currentIndex = 0;
  int remainingSeconds = 600;
  int questionStartedAt = 0;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    questions = _generateQuestions();
    questionStartedAt = DateTime.now().millisecondsSinceEpoch;
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => remainingSeconds--);
      if (remainingSeconds <= 0) _submit();
    });
  }

  List<TestQuestion> _generateQuestions() {
    final pool = List<VocabularyWord>.from(widget.words)..shuffle(random);
    final selected = pool.take(min(10, pool.length)).toList();
    final result = <TestQuestion>[];

    for (final word in selected) {
      final type = QuestionType.values[random.nextInt(QuestionType.values.length)];
      List<String> options;
      String correct;

      switch (type) {
        case QuestionType.definition:
          options = _makeOptions(word, (w) => w.word);
          correct = word.word;
        case QuestionType.meaning:
          options = _makeOptions(word, (w) => w.meaning);
          correct = word.meaning;
        case QuestionType.example:
          options = _makeOptions(word, (w) => w.word);
          correct = word.word;
        case QuestionType.synonym:
          String pick(VocabularyWord w) =>
              w.synonyms.isNotEmpty ? w.synonyms.first : w.word;
          options = _makeOptions(word, pick);
          correct = pick(word);
      }

      result.add(TestQuestion(
          word: word, type: type, options: options, correctAnswer: correct));
    }
    return result;
  }

  List<String> _makeOptions(
      VocabularyWord correct, String Function(VocabularyWord) selector) {
    final candidates = widget.words.where((w) => w.word != correct.word).toList()
      ..shuffle(random);
    final values = <String>[selector(correct)];
    for (final candidate in candidates) {
      final value = selector(candidate);
      if (value.trim().isEmpty) continue;
      if (!values.contains(value)) values.add(value);
      if (values.length >= 4) break;
    }
    while (values.length < 4) {
      values.add('Not enough information');
    }
    values.shuffle(random);
    return values;
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void _select(String answer) {
    final elapsed =
    ((DateTime.now().millisecondsSinceEpoch - questionStartedAt) / 1000)
        .round();
    answers[currentIndex] = answer;
    questionTimes[currentIndex] = elapsed;

    if (currentIndex == questions.length - 1) {
      _submit();
    } else {
      setState(() {
        currentIndex++;
        questionStartedAt = DateTime.now().millisecondsSinceEpoch;
      });
    }
  }

  void _submit() {
    timer?.cancel();
    final results = <TestAnswer>[];

    for (int i = 0; i < questions.length; i++) {
      final q = questions[i];
      final selected = answers[i] ?? 'Not answered';
      results.add(TestAnswer(
        question: q,
        selectedAnswer: selected,
        correct: selected == q.correctAnswer,
        seconds: questionTimes[i] ?? 0,
      ));
    }

    final score = results.where((e) => e.correct).length;
    final averageTime = results.isEmpty
        ? 0
        : results.map((e) => e.seconds).reduce((a, b) => a + b) / results.length;
    final percentage = questions.isEmpty ? 0 : score / questions.length * 100;

    final record = AssessmentRecord(
      date: DateTime.now(),
      score: score,
      total: questions.length,
      averageTime: averageTime.toDouble(),
      voiceScore: 0,
      level: _level(percentage),
    );

    widget.onCompleted(record);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => ResultsPage(results: results, record: record)),
    );
  }

  String _level(num percentage) {
    if (percentage >= 90) return 'Advanced';
    if (percentage >= 75) return 'Upper Intermediate';
    if (percentage >= 60) return 'Intermediate';
    if (percentage >= 40) return 'Developing';
    return 'Foundation';
  }

  @override
  Widget build(BuildContext context) {
    if (questions.isEmpty) {
      return const Scaffold(
          body: Center(child: Text('Not enough vocabulary entries.')));
    }

    final question = questions[currentIndex];
    final minutes = (max(0, remainingSeconds) ~/ 60).toString().padLeft(2, '0');
    final seconds = (max(0, remainingSeconds) % 60).toString().padLeft(2, '0');

    return Scaffold(
      appBar: AppBar(
        title: Text('Question ${currentIndex + 1}/${questions.length}'),
        actions: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Chip(
                avatar: const Icon(Icons.timer, size: 18),
                label: Text('$minutes:$seconds')),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          LinearProgressIndicator(value: (currentIndex + 1) / questions.length),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(question.type.name.toUpperCase(),
                      style: const TextStyle(
                          color: Color(0xFF60A5FA), fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  Text(question.questionText,
                      style: const TextStyle(fontSize: 19, height: 1.5)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          ...question.options.map((option) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _optionButton(option),
          )),
        ],
      ),
    );
  }

  Widget _optionButton(String option) {
    return OutlinedButton(
      onPressed: () => _select(option),
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.all(18),
        minimumSize: const Size(double.infinity, 60),
      ),
      child: Text(option, style: const TextStyle(fontSize: 15)),
    );
  }
}

// ============================================================
// RESULTS
// ============================================================

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

// ============================================================
// VOICE TUTOR
// ============================================================

class VoiceTutorPage extends StatefulWidget {
  final List<VocabularyWord> words;
  final Future<void> Function(AssessmentRecord) onCompleted;

  const VoiceTutorPage({super.key, required this.words, required this.onCompleted});

  @override
  State<VoiceTutorPage> createState() => _VoiceTutorPageState();
}

class _VoiceTutorPageState extends State<VoiceTutorPage> {
  final stt.SpeechToText speech = stt.SpeechToText();
  final FlutterTts tts = FlutterTts();
  final Random random = Random();

  VocabularyWord? currentWord;
  bool speechAvailable = false;
  bool listening = false;
  String transcript = '';
  double recognitionConfidence = 0;
  int speakingSeconds = 0;
  Timer? speakingTimer;
  int voiceScore = 0;
  double wordMatch = 0;
  double similarity = 0;
  String tutorFeedback =
      'Press the speaker button to hear the word, then say it aloud.';

  @override
  void initState() {
    super.initState();
    if (widget.words.isNotEmpty) {
      currentWord = widget.words[random.nextInt(widget.words.length)];
    }
    _initializeVoice();
    _initializeTts();
  }

  Future<void> _initializeVoice() async {
    try {
      speechAvailable = await speech.initialize(
        onStatus: (status) {
          if (status == 'notListening' && listening) _finishListening();
        },
        onError: (error) {
          if (mounted) {
            setState(() => tutorFeedback = 'Speech recognition error: ${error.errorMsg}');
          }
        },
      );
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        setState(() => tutorFeedback = 'Unable to initialise speech recognition.');
      }
    }
  }

  Future<void> _initializeTts() async {
    await tts.setLanguage('en-US');
    await tts.setSpeechRate(.45);
    await tts.setPitch(1.0);
    await tts.setVolume(1.0);
  }

  Future<void> _speak(String text) async {
    await tts.stop();
    await tts.speak(text);
  }

  Future<void> _speakWord() async {
    if (currentWord == null) return;
    await _speak(currentWord!.word);
  }

  Future<void> _speakLesson() async {
    if (currentWord == null) return;
    final w = currentWord!;
    await _speak('${w.word}. ${w.definition}. Meaning: ${w.meaning}. Example: ${w.example}.');
  }

  Future<void> _startListening() async {
    if (!speechAvailable) await _initializeVoice();
    if (!speechAvailable) {
      setState(() => tutorFeedback = 'Speech recognition is not available on this device.');
      return;
    }

    transcript = '';
    recognitionConfidence = 0;
    voiceScore = 0;
    wordMatch = 0;
    similarity = 0;
    speakingSeconds = 0;

    speakingTimer?.cancel();
    speakingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && listening) setState(() => speakingSeconds++);
    });

    setState(() {
      listening = true;
      tutorFeedback = 'Listening... say the word clearly.';
    });

    await speech.listen(
      onResult: (result) {
        if (!mounted) return;
        setState(() {
          transcript = result.recognizedWords;
          recognitionConfidence = result.confidence;
        });
        if (result.finalResult) _finishListening();
      },
      localeId: 'en_US',
      listenFor: const Duration(seconds: 15),
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
    );
  }

  Future<void> _finishListening() async {
    if (!listening) return;
    speakingTimer?.cancel();
    await speech.stop();
    if (!mounted) return;
    setState(() => listening = false);
    _calculateVoiceScore();
  }

  void _calculateVoiceScore() {
    if (currentWord == null) return;
    final target = _normalize(currentWord!.word);
    final spoken = _normalize(transcript);

    if (spoken.isEmpty) {
      setState(() {
        voiceScore = 0;
        tutorFeedback = 'No speech was detected. Please try again.';
      });
      return;
    }

    final targetWords = target.split(' ');
    final spokenWords = spoken.split(' ');
    int matches = 0;
    for (final w in targetWords) {
      if (spokenWords.contains(w)) matches++;
    }

    wordMatch = targetWords.isEmpty ? 0 : matches / targetWords.length * 100;
    similarity = _stringSimilarity(target, spoken);
    final confidenceScore = recognitionConfidence > 0 ? recognitionConfidence * 100 : 50;

    voiceScore =
        ((wordMatch * .55) + (similarity * .25) + (confidenceScore * .20)).round();
    voiceScore = max(0, min(100, voiceScore));

    if (voiceScore >= 90) {
      tutorFeedback = 'Excellent pronunciation recognition. Your response closely matched the target.';
    } else if (voiceScore >= 75) {
      tutorFeedback = 'Good attempt. Repeat the word once more for greater consistency.';
    } else if (voiceScore >= 60) {
      tutorFeedback = 'Developing. Speak more slowly and clearly, then repeat.';
    } else {
      tutorFeedback = 'Keep practising. Listen to the model pronunciation and try again.';
    }

    setState(() {});
    _saveVoiceAssessment();
  }

  Future<void> _saveVoiceAssessment() async {
    final seconds = max(1, speakingSeconds);
    final level = voiceScore >= 90
        ? 'Excellent'
        : voiceScore >= 75
        ? 'Good'
        : voiceScore >= 60
        ? 'Developing'
        : 'Needs Practice';
    await widget.onCompleted(AssessmentRecord(
      date: DateTime.now(),
      score: voiceScore,
      total: 100,
      averageTime: seconds.toDouble(),
      voiceScore: voiceScore,
      level: level,
    ));
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  double _stringSimilarity(String a, String b) {
    if (a == b) return 100;
    if (a.isEmpty || b.isEmpty) return 0;
    final distance = _levenshtein(a, b);
    return (1 - distance / max(a.length, b.length)) * 100;
  }

  int _levenshtein(String a, String b) {
    final m = List.generate(a.length + 1, (_) => List<int>.filled(b.length + 1, 0));
    for (int i = 0; i <= a.length; i++) {
      m[i][0] = i;
    }
    for (int j = 0; j <= b.length; j++) {
      m[0][j] = j;
    }
    for (int i = 1; i <= a.length; i++) {
      for (int j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        m[i][j] = min(min(m[i - 1][j] + 1, m[i][j - 1] + 1), m[i - 1][j - 1] + cost);
      }
    }
    return m[a.length][b.length];
  }

  void _nextWord() {
    if (widget.words.isEmpty) return;
    setState(() {
      currentWord = widget.words[random.nextInt(widget.words.length)];
      transcript = '';
      voiceScore = 0;
      wordMatch = 0;
      similarity = 0;
      recognitionConfidence = 0;
      tutorFeedback = 'New word selected. Listen first, then speak.';
    });
  }

  @override
  void dispose() {
    speakingTimer?.cancel();
    speech.stop();
    tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final word = currentWord;
    if (word == null) {
      return const Scaffold(body: Center(child: Text('No vocabulary available.')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Voice Tutor'),
        actions: [
          IconButton(tooltip: 'New Word', onPressed: _nextWord, icon: const Icon(Icons.shuffle)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _wordHero(word),
          const SizedBox(height: 16),
          _voiceControls(),
          const SizedBox(height: 16),
          _transcriptCard(),
          const SizedBox(height: 16),
          _scoreCard(),
          const SizedBox(height: 16),
          _detailsCard(word),
        ],
      ),
    );
  }

  Widget _wordHero(VocabularyWord word) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          children: [
            const Text('SAY THIS WORD',
                style: TextStyle(color: Colors.white60, letterSpacing: 2)),
            const SizedBox(height: 12),
            Text(word.word,
                style: const TextStyle(fontSize: 38, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                Chip(label: Text(word.difficultCefrStyle)),
                Chip(label: Text(word.difficulty)),
                Chip(label: Text(word.partsOfSpeech)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _voiceControls() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _speakWord,
                    icon: const Icon(Icons.volume_up),
                    label: const Text('Hear Word'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _speakLesson,
                    icon: const Icon(Icons.record_voice_over),
                    label: const Text('AI Lesson'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: FilledButton.icon(
                onPressed: listening ? _finishListening : _startListening,
                icon: Icon(listening ? Icons.stop : Icons.mic),
                label: Text(listening ? 'STOP LISTENING' : 'START SPEAKING'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _transcriptCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Speech Recognition',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(transcript.isEmpty ? 'Your spoken response will appear here...' : transcript,
                style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 12),
            Text('Speaking time: ${speakingSeconds}s',
                style: const TextStyle(color: Colors.white60)),
          ],
        ),
      ),
    );
  }

  Widget _scoreCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text('VOICE SCORE',
                style: TextStyle(letterSpacing: 2, color: Colors.white60)),
            const SizedBox(height: 10),
            Text('$voiceScore',
                style: const TextStyle(
                    fontSize: 56, fontWeight: FontWeight.bold, color: Color(0xFF60A5FA))),
            const Text('/ 100', style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 16),
            _scoreBar('Word Match', wordMatch),
            _scoreBar('Recognition Confidence', recognitionConfidence * 100),
            _scoreBar('Text Similarity', similarity),
            const SizedBox(height: 14),
            Text(tutorFeedback,
                textAlign: TextAlign.center, style: const TextStyle(height: 1.5)),
          ],
        ),
      ),
    );
  }

  Widget _scoreBar(String title, double value) {
    final safe = value.clamp(0.0, 100.0).toDouble();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(title)),
            Text('${safe.toStringAsFixed(0)}%'),
          ]),
          const SizedBox(height: 5),
          LinearProgressIndicator(value: safe / 100),
        ],
      ),
    );
  }

  Widget _detailsCard(VocabularyWord word) {
    return Card(
      child: ExpansionTile(
        title: const Text('Vocabulary Information'),
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(word.definition),
                const SizedBox(height: 10),
                Text(word.meaning),
                const SizedBox(height: 10),
                Text('Example: ${word.example}'),
                const SizedBox(height: 10),
                Text('Synonyms: ${word.synonyms.join(', ')}'),
                const SizedBox(height: 10),
                Text('Usage: ${word.usage}'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// LOGIN (Firebase Auth)
// ============================================================

/// Shows LoginPage until a Firebase user is signed in, then shows [child].
class AuthGate extends StatelessWidget {
  final Widget child;
  const AuthGate({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        return snap.data == null ? const LoginPage() : child;
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _register = false;
  bool _hidePassword = true;
  bool _loading = false;
  String? _error;

  // Client-side brute-force throttle (Firebase also rate-limits server side).
  int _failures = 0;
  DateTime? _lockedUntil;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;

    if (_lockedUntil != null && DateTime.now().isBefore(_lockedUntil!)) {
      final s = _lockedUntil!.difference(DateTime.now()).inSeconds;
      setState(() => _error = 'Too many attempts. Try again in ${s}s.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final auth = FirebaseAuth.instance;
      final email = _email.text.trim();
      if (_register) {
        final cred = await auth.createUserWithEmailAndPassword(
            email: email, password: _password.text);
        await cred.user?.sendEmailVerification();
      } else {
        await auth.signInWithEmailAndPassword(
            email: email, password: _password.text);
      }
      _failures = 0;
    } on FirebaseAuthException catch (e) {
      _failures++;
      if (_failures >= 5) {
        _lockedUntil = DateTime.now().add(const Duration(seconds: 30));
        _failures = 0;
      }
      setState(() => _error = _message(e.code));
    } catch (_) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _email.text.trim();
    if (!_validEmail(email)) {
      setState(() => _error = 'Enter your email above first.');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    } catch (_) {}
    if (!mounted) return;
    // Same message either way, so accounts can't be enumerated.
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('If that account exists, a reset email was sent.')));
  }

  bool _validEmail(String v) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v);

  String _message(String code) {
    switch (code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'weak-password':
        return 'Password is too weak.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';
      case 'network-request-failed':
        return 'No internet connection.';
      default:
        return 'Authentication failed.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _form,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lock_outline,
                            size: 56, color: Color(0xFF60A5FA)),
                        const SizedBox(height: 12),
                        Text(_register ? 'Create account' : 'Welcome back',
                            style: const TextStyle(
                                fontSize: 26, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email_outlined),
                              border: OutlineInputBorder()),
                          validator: (v) => _validEmail((v ?? '').trim())
                              ? null
                              : 'Enter a valid email',
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _password,
                          obscureText: _hidePassword,
                          enableSuggestions: false,
                          autocorrect: false,
                          autofillHints: const [AutofillHints.password],
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.key),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(_hidePassword
                                  ? Icons.visibility
                                  : Icons.visibility_off),
                              onPressed: () => setState(
                                      () => _hidePassword = !_hidePassword),
                            ),
                          ),
                          validator: (v) {
                            final p = v ?? '';
                            if (p.length < 8) return 'Minimum 8 characters';
                            if (_register &&
                                !(RegExp(r'[A-Za-z]').hasMatch(p) &&
                                    RegExp(r'\d').hasMatch(p))) {
                              return 'Use letters and numbers';
                            }
                            return null;
                          },
                          onFieldSubmitted: (_) => _submit(),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(_error!,
                              style:
                              const TextStyle(color: Colors.redAccent)),
                        ],
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: FilledButton(
                            onPressed: _loading ? null : _submit,
                            child: _loading
                                ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2))
                                : Text(_register ? 'SIGN UP' : 'SIGN IN'),
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(() {
                            _register = !_register;
                            _error = null;
                          }),
                          child: Text(_register
                              ? 'Have an account? Sign in'
                              : 'New here? Create account'),
                        ),
                        if (!_register)
                          TextButton(
                              onPressed: _resetPassword,
                              child: const Text('Forgot password?')),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// NOTES
// ============================================================


/// Separate "Notes" section: searchable, expandable list of all words.
class NotesPage extends StatefulWidget {
  final List<VocabularyWord> words;
  const NotesPage({super.key, required this.words});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  String search = '';
  String letter = 'All';

  List<VocabularyWord> get filtered {
    final q = search.toLowerCase().trim();
    final list = widget.words.where((w) {
      final okLetter = letter == 'All' || w.letter.toUpperCase() == letter;
      final okSearch = q.isEmpty ||
          w.word.toLowerCase().contains(q) ||
          w.meaning.toLowerCase().contains(q) ||
          w.synonyms.any((s) => s.toLowerCase().contains(q));
      return okLetter && okSearch;
    }).toList()
      ..sort((a, b) => a.word.toLowerCase().compareTo(b.word.toLowerCase()));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final letters = widget.words
        .map((e) => e.letter.toUpperCase())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final items = filtered;

    return Scaffold(
      appBar: AppBar(title: const Text('Notes')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search notes...',
                prefixIcon: const Icon(Icons.search),
                border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onChanged: (v) => setState(() => search = v),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final l in ['All', ...letters])
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(l),
                      selected: letter == l,
                      onSelected: (_) => setState(() => letter = l),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('${items.length} words',
                  style: const TextStyle(color: Colors.white60)),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              itemBuilder: (_, i) {
                final w = items[i];
                return Card(
                  child: ExpansionTile(
                    title: Text(w.word,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    subtitle: Text(
                        '${w.partsOfSpeech} • ${w.difficultCefrStyle}',
                        style: const TextStyle(color: Colors.white60)),
                    childrenPadding: const EdgeInsets.all(16),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _row('Definition', w.definition),
                      _row('Meaning', w.meaning),
                      _row('Synonyms', w.synonyms.join(', ')),
                      _row('Example', w.example),
                      _row('Usage', w.usage),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String title, String body) {
    if (body.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Color(0xFF60A5FA), fontWeight: FontWeight.bold)),
          const SizedBox(height: 3),
          Text(body, style: const TextStyle(height: 1.4)),
        ],
      ),
    );
  }
}

// ============================================================
// SCORES: PDF / GOOGLE DRIVE / EMAIL
// ============================================================



// ============================================================
// REPORT SERVICE: PDF, CSV, Google Drive, Gmail
// ============================================================

class ReportService {
  static final GoogleSignIn _gsi = GoogleSignIn(
    scopes: [drive.DriveApi.driveFileScope, gmail.GmailApi.gmailSendScope],
  );

  static String _d(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  static Future<Uint8List> buildPdf(
      List<AssessmentRecord> history, String student) async {
    final doc = pw.Document();
    final avg = history.isEmpty
        ? 0.0
        : history.map((e) => e.percentage).reduce((a, b) => a + b) /
        history.length;

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (_) => [
        pw.Text('Vocabulary Assessment Report',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Text('Student: $student'),
        pw.Text('Generated: ${_d(DateTime.now())}'),
        pw.Text('Assessments: ${history.length}   '
            'Average: ${avg.toStringAsFixed(1)}%'),
        pw.SizedBox(height: 16),
        pw.TableHelper.fromTextArray(
          headers: ['Date', 'Score', '%', 'Avg time (s)', 'Voice', 'Level'],
          data: [
            for (final r in history)
              [
                _d(r.date),
                '${r.score}/${r.total}',
                r.percentage.toStringAsFixed(1),
                r.averageTime.toStringAsFixed(1),
                '${r.voiceScore}',
                r.level,
              ]
          ],
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          headerDecoration:
          const pw.BoxDecoration(color: PdfColors.blue100),
          cellAlignment: pw.Alignment.centerLeft,
        ),
      ],
    ));
    return doc.save();
  }

  static String buildCsv(List<AssessmentRecord> history) {
    String q(String v) => '"${v.replaceAll('"', '""')}"';
    final rows = <String>['Date,Score,Total,Percentage,AvgTimeSec,Voice,Level'];
    for (final r in history) {
      rows.add([
        _d(r.date),
        r.score,
        r.total,
        r.percentage.toStringAsFixed(1),
        r.averageTime.toStringAsFixed(1),
        r.voiceScore,
        q(r.level),
      ].join(','));
    }
    return rows.join('\n');
  }

  static Future<http.Client> _client() async {
    final account = await _gsi.signInSilently() ?? await _gsi.signIn();
    if (account == null) throw 'Google sign-in was cancelled.';
    final client = await _gsi.authenticatedClient();
    if (client == null) throw 'Google permissions were not granted.';
    return client;
  }

  static Future<void> download(Uint8List pdf) =>
      Printing.sharePdf(bytes: pdf, filename: 'vocabulary_report.pdf');

  /// Uploads scores as a Google Sheet (CSV converted by Drive). Returns link.
  static Future<String?> uploadSheet(List<AssessmentRecord> history) async {
    final client = await _client();
    try {
      final bytes = utf8.encode(buildCsv(history));
      final meta = drive.File()
        ..name = 'Vocabulary Assessment Scores'
        ..mimeType = 'application/vnd.google-apps.spreadsheet';
      final res = await drive.DriveApi(client).files.create(
        meta,
        uploadMedia: drive.Media(Stream.value(bytes), bytes.length,
            contentType: 'text/csv'),
        $fields: 'id,webViewLink',
      );
      return res.webViewLink;
    } finally {
      client.close();
    }
  }

  /// Emails the PDF via the Gmail API (sent from the signed-in Google account).
  static Future<void> emailPdf(String to, Uint8List pdf) async {
    // Block header injection.
    if (to.contains(RegExp(r'[\r\n,;<>]'))) throw 'Invalid email address.';

    final client = await _client();
    try {
      final b = 'bnd${DateTime.now().millisecondsSinceEpoch}';
      final body = base64Encode(pdf);
      final wrapped = RegExp('.{1,76}')
          .allMatches(body)
          .map((m) => m.group(0))
          .join('\r\n');
      final mime = [
        'To: $to',
        'Subject: Vocabulary Assessment Report',
        'MIME-Version: 1.0',
        'Content-Type: multipart/mixed; boundary="$b"',
        '',
        '--$b',
        'Content-Type: text/plain; charset="UTF-8"',
        '',
        'Please find the vocabulary assessment report attached.',
        '--$b',
        'Content-Type: application/pdf; name="vocabulary_report.pdf"',
        'Content-Transfer-Encoding: base64',
        'Content-Disposition: attachment; filename="vocabulary_report.pdf"',
        '',
        wrapped,
        '--$b--',
      ].join('\r\n');

      final msg = gmail.Message()..raw = base64UrlEncode(utf8.encode(mime));
      await gmail.GmailApi(client).users.messages.send(msg, 'me');
    } finally {
      client.close();
    }
  }
}

// ============================================================
// SCORES PAGE
// ============================================================

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
      _toast(await task() ?? 'Done');
    } catch (e) {
      _toast('Failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _downloadPdf() => _run(() async {
    await ReportService.download(
        await ReportService.buildPdf(widget.history, _student));
    return null;
  });

  Future<void> _uploadSheet() => _run(() async {
    final link = await ReportService.uploadSheet(widget.history);
    return link == null ? 'Uploaded to Google Drive' : 'Uploaded: $link';
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
      return 'PDF sent to $to';
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
                    label: const Text('Email PDF'),
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
                    '${ReportService._d(r.date)} • Avg ${r.averageTime.toStringAsFixed(1)}s'),
                trailing: r.voiceScore > 0 ? Text('Voice ${r.voiceScore}') : null,
              ),
            ),
        ],
      ),
    );
  }
}