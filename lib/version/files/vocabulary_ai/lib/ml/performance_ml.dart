import 'dart:math';

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
