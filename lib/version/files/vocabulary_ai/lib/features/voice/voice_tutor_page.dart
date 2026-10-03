import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../models/assessment_record.dart';
import '../../models/vocabulary_word.dart';

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
