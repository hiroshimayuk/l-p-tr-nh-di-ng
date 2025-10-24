import 'package:flutter/material.dart';
import '../models/quiz_models.dart';

class QuizEditExercisePage extends StatefulWidget {
  final Exercise exercise;
  final bool isNew;
  const QuizEditExercisePage({super.key, required this.exercise, required this.isNew});

  @override
  State<QuizEditExercisePage> createState() => _QuizEditExercisePageState();
}

class _QuizEditExercisePageState extends State<QuizEditExercisePage> {
  late Exercise _ex;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _ex = Exercise(
      id: widget.exercise.id,
      title: widget.exercise.title,
      instructions: widget.exercise.instructions,
      questions: widget.exercise.questions
          .map((q) => QuestionItem(id: q.id, question: q.question, choices: Map.from(q.choices), answer: q.answer, explanation: q.explanation))
          .toList(),
    );
  }

  void _saveAndReturn() {
    if (!_formKey.currentState!.validate()) return;
    for (final q in _ex.questions) {
      if (q.question.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Có câu chưa nhập nội dung')));
        return;
      }
      final keys = q.choices.keys.toSet();
      if (!keys.containsAll({'A', 'B', 'C', 'D'})) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mỗi câu phải có 4 phương án A,B,C,D')));
        return;
      }
      if (!{'A', 'B', 'C', 'D'}.contains(q.answer)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đáp án phải là A/B/C/D')));
        return;
      }
    }
    Navigator.of(context).pop(_ex);
  }

  Widget _buildQuestionEditor(int idx) {
    final q = _ex.questions[idx];
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextFormField(
            initialValue: q.question,
            decoration: InputDecoration(labelText: 'Câu ${idx + 1}'),
            onChanged: (v) => q.question = v,
            validator: (s) => (s == null || s.trim().isEmpty) ? 'Nhập câu hỏi' : null,
          ),
          const SizedBox(height: 8),
          for (final key in ['A', 'B', 'C', 'D'])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                SizedBox(width: 28, child: Text('$key.')),
                Expanded(
                  child: TextFormField(
                    initialValue: q.choices[key] ?? '',
                    decoration: InputDecoration(hintText: 'Phương án $key'),
                    onChanged: (v) => q.choices[key] = v,
                    validator: (s) => (s == null || s.trim().isEmpty) ? 'Nhập đáp án $key' : null,
                  ),
                ),
              ]),
            ),
          const SizedBox(height: 8),
          Row(children: [
            const Text('Đáp án đúng:'),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: q.answer,
              items: ['A', 'B', 'C', 'D'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) {
                if (v != null) setState(() => q.answer = v);
              },
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                initialValue: q.explanation ?? '',
                decoration: const InputDecoration(labelText: 'Giải thích (tùy chọn)'),
                onChanged: (v) => q.explanation = v,
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_ex.questions.length < 20) {
      for (int i = _ex.questions.length; i < 20; i++) {
        _ex.questions.add(QuestionItem(id: i + 1, question: 'Câu ${i + 1}', choices: {'A': '', 'B': '', 'C': '', 'D': ''}, answer: 'A'));
      }
    } else if (_ex.questions.length > 20) {
      _ex.questions = _ex.questions.sublist(0, 20);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? 'Tạo bài mới' : 'Sửa bài'),
        actions: [
          TextButton(onPressed: _saveAndReturn, child: const Text('Lưu', style: TextStyle(color: Colors.white))),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            TextFormField(
              initialValue: _ex.title,
              decoration: const InputDecoration(labelText: 'Tiêu đề bài'),
              onChanged: (v) => _ex.title = v,
              validator: (s) => (s == null || s.trim().isEmpty) ? 'Nhập tiêu đề' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: _ex.instructions,
              decoration: const InputDecoration(labelText: 'Hướng dẫn'),
              onChanged: (v) => _ex.instructions = v,
            ),
            const SizedBox(height: 12),
            const Text('Các câu hỏi (phải có đúng 20 câu)', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...List.generate(20, (i) => _buildQuestionEditor(i)),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: ElevatedButton(onPressed: _saveAndReturn, child: const Text('Lưu và thoát'))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton(onPressed: () {
                setState(() {
                  _ex.questions = List.generate(20, (i) => QuestionItem(id: i + 1, question: 'Câu ${i + 1}', choices: {'A': '', 'B': '', 'C': '', 'D': ''}, answer: 'A'));
                });
              }, child: const Text('Reset câu'))),
            ]),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
