import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
      home: const VocabularyHome(),
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

      // Supports both spellings.
      difficultCefrStyle:
      '${json['difficult_cefr_style'] ?? json['difficulty_cefr_style'] ?? ''}',

      difficulty: '${json['difficulty'] ?? ''}',

      // Supports user's new field and older JSON field.
      partsOfSpeech:
      '${json['parts_of_speech'] ?? json['part_of_speech'] ?? ''}',

      definition: '${json['definition'] ?? ''}',
      meaning: '${json['meaning'] ?? ''}',

      synonyms: _stringList(json['synonyms']),

      example: '${json['example'] ?? ''}',

      // Supports requested spelling + existing file spelling.
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

    if (value is List) {
      return value.map((e) => '$e').toList();
    }

    if (value is String && value.trim().isNotEmpty) {
      return [value];
    }

    return [];
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'word': word,
      'letter': letter,
      'difficult_cefr_style': difficultCefrStyle,
      'difficulty': difficulty,
      'parts_of_speech': partsOfSpeech,
      'definition': definition,
      'meaning': meaning,
      'synonyms': synonyms,
      'example': example,
      'gmat_relavance': gmatRelevance,
      'ielts_relavance': ieltsRelevance,
      'usage': usage,
      'current_status': currentStatus,
      'year_focus': yearFocus,
      'source_reference': sourceReference,
      'source_note': sourceNote,
    };
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

  double get percentage {
    if (total == 0) return 0;
    return score / total * 100;
  }

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
    return AssessmentRecord(
      date: DateTime.tryParse('${json['date']}') ?? DateTime.now(),
      score: json['score'] is num
          ? (json['score'] as num).toInt()
          : int.tryParse('${json['score']}') ?? 0,
      total: json['total'] is num
          ? (json['total'] as num).toInt()
          : int.tryParse('${json['total']}') ?? 0,
      averageTime: n(json['averageTime']),
      voiceScore: json['voiceScore'] is num
          ? (json['voiceScore'] as num).toInt()
          : int.tryParse('${json['voiceScore']}') ?? 0,
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

class StudentStorage {
  static const _historyKey = 'vocabulary_assessment_history';
  static const _samplesKey = 'student_performance_samples';
  static const _modelKey = 'student_ml_model';

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
        result.add(
          AssessmentRecord.fromJson(
            Map<String, dynamic>.from(jsonDecode(item)),
          ),
        );
      } catch (_) {}
    }
    result.sort((a, b) => b.date.compareTo(a.date));
    return result;
  }

  static Future<void> savePerformanceSample(PerformanceSample sample) async {
    final prefs = await SharedPreferences.getInstance();
    final samples = await loadPerformanceSamples();
    samples.add(sample);
    final trimmed = samples.length > 500
        ? samples.sublist(samples.length - 500)
        : samples;
    await prefs.setStringList(
      _samplesKey,
      trimmed.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  static Future<List<PerformanceSample>> loadPerformanceSamples() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_samplesKey) ?? [];
    final result = <PerformanceSample>[];
    for (final item in raw) {
      try {
        result.add(
          PerformanceSample.fromJson(
            Map<String, dynamic>.from(jsonDecode(item)),
          ),
        );
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
  bool mlLoading = true;
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
        mlLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => mlLoading = false);
    }
  }

  Future<void> loadVocabulary() async {
    try {
      final raw = await rootBundle.loadString('assets/vocab.json');

      final decoded = jsonDecode(raw);

      List<dynamic> list = [];

      if (decoded is Map<String, dynamic>) {
        if (decoded['words'] is List) {
          list = decoded['words'];
        }
      } else if (decoded is List) {
        list = decoded;
      }

      final loaded = list
          .whereType<Map>()
          .map(
            (item) => VocabularyWord.fromJson(Map<String, dynamic>.from(item)),
      )
          .where((item) => item.word.trim().isNotEmpty)
          .toList();

      setState(() {
        words = loaded;
        loading = false;
      });
    } catch (e) {
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
      accuracy: accuracy,
      speed: speed,
      voiceScore: voice,
      target: target,
    );
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
            child: Text(
              'Unable to load vocabulary.json\n\n$error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final pages = [
      DashboardPage(
        words: words,
        mastery: currentMastery,
        trainingSamples: totalTrainingSamples,
        onTest: () {
          setState(() {
            selectedIndex = 1;
          });
        },
      ),
      TestLauncher(words: words, onCompleted: addHistory),
      VoiceTutorPage(words: words, onCompleted: addHistory),
      HistoryPage(history: history),
      JsonPage(words: words),
    ];

    final destinations = [
      const NavigationRailDestination(
        icon: Icon(Icons.dashboard_outlined),
        selectedIcon: Icon(Icons.dashboard),
        label: Text('Dashboard'),
      ),
      const NavigationRailDestination(
        icon: Icon(Icons.quiz_outlined),
        selectedIcon: Icon(Icons.quiz),
        label: Text('Test'),
      ),
      const NavigationRailDestination(
        icon: Icon(Icons.mic_none),
        selectedIcon: Icon(Icons.mic),
        label: Text('Voice'),
      ),
      const NavigationRailDestination(
        icon: Icon(Icons.history),
        selectedIcon: Icon(Icons.history),
        label: Text('History'),
      ),
      const NavigationRailDestination(
        icon: Icon(Icons.data_object),
        selectedIcon: Icon(Icons.data_object),
        label: Text('JSON'),
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) {
                setState(() {
                  selectedIndex = index;
                });
              },
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
// DASHBOARD - MOBILE RESPONSIVE VERSION
// ============================================================

class DashboardPage extends StatefulWidget {
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
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String search = '';
  String selectedDifficulty = 'All';
  String selectedLetter = 'All';

  // ============================================================
  // FILTERED WORDS
  // ============================================================

  List<VocabularyWord> get filtered {
    return widget.words.where((word) {
      final searchText = search.toLowerCase().trim();

      final matchesSearch =
          searchText.isEmpty ||
              word.word.toLowerCase().contains(searchText) ||
              word.definition.toLowerCase().contains(searchText) ||
              word.meaning.toLowerCase().contains(searchText) ||
              word.synonyms.any((s) => s.toLowerCase().contains(searchText));

      final matchesDifficulty =
          selectedDifficulty == 'All' ||
              word.difficulty == selectedDifficulty ||
              word.difficultCefrStyle == selectedDifficulty;

      final matchesLetter =
          selectedLetter == 'All' ||
              word.letter.toUpperCase() == selectedLetter;

      return matchesSearch && matchesDifficulty && matchesLetter;
    }).toList();
  }

  // ============================================================
  // LETTERS
  // ============================================================

  Set<String> get letters {
    return widget.words
        .map((e) => e.letter.toUpperCase())
        .where((e) => e.isNotEmpty)
        .toSet();
  }

  // ============================================================
  // DIFFICULTIES
  // ============================================================

  Set<String> get difficulties {
    return widget.words
        .map((e) => e.difficulty)
        .where((e) => e.isNotEmpty)
        .toSet();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Vocabulary AI-ML',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Start Test',
            onPressed: widget.onTest,
            icon: const Icon(Icons.play_circle),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isSmallPhone = constraints.maxWidth < 380;

          final horizontalPadding = isSmallPhone ? 12.0 : 20.0;

          return ListView(
            padding: EdgeInsets.all(horizontalPadding),
            children: [
              _hero(),
              const SizedBox(height: 20),

              _stats(),

              const SizedBox(height: 16),

              _performanceCard(),

              const SizedBox(height: 20),

              _filters(),

              const SizedBox(height: 20),

              Text(
                '${filtered.length} vocabulary entries',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),

              const SizedBox(height: 12),

              ...filtered.take(100).map(_wordCard),
            ],
          );
        },
      ),
    );
  }

  // ============================================================
  // HERO
  // ============================================================

  Widget _hero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF87CEEB)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome, size: 40),

          const SizedBox(height: 16),

          const Text(
            'AI Vocabulary Hub',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          Text(
            '${widget.words.length} words • GMAT • IELTS • Academic • Contemporary English',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, height: 1.4),
          ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: widget.onTest,
              icon: const Icon(Icons.quiz),
              label: const Text(
                'Start Vocabulary Test',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STATISTICS
  // ============================================================

  Widget _stats() {
    final advanced = widget.words
        .where(
          (e) =>
      e.difficultCefrStyle.toUpperCase() == 'C1' ||
          e.difficultCefrStyle.toUpperCase() == 'C2',
    )
        .length;

    final gmat = widget.words
        .where((e) => e.gmatRelevance.toLowerCase() == 'high')
        .length;

    final ielts = widget.words
        .where((e) => e.ieltsRelevance.toLowerCase() == 'high')
        .length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        // Two columns on phones.
        final cardWidth = width < 700 ? (width - 12) / 2 : 180.0;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _statCard(
              'Total Words',
              '${widget.words.length}',
              Icons.menu_book,
              cardWidth,
            ),
            _statCard('Advanced', '$advanced', Icons.trending_up, cardWidth),
            _statCard('GMAT High', '$gmat', Icons.school, cardWidth),
            _statCard('IELTS High', '$ielts', Icons.language, cardWidth),
          ],
        );
      },
    );
  }

  // ============================================================
  // STAT CARD
  // ============================================================

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
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 2),

                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // PERFORMANCE ML CARD
  // ============================================================

  Widget _performanceCard() {
    final mastery = widget.mastery.clamp(0.0, 100.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 330;

            if (compact) {
              return Column(
                children: [
                  _masteryCircle(mastery),

                  const SizedBox(height: 16),

                  _performanceText(),
                ],
              );
            }

            return Row(
              children: [
                _masteryCircle(mastery),

                const SizedBox(width: 16),

                Expanded(child: _performanceText()),
              ],
            );
          },
        ),
      ),
    );
  }

  // ============================================================
  // MASTERY CIRCLE
  // ============================================================

  Widget _masteryCircle(double mastery) {
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(value: mastery / 100, strokeWidth: 7),

          Center(
            child: Text(
              '${mastery.round()}%',
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PERFORMANCE TEXT
  // ============================================================

  Widget _performanceText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Student Performance ML',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 5),

        Text(
          '${widget.trainingSamples} training samples',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),

        const SizedBox(height: 3),

        const Text(
          'Local adaptive learning model',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.white60, fontSize: 12),
        ),
      ],
    );
  }

  // ============================================================
  // FILTERS
  // ============================================================

  Widget _filters() {
    return Column(
      children: [
        TextField(
          decoration: InputDecoration(
            hintText: 'Search word, definition, meaning or synonym...',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          onChanged: (value) {
            setState(() {
              search = value;
            });
          },
        ),

        const SizedBox(height: 12),

        LayoutBuilder(
          builder: (context, constraints) {
            // Stack dropdowns vertically on narrow phones.
            if (constraints.maxWidth < 430) {
              return Column(
                children: [
                  _difficultyDropdown(),

                  const SizedBox(height: 12),

                  _letterDropdown(),
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: _difficultyDropdown()),

                const SizedBox(width: 12),

                Expanded(child: _letterDropdown()),
              ],
            );
          },
        ),
      ],
    );
  }

  // ============================================================
  // DIFFICULTY DROPDOWN
  // ============================================================

  Widget _difficultyDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: selectedDifficulty,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Difficulty',
        border: OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem(
          value: 'All',
          child: Text('All', overflow: TextOverflow.ellipsis),
        ),
        ...difficulties.map(
              (e) => DropdownMenuItem(
            value: e,
            child: Text(e, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
      onChanged: (value) {
        if (value == null) return;

        setState(() {
          selectedDifficulty = value;
        });
      },
    );
  }

  // ============================================================
  // LETTER DROPDOWN
  // ============================================================

  Widget _letterDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: selectedLetter,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Letter',
        border: OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem(
          value: 'All',
          child: Text('All', overflow: TextOverflow.ellipsis),
        ),
        ...letters.map(
              (e) => DropdownMenuItem(
            value: e,
            child: Text(e, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
      onChanged: (value) {
        if (value == null) return;

        setState(() {
          selectedLetter = value;
        });
      },
    );
  }

  // ============================================================
  // WORD CARD
  // ============================================================

  Widget _wordCard(VocabularyWord word) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) => WordDetailSheet(word: word),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ------------------------------------------------
              // WORD + CEFR
              // ------------------------------------------------
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      word.word,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  Flexible(child: _badge(word.difficultCefrStyle, Colors.blue)),
                ],
              ),

              const SizedBox(height: 6),

              // ------------------------------------------------
              // PART OF SPEECH / DIFFICULTY
              // ------------------------------------------------
              Text(
                '${word.partsOfSpeech} • ${word.difficulty}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white60),
              ),

              const SizedBox(height: 12),

              // ------------------------------------------------
              // DEFINITION
              // ------------------------------------------------
              Text(
                word.definition,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(height: 1.4),
              ),

              const SizedBox(height: 10),

              // ------------------------------------------------
              // EXAMPLE
              // ------------------------------------------------
              Text(
                'Example: ${word.example}',
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, height: 1.4),
              ),

              const SizedBox(height: 10),

              // ------------------------------------------------
              // TAGS
              // ------------------------------------------------
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _smallBadge('GMAT ${word.gmatRelevance}'),
                  _smallBadge('IELTS ${word.ieltsRelevance}'),
                  _smallBadge(word.currentStatus),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CEFR BADGE
  // ============================================================

  Widget _badge(String text, Color color) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 90),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  // ============================================================
  // SMALL BADGE
  // ============================================================

  Widget _smallBadge(String text) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 180),
      child: Chip(
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        label: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11),
        ),
      ),
    );
  }
}

// ============================================================
// WORD DETAIL
// ============================================================

class WordDetailSheet extends StatelessWidget {
  final VocabularyWord word;

  const WordDetailSheet({super.key, required this.word});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .85,
      maxChildSize: .95,
      builder: (_, controller) {
        return ListView(
          controller: controller,
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white30,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              word.word,
              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                Chip(label: Text(word.letter)),
                Chip(label: Text(word.difficultCefrStyle)),
                Chip(label: Text(word.difficulty)),
                Chip(label: Text(word.partsOfSpeech)),
              ],
            ),
            const SizedBox(height: 20),
            _section('Definition', word.definition),
            _section('Meaning', word.meaning),
            _section(
              'Synonyms',
              word.synonyms.isEmpty
                  ? 'No synonyms supplied.'
                  : word.synonyms.join(', '),
            ),
            _section('Example', word.example),
            _section('Usage', word.usage),
            _section('GMAT relevance', word.gmatRelevance),
            _section('IELTS relevance', word.ieltsRelevance),
            _section('Current status', word.currentStatus),
            _section('Year focus', word.yearFocus),
            _section('Source reference', word.sourceReference.join('\n')),
            _section('Source note', word.sourceNote),
          ],
        );
      },
    );
  }

  Widget _section(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF60A5FA),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            content.isEmpty ? 'Not available' : content,
            style: const TextStyle(fontSize: 15, height: 1.5),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// TEST LAUNCHER
// ============================================================

class TestLauncher extends StatelessWidget {
  final List<VocabularyWord> words;
  final Function(AssessmentRecord) onCompleted;

  const TestLauncher({
    super.key,
    required this.words,
    required this.onCompleted,
  });

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
                    const Icon(
                      Icons.assignment,
                      size: 70,
                      color: Color(0xFF60A5FA),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'AI Vocabulary Test',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${min(words.length, 10)} questions • 10 minutes',
                      style: const TextStyle(color: Colors.white60),
                    ),
                    const SizedBox(height: 25),
                    const Text(
                      'Question types',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '• Definition recognition\n'
                          '• Meaning recognition\n'
                          '• Context questions\n'
                          '• Synonym questions\n'
                          '• Adaptive difficulty\n'
                          '• Response-time analysis',
                    ),
                    const SizedBox(height: 30),
                    FilledButton.icon(
                      onPressed: words.length < 4
                          ? null
                          : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TestPage(
                              words: words,
                              onCompleted: onCompleted,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.play_arrow),
                      label: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('BEGIN TEST'),
                      ),
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

      setState(() {
        remainingSeconds--;
      });

      if (remainingSeconds <= 0) {
        _submit();
      }
    });
  }

  List<TestQuestion> _generateQuestions() {
    final pool = List<VocabularyWord>.from(widget.words)..shuffle(random);

    final selected = pool.take(min(10, pool.length)).toList();

    final result = <TestQuestion>[];

    for (final word in selected) {
      final type =
      QuestionType.values[random.nextInt(QuestionType.values.length)];

      List<String> options;

      switch (type) {
        case QuestionType.definition:
          options = _makeOptions(word, (w) => w.word);

        case QuestionType.meaning:
          options = _makeOptions(word, (w) => w.meaning);

        case QuestionType.example:
          options = _makeOptions(word, (w) => w.word);

        case QuestionType.synonym:
          options = _makeOptions(word, (w) {
            if (w.synonyms.isNotEmpty) {
              return w.synonyms.first;
            }
            return w.word;
          });
      }

      String correct;

      switch (type) {
        case QuestionType.definition:
          correct = word.word;

        case QuestionType.meaning:
          correct = word.meaning;

        case QuestionType.example:
          correct = word.word;

        case QuestionType.synonym:
          correct = word.synonyms.isNotEmpty ? word.synonyms.first : word.word;
      }

      result.add(
        TestQuestion(
          word: word,
          type: type,
          options: options,
          correctAnswer: correct,
        ),
      );
    }

    return result;
  }

  List<String> _makeOptions(
      VocabularyWord correct,
      String Function(VocabularyWord) selector,
      ) {
    final candidates =
    widget.words.where((w) => w.word != correct.word).toList()
      ..shuffle(random);

    final values = <String>[selector(correct)];

    for (final candidate in candidates) {
      final value = selector(candidate);

      if (value.trim().isEmpty) continue;

      if (!values.contains(value)) {
        values.add(value);
      }

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

    setState(() {});

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

      results.add(
        TestAnswer(
          question: q,
          selectedAnswer: selected,
          correct: selected == q.correctAnswer,
          seconds: questionTimes[i] ?? 0,
        ),
      );
    }

    final score = results.where((e) => e.correct).length;

    final averageTime = results.isEmpty
        ? 0
        : results.map((e) => e.seconds).reduce((a, b) => a + b) /
        results.length;

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
      MaterialPageRoute(
        builder: (_) => ResultsPage(results: results, record: record),
      ),
    );
  }

  String _level(percentage) {
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
        body: Center(child: Text('Not enough vocabulary entries.')),
      );
    }

    final question = questions[currentIndex];

    final minutes = (remainingSeconds ~/ 60).toString().padLeft(2, '0');

    final seconds = (remainingSeconds % 60).toString().padLeft(2, '0');

    return Scaffold(
      appBar: AppBar(
        title: Text('Question ${currentIndex + 1}/${questions.length}'),
        actions: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Chip(
              avatar: const Icon(Icons.timer, size: 18),
              label: Text('$minutes:$seconds'),
            ),
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
                  Text(
                    question.type.name.toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFF60A5FA),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    question.questionText,
                    style: const TextStyle(fontSize: 19, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          ...question.options.map(
                (option) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _optionButton(option),
            ),
          ),
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

    return max(0, min(100, accuracy + speedFactor));
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
          Text(
            'Mistake Analysis',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          if (mistakes.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('No mistakes. Excellent!'),
              ),
            )
          else
            ...mistakes.map((mistake) => _mistakeCard(mistake)),
          const SizedBox(height: 20),
          Text(
            'Question Review',
            style: Theme.of(context).textTheme.titleLarge,
          ),
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
            const Text(
              'YOUR SCORE',
              style: TextStyle(color: Colors.white, letterSpacing: 2),
            ),
            const SizedBox(height: 10),
            Text(
              '${record.score}/${record.total}',
              style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
            ),
            Text(
              '${accuracy.toStringAsFixed(1)}%',
              style: const TextStyle(fontSize: 24, color: Color(0xFF60A5FA)),
            ),
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
        _metric(
          'Avg Time',
          '${record.averageTime.toStringAsFixed(1)} sec',
          Icons.timer,
        ),
        _metric(
          'AI Mastery',
          '${mastery.toStringAsFixed(1)}%',
          Icons.auto_awesome,
        ),
        _metric(
          'Mistakes',
          '${results.where((e) => !e.correct).length}',
          Icons.error_outline,
        ),
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
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
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
            Expanded(
              child: Text(feedback, style: const TextStyle(height: 1.5)),
            ),
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
            Text(
              answer.question.word.word,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Your answer: ${answer.selectedAnswer}',
              style: const TextStyle(color: Colors.redAccent),
            ),
            const SizedBox(height: 5),
            Text(
              'Correct answer: ${answer.question.correctAnswer}',
              style: const TextStyle(color: Colors.greenAccent),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reviewCard(TestAnswer answer) {
    return Card(
      child: ExpansionTile(
        title: Text(answer.question.word.word),
        subtitle: Text(
          answer.correct
              ? 'Correct • ${answer.seconds}s'
              : 'Incorrect • ${answer.seconds}s',
        ),
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

  const VoiceTutorPage({
    super.key,
    required this.words,
    required this.onCompleted,
  });

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
          if (status == 'notListening' && listening) {
            _finishListening();
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              tutorFeedback = 'Speech recognition error: ${error.errorMsg}';
            });
          }
        },
      );

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          tutorFeedback = 'Unable to initialise speech recognition.';
        });
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

    final word = currentWord!;

    final lesson =
        '${word.word}. '
        '${word.definition}. '
        'Meaning: ${word.meaning}. '
        'Example: ${word.example}.';

    await _speak(lesson);
  }

  Future<void> _startListening() async {
    if (!speechAvailable) {
      await _initializeVoice();
    }

    if (!speechAvailable) {
      setState(() {
        tutorFeedback = 'Speech recognition is not available on this device.';
      });
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
      if (mounted && listening) {
        setState(() {
          speakingSeconds++;
        });
      }
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

        if (result.finalResult) {
          _finishListening();
        }
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

    setState(() {
      listening = false;
    });

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

    for (final word in targetWords) {
      if (spokenWords.contains(word)) {
        matches++;
      }
    }

    wordMatch = targetWords.isEmpty ? 0 : matches / targetWords.length * 100;

    similarity = _stringSimilarity(target, spoken);

    final confidenceScore = recognitionConfidence > 0
        ? recognitionConfidence * 100
        : 50;

    voiceScore =
        ((wordMatch * .55) + (similarity * .25) + (confidenceScore * .20))
            .round();

    voiceScore = max(0, min(100, voiceScore));

    if (voiceScore >= 90) {
      tutorFeedback =
      'Excellent pronunciation recognition. Your response closely matched the target.';
    } else if (voiceScore >= 75) {
      tutorFeedback =
      'Good attempt. Repeat the word once more for greater consistency.';
    } else if (voiceScore >= 60) {
      tutorFeedback = 'Developing. Speak more slowly and clearly, then repeat.';
    } else {
      tutorFeedback =
      'Keep practising. Listen to the model pronunciation and try again.';
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
    final record = AssessmentRecord(
      date: DateTime.now(),
      score: voiceScore,
      total: 100,
      averageTime: seconds.toDouble(),
      voiceScore: voiceScore,
      level: level,
    );
    await widget.onCompleted(record);
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

    if (a.isEmpty || b.isEmpty) {
      return 0;
    }

    final distance = _levenshtein(a, b);

    final longest = max(a.length, b.length);

    return (1 - distance / longest) * 100;
  }

  int _levenshtein(String a, String b) {
    final matrix = List.generate(
      a.length + 1,
          (_) => List<int>.filled(b.length + 1, 0),
    );

    for (int i = 0; i <= a.length; i++) {
      matrix[i][0] = i;
    }

    for (int j = 0; j <= b.length; j++) {
      matrix[0][j] = j;
    }

    for (int i = 1; i <= a.length; i++) {
      for (int j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;

        matrix[i][j] = min(
          min(matrix[i - 1][j] + 1, matrix[i][j - 1] + 1),
          matrix[i - 1][j - 1] + cost,
        );
      }
    }

    return matrix[a.length][b.length];
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
      return const Scaffold(
        body: Center(child: Text('No vocabulary available.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Voice Tutor'),
        actions: [
          IconButton(
            tooltip: 'New Word',
            onPressed: _nextWord,
            icon: const Icon(Icons.shuffle),
          ),
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
            const Text(
              'SAY THIS WORD',
              style: TextStyle(color: Colors.white60, letterSpacing: 2),
            ),
            const SizedBox(height: 12),
            Text(
              word.word,
              style: const TextStyle(fontSize: 38, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
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
            const Text(
              'Speech Recognition',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              transcript.isEmpty
                  ? 'Your spoken response will appear here...'
                  : transcript,
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 12),
            Text(
              'Speaking time: ${speakingSeconds}s',
              style: const TextStyle(color: Colors.white60),
            ),
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
            const Text(
              'VOICE SCORE',
              style: TextStyle(letterSpacing: 2, color: Colors.white60),
            ),
            const SizedBox(height: 10),
            Text(
              '$voiceScore',
              style: const TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.bold,
                color: Color(0xFF60A5FA),
              ),
            ),
            Text('/ 100', style: const TextStyle(color: Colors.white54)),
            const SizedBox(height: 16),
            _scoreBar('Word Match', wordMatch),
            _scoreBar('Recognition Confidence', recognitionConfidence * 100),
            _scoreBar('Text Similarity', similarity),
            const SizedBox(height: 14),
            Text(
              tutorFeedback,
              textAlign: TextAlign.center,
              style: const TextStyle(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scoreBar(String title, double value) {
    final safeValue = max(0, min(100, value));

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title)),
              Text('${safeValue.toStringAsFixed(0)}%'),
            ],
          ),
          const SizedBox(height: 5),
          LinearProgressIndicator(value: safeValue / 100),
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
// HISTORY
// ============================================================

class HistoryPage extends StatelessWidget {
  final List<AssessmentRecord> history;

  const HistoryPage({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assessment History')),
      body: history.isEmpty
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 60, color: Colors.white38),
            SizedBox(height: 12),
            Text('No assessments yet.'),
            SizedBox(height: 6),
            Text(
              'Complete a test to create history.',
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: history.length,
        itemBuilder: (_, index) {
          final item = history[index];

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(child: Text('${item.score}')),
              title: Text(
                '${item.percentage.toStringAsFixed(1)}% • ${item.level}',
              ),
              subtitle: Text(
                '${item.date.day}/${item.date.month}/${item.date.year}'
                    ' • Avg ${item.averageTime.toStringAsFixed(1)}s',
              ),
              trailing: item.voiceScore > 0
                  ? Text('Voice ${item.voiceScore}')
                  : null,
            ),
          );
        },
      ),
    );
  }
}

// ============================================================
// JSON VIEWER
// ============================================================

class JsonPage extends StatefulWidget {
  final List<VocabularyWord> words;

  const JsonPage({super.key, required this.words});

  @override
  State<JsonPage> createState() => _JsonPageState();
}

class _JsonPageState extends State<JsonPage> {
  bool pretty = true;

  String get jsonText {
    final data = {
      'metadata': {
        'title': 'Current English Vocabulary Bank',
        'entry_count': widget.words.length,
        'schema': [
          'id',
          'word',
          'letter',
          'difficult_cefr_style',
          'difficulty',
          'parts_of_speech',
          'definition',
          'meaning',
          'synonyms',
          'example',
          'gmat_relavance',
          'ielts_relavance',
          'usage',
          'current_status',
          'year_focus',
          'source_reference',
          'source_note',
        ],
      },
      'words': widget.words.map((e) => e.toJson()).toList(),
    };

    return pretty
        ? const JsonEncoder.withIndent('  ').convert(data)
        : jsonEncode(data);
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: jsonText));

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('JSON copied to clipboard')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vocabulary JSON'),
        actions: [
          IconButton(
            tooltip: 'Copy JSON',
            onPressed: _copy,
            icon: const Icon(Icons.copy),
          ),
          IconButton(
            tooltip: 'Pretty JSON',
            onPressed: () {
              setState(() {
                pretty = !pretty;
              });
            },
            icon: Icon(pretty ? Icons.format_align_left : Icons.code),
          ),
        ],
      ),
      body: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF020817),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white12),
        ),
        child: SingleChildScrollView(
          child: SelectableText(
            jsonText,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}
