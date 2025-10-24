class QuizPack {
  final String language;
  final String level;
  final List<Exercise> exercises;

  QuizPack({
    required this.language,
    required this.level,
    required this.exercises,
  });

  factory QuizPack.fromJson(Map<String, dynamic> j) => QuizPack(
    language: j['language'] as String,
    level: j['level'] as String,
    exercises: (j['exercises'] as List<dynamic>)
        .map((e) => Exercise.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'language': language,
    'level': level,
    'total_exercises': exercises.length,
    'total_questions': exercises.fold<int>(0, (p, e) => p + e.questions.length),
    'exercises': exercises.map((e) => e.toJson()).toList(),
  };
}

class Exercise {
  int id;
  String title;
  String instructions;
  List<QuestionItem> questions;

  Exercise({
    required this.id,
    required this.title,
    required this.instructions,
    required this.questions,
  });

  factory Exercise.fromJson(Map<String, dynamic> j) => Exercise(
    id: j['id'] as int,
    title: j['title'] as String,
    instructions: j['instructions'] as String,
    questions: (j['questions'] as List<dynamic>)
        .map((q) => QuestionItem.fromJson(q as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'instructions': instructions,
    'questions': questions.map((q) => q.toJson()).toList(),
  };
}

class QuestionItem {
  int id;
  String question;
  Map<String, String> choices;
  String answer;
  String? explanation;

  QuestionItem({
    required this.id,
    required this.question,
    required this.choices,
    required this.answer,
    this.explanation,
  });

  factory QuestionItem.fromJson(Map<String, dynamic> j) => QuestionItem(
    id: j['id'] as int,
    question: j['question'] as String,
    choices: Map<String, String>.from(j['choices'] as Map),
    answer: j['answer'] as String,
    explanation: j['explanation'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'question': question,
    'choices': choices,
    'answer': answer,
    'explanation': explanation,
  };
}
