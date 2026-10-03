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
