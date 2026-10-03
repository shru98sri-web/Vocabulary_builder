import 'vocabulary_word.dart';

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
