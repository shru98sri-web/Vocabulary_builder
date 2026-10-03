import 'package:flutter/material.dart';

import 'features/auth/auth_gate.dart';
import 'features/home/vocabulary_home.dart';

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
      home: const AuthGate(child: VocabularyHome()),
    );
  }
}
