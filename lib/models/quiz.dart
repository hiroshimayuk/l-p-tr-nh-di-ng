
class Quiz {
  final String id;
  final String question;
  final List<String> options;
  final int correctAnswerIndex;

  Quiz({
    required this.id,
    required this.question,
    required this.options,
    required this.correctAnswerIndex,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': question,
      'options': options,
      'correctAnswerIndex': correctAnswerIndex,
    };
  }

  factory Quiz.fromJson(Map<String, dynamic> json) {
    return Quiz(
      id: json['id'] as String,
      question: json['question'] as String,
      options: List<String>.from(json['options'] as List),
      correctAnswerIndex: json['correctAnswerIndex'] as int,
    );
  }
}
