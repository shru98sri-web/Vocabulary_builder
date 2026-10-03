import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/vocabulary_word.dart';
import 'etl_pipeline.dart';

typedef RawRow = Map<String, dynamic>;

/// EXTRACT: reads assets/vocab.json (a list, or {"words": [...]}).
class VocabularyExtractor implements Extractor<List<RawRow>> {
  final String assetPath;
  const VocabularyExtractor([this.assetPath = 'assets/vocab.json']);

  @override
  Future<List<RawRow>> extract() async {
    final raw = await rootBundle.loadString(assetPath);
    final decoded = jsonDecode(raw);
    List<dynamic> list = [];
    if (decoded is Map<String, dynamic>) {
      if (decoded['words'] is List) list = decoded['words'];
    } else if (decoded is List) {
      list = decoded;
    }
    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
}

class VocabularyBatch {
  final List<VocabularyWord> words;
  final int rejected;
  final int duplicates;
  const VocabularyBatch(this.words, this.rejected, this.duplicates);
}

/// TRANSFORM: parse rows, drop blank words, remove duplicate words.
class VocabularyTransformer
    implements Transformer<List<RawRow>, VocabularyBatch> {
  @override
  VocabularyBatch transform(List<RawRow> rows) {
    final seen = <String>{};
    final words = <VocabularyWord>[];
    var rejected = 0;
    var duplicates = 0;

    for (final row in rows) {
      final word = VocabularyWord.fromJson(row);
      final key = word.word.trim().toLowerCase();
      if (key.isEmpty) {
        rejected++;
        continue;
      }
      if (!seen.add(key)) {
        duplicates++;
        continue;
      }
      words.add(word);
    }
    return VocabularyBatch(words, rejected, duplicates);
  }
}

/// Destination for loaded vocabulary (shared in-memory cache).
class VocabularyRepository {
  VocabularyRepository._();
  static final VocabularyRepository instance = VocabularyRepository._();
  List<VocabularyWord> words = const [];
}

/// LOAD: stores the clean batch in the repository.
class VocabularyLoader implements Loader<VocabularyBatch, VocabularyBatch> {
  @override
  Future<VocabularyBatch> load(VocabularyBatch batch) async {
    VocabularyRepository.instance.words = batch.words;
    return batch;
  }
}

class VocabularyEtl {
  static Future<VocabularyBatch> run() => EtlPipeline<List<RawRow>,
          VocabularyBatch, VocabularyBatch>(
        name: 'vocabulary',
        extractor: const VocabularyExtractor(),
        transformer: VocabularyTransformer(),
        loader: VocabularyLoader(),
      ).run();
}
