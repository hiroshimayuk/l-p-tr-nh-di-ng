import 'dart:convert';

import 'quiz_exercise_attempt.dart';

class QuizResult {
  final String quizTitle;
  final int totalQuestions;
  final int correctAnswers;
  final DateTime timestamp;
  final QuizExerciseAttempt attemptDetails;

  QuizResult({
    required this.quizTitle,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.timestamp,
    required this.attemptDetails,
  });

  double get score => totalQuestions == 0 ? 0.0 : correctAnswers / totalQuestions;

  Map<String, dynamic> toJson() => {
    'quizTitle': quizTitle,
    'totalQuestions': totalQuestions,
    'correctAnswers': correctAnswers,
    'timestamp': timestamp.toIso8601String(),
    'attemptDetails': attemptDetails.toJson(),
  };

  factory QuizResult.fromJson(Map<String, dynamic> j) => QuizResult(
    quizTitle: j['quizTitle'] as String,
    totalQuestions: j['totalQuestions'] as int,
    correctAnswers: j['correctAnswers'] as int,
    timestamp: DateTime.parse(j['timestamp'] as String),
    attemptDetails: QuizExerciseAttempt.fromJson(Map<String, dynamic>.from(j['attemptDetails'] as Map)),
  );

  @override
  String toString() => json.encode(toJson());

  // Helper constructor used elsewhere
  factory QuizResult.create({
    required String quizTitle,
    required int totalQuestions,
    required int correctAnswers,
    required QuizExerciseAttempt attemptDetails,
  }) {
    return QuizResult(
      quizTitle: quizTitle,
      totalQuestions: totalQuestions,
      correctAnswers: correctAnswers,
      timestamp: DateTime.now(),
      attemptDetails: attemptDetails,
    );
  }
}
