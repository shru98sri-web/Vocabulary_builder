import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../ml/performance_ml.dart';
import '../models/assessment_record.dart';

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
