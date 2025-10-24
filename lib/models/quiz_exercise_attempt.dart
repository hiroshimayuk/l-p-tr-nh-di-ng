import 'package:vn_es_demo/models/quiz_models.dart';

class QuizExerciseAttempt {
  final List<QuestionItem> questions;
  final Map<String, String> userAnswers;

  QuizExerciseAttempt({
    required this.questions,
    required this.userAnswers,
  });

  factory QuizExerciseAttempt.fromJson(Map<String, dynamic> json) {
    final questionsList = (json['questions'] as List)
        .map((item) => QuestionItem.fromJson(item as Map<String, dynamic>))
        .toList();
    final answersMap = Map<String, String>.from(json['userAnswers'] as Map);
    return QuizExerciseAttempt(
      questions: questionsList,
      userAnswers: answersMap,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'questions': questions.map((q) => q.toJson()).toList(),
      'userAnswers': userAnswers,
    };
  }
}
