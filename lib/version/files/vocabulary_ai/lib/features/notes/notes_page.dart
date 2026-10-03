import 'package:flutter/material.dart';
import '../../models/vocabulary_word.dart';

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
