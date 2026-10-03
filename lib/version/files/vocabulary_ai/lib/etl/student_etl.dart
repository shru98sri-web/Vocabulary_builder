import '../ml/performance_ml.dart';
import '../models/assessment_record.dart';
import '../services/student_storage.dart';
import 'etl_pipeline.dart';

// ------------------------------------------------------------
// PIPELINE 1: load student data (storage -> analytics)
// ------------------------------------------------------------

class StudentSnapshot {
  final List<AssessmentRecord> history;
  final List<PerformanceSample> samples;
  final StudentPerformanceML model;
  const StudentSnapshot(this.history, this.samples, this.model);
}

/// EXTRACT: history, training samples and model from local storage.
class StudentDataExtractor implements Extractor<StudentSnapshot> {
  @override
  Future<StudentSnapshot> extract() async {
    final history = await StudentStorage.loadAssessments();
    final samples = await StudentStorage.loadPerformanceSamples();
    final model = await StudentStorage.loadModel();
    return StudentSnapshot(history, samples, model);
  }
}

class StudentAnalytics {
  final List<AssessmentRecord> history;
  final StudentPerformanceML model;
  final int sampleCount;
  final double mastery;
  final bool modelRetrained;
  const StudentAnalytics({
    required this.history,
    required this.model,
    required this.sampleCount,
    required this.mastery,
    required this.modelRetrained,
  });
}

/// TRANSFORM: retrain an empty model from samples, compute current mastery.
class StudentAnalyticsTransformer
    implements Transformer<StudentSnapshot, StudentAnalytics> {
  @override
  StudentAnalytics transform(StudentSnapshot s) {
    var retrained = false;
    if (s.model.trainingSteps == 0 && s.samples.isNotEmpty) {
      s.model.trainMany(s.samples);
      retrained = true;
    }
    final latest = s.history.isNotEmpty ? s.history.first : null;
    final mastery = latest == null
        ? 0.0
        : s.model.predict(
            accuracy: latest.percentage,
            averageTime: latest.averageTime,
            voiceScore: latest.voiceScore.toDouble(),
          );
    return StudentAnalytics(
      history: s.history,
      model: s.model,
      sampleCount: s.samples.length,
      mastery: mastery,
      modelRetrained: retrained,
    );
  }
}

/// LOAD: persist the model only if it was retrained.
class StudentAnalyticsLoader
    implements Loader<StudentAnalytics, StudentAnalytics> {
  @override
  Future<StudentAnalytics> load(StudentAnalytics a) async {
    if (a.modelRetrained) await StudentStorage.saveModel(a.model);
    return a;
  }
}

class StudentEtl {
  static Future<StudentAnalytics> load() => EtlPipeline<StudentSnapshot,
          StudentAnalytics, StudentAnalytics>(
        name: 'student-load',
        extractor: StudentDataExtractor(),
        transformer: StudentAnalyticsTransformer(),
        loader: StudentAnalyticsLoader(),
      ).run();
}

// ------------------------------------------------------------
// PIPELINE 2: ingest a finished assessment (record -> storage + ML)
// ------------------------------------------------------------

class IngestPayload {
  final AssessmentRecord record;
  final PerformanceSample sample;
  const IngestPayload(this.record, this.sample);
}

/// EXTRACT: the assessment that just finished.
class NewAssessmentExtractor implements Extractor<AssessmentRecord> {
  final AssessmentRecord record;
  const NewAssessmentExtractor(this.record);

  @override
  Future<AssessmentRecord> extract() async => record;
}

/// TRANSFORM: record -> normalised training sample.
class AssessmentToSampleTransformer
    implements Transformer<AssessmentRecord, IngestPayload> {
  @override
  IngestPayload transform(AssessmentRecord record) {
    final accuracy = (record.percentage / 100).clamp(0.0, 1.0).toDouble();
    final speed = record.averageTime <= 0
        ? 1.0
        : (1 / (1 + record.averageTime / 15)).clamp(0.0, 1.0).toDouble();
    final voice = (record.voiceScore / 100).clamp(0.0, 1.0).toDouble();
    final target = ((accuracy * .65) + (speed * .15) + (voice * .20))
        .clamp(0.0, 1.0)
        .toDouble();
    return IngestPayload(
      record,
      PerformanceSample(
          accuracy: accuracy, speed: speed, voiceScore: voice, target: target),
    );
  }
}

/// LOAD: train the model, save record + sample + model, return new mastery.
class AssessmentIngestLoader implements Loader<IngestPayload, double> {
  final StudentPerformanceML model;
  const AssessmentIngestLoader(this.model);

  @override
  Future<double> load(IngestPayload p) async {
    model.train(p.sample);
    await StudentStorage.saveAssessment(p.record);
    await StudentStorage.savePerformanceSample(p.sample);
    await StudentStorage.saveModel(model);
    return model.predict(
      accuracy: p.record.percentage,
      averageTime: p.record.averageTime,
      voiceScore: p.record.voiceScore.toDouble(),
    );
  }
}

class AssessmentIngestEtl {
  static Future<double> run(
          AssessmentRecord record, StudentPerformanceML model) =>
      EtlPipeline<AssessmentRecord, IngestPayload, double>(
        name: 'assessment-ingest',
        extractor: NewAssessmentExtractor(record),
        transformer: AssessmentToSampleTransformer(),
        loader: AssessmentIngestLoader(model),
      ).run();
}
