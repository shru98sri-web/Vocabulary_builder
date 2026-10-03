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
