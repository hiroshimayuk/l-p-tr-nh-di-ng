import 'package:flutter/material.dart';
import '../models/quiz_result.dart';
import '../models/quiz_exercise_attempt.dart';
import '../models/quiz_models.dart';

class HistoryDetailPage extends StatelessWidget {
  final QuizResult result;
  final bool isImmediateResult;

  const HistoryDetailPage({
    super.key,
    required this.result,
    this.isImmediateResult = false,
  });

  String _getQuestionText(QuestionItem q) => q.question;
  Map<String, String> _getChoices(QuestionItem q) => q.choices;
  String _getAnswerKey(QuestionItem q) => q.answer;
  String? _getExplanation(QuestionItem q) => q.explanation;

  @override
  Widget build(BuildContext context) {
    final attempt = result.attemptDetails;
    if (attempt == null) {
      return Scaffold(
        appBar: AppBar(title: Text(result.quizTitle)),
        body: const Center(child: Text('Không có dữ liệu chi tiết cho lần làm bài này.')),
      );
    }

    final questions = attempt.questions;
    final userAnswers = attempt.userAnswers; // keys expected as string ids
    final correctCount = result.correctAnswers;
    final total = result.totalQuestions;
    final percent = total > 0 ? (correctCount / total * 100).round() : 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(isImmediateResult ? 'Kết quả bài làm' : 'Chi tiết lịch sử'),
        automaticallyImplyLeading: !isImmediateResult,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(children: [
              Text(result.quizTitle, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('$correctCount', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.green)),
                Text('/$total câu đúng', style: const TextStyle(fontSize: 18)),
              ]),
              const SizedBox(height: 6),
              Text('($percent%)', style: const TextStyle(fontSize: 16, color: Colors.grey)),
            ]),
          ),
          const Divider(thickness: 2),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: questions.length,
              itemBuilder: (context, index) {
                final q = questions[index];
                final qIdKey = q.id.toString();
                final userKey = userAnswers[qIdKey];
                final correctKey = _getAnswerKey(q);
                final choices = _getChoices(q);
                final isCorrect = userKey != null && userKey.toUpperCase() == correctKey.toUpperCase();

                return Card(
                  color: isCorrect ? Colors.green.shade50 : Colors.red.shade50,
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: isCorrect ? Colors.green.shade200 : Colors.red.shade200,
                      width: 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Câu ${index + 1}: ${_getQuestionText(q)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      Text('Đáp án đúng: ${correctKey}. ${choices[correctKey] ?? ''}', style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      if (!isCorrect)
                        Text('Bạn đã chọn: ${userKey != null ? '${userKey}. ${choices[userKey] ?? ''}' : 'Chưa trả lời'}', style: TextStyle(color: Colors.red.shade900)),
                      if (_getExplanation(q) != null && _getExplanation(q)!.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text('Giải thích: ${_getExplanation(q)!}', style: TextStyle(color: Colors.blue.shade800, fontStyle: FontStyle.italic)),
                        ),
                    ]),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                onPressed: () {
                  if (isImmediateResult) {
                    int cnt = 0;
                    Navigator.of(context).popUntil((_) => cnt++ >= 2);
                  } else {
                    Navigator.of(context).pop();
                  }
                },
                child: Text(isImmediateResult ? 'Về trang trước' : 'Quay lại lịch sử'),
              ),
            ),
          )
        ],
      ),
    );
  }
}
