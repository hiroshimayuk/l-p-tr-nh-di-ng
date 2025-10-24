// lib/pages/quiz_from_pack_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/quiz_models.dart';
import '../models/quiz_result.dart';
import '../models/quiz_exercise_attempt.dart';
import '../services/quiz_storage_service.dart';
import '../services/storage_service.dart';
import '../services/auth_service.dart';
import 'history_detail_page.dart';

class QuizFromPackPage extends StatefulWidget {
  final String assetPath;
  final int? exerciseId;
  final List<QuestionItem>? questionsOverride;
  final int questionCount;

  const QuizFromPackPage({
    super.key,
    required this.assetPath,
    this.exerciseId,
    this.questionsOverride,
    this.questionCount = 10,
  });

  @override
  State<QuizFromPackPage> createState() => _QuizFromPackPageState();
}

class _QuizFromPackPageState extends State<QuizFromPackPage> {
  final QuizStorageService _store = QuizStorageService();
  final StorageService _storage = StorageService();

  List<QuestionItem> _qs = [];
  Map<int, String> _answers = {};
  bool _loading = true;
  bool _submitted = false;
  int _score = 0;

  @override
  void initState() {
    super.initState();
    _prepareQuestions();
  }

  Future<void> _prepareQuestions() async {
    setState(() {
      _loading = true;
      _submitted = false;
      _answers = {};
      _score = 0;
      _qs = [];
    });

    try {
      if (widget.questionsOverride != null) {
        _qs = List<QuestionItem>.from(widget.questionsOverride!);
      } else {
        final pack = await _store.loadPack(widget.assetPath);
        if (widget.exerciseId != null) {
          final ex = pack.exercises.firstWhere(
                (e) => e.id == widget.exerciseId,
            orElse: () => Exercise(id: 0, title: '', instructions: '', questions: []),
          );
          _qs = List<QuestionItem>.from(ex.questions);
        } else {
          final all = <QuestionItem>[];
          for (final e in pack.exercises) {
            all.addAll(e.questions);
          }
          all.shuffle();
          final takeCount = widget.questionCount.clamp(1, all.length);
          _qs = all.take(takeCount).toList();
        }
      }
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _qs = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không thể load quiz từ file')));
    }
  }

  void _selectAnswer(QuestionItem q, String choiceKey) {
    if (_submitted) return;
    setState(() {
      _answers[q.id] = choiceKey;
    });
  }

  Future<void> _submit() async {
    if (_submitted) return;

    final unanswered = _qs.where((q) => !_answers.containsKey(q.id)).toList();
    if (unanswered.isNotEmpty) {
      final cnt = unanswered.length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bạn chưa trả lời $cnt câu. Vui lòng hoàn tất hoặc bấm Nộp vẫn tiếp tục.')),
      );
    }

    int correct = 0;
    for (final q in _qs) {
      final picked = _answers[q.id];
      if (picked != null && picked.toUpperCase() == q.answer.toUpperCase()) correct++;
    }

    setState(() {
      _submitted = true;
      _score = correct;
    });

    // Build userAnswers map with string keys for persistence
    final Map<String, String> userAnswersMap = {};
    for (final q in _qs) {
      final picked = _answers[q.id];
      if (picked != null) userAnswersMap[q.id.toString()] = picked;
    }

    final attempt = QuizExerciseAttempt(questions: _qs, userAnswers: userAnswersMap);
    final title = widget.exerciseId != null
        ? 'Bài ${widget.exerciseId}'
        : 'Quiz ${widget.assetPath.split('/').last}';
    final result = QuizResult.create(
      quizTitle: title,
      totalQuestions: _qs.length,
      correctAnswers: correct,
      attemptDetails: attempt,
    );

    // Save history per-user (use AuthService)
    final auth = context.read<AuthService>();
    final username = auth.currentUsername; // may be null -> guest
    try {
      await _storage.appendQuizHistory(result, username: username);
    } catch (_) {
      // ignore storage error
    }

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kết quả'),
        content: Text('Đúng $correct / ${_qs.length}  (${(result.score * 100).toStringAsFixed(0)}%)'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Đóng')),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => HistoryDetailPage(result: result, isImmediateResult: true),
              ));
            },
            child: const Text('Xem chi tiết'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(QuestionItem q, int idx) {
    final picked = _answers[q.id];
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Câu ${idx + 1}: ${q.question}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...q.choices.entries.map((e) {
            final key = e.key;
            final text = e.value;
            final selected = picked == key;
            Color? bg;
            Widget trailing = const SizedBox.shrink();
            if (!_submitted) {
              if (selected) bg = const Color.fromRGBO(33, 150, 243, 0.08);
            } else {
              if (key.toUpperCase() == q.answer.toUpperCase()) {
                bg = const Color.fromRGBO(76, 175, 80, 0.18);
                trailing = const Icon(Icons.check_circle, color: Colors.green);
              } else if (selected && key.toUpperCase() != q.answer.toUpperCase()) {
                bg = const Color.fromRGBO(244, 67, 54, 0.18);
                trailing = const Icon(Icons.cancel, color: Colors.red);
              }
            }
            return InkWell(
              onTap: () => _selectAnswer(q, key),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                margin: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: selected ? Colors.blue : Colors.transparent),
                ),
                child: Row(
                  children: [
                    Text('$key. ', style: const TextStyle(fontWeight: FontWeight.w600)),
                    Expanded(child: Text(text)),
                    trailing,
                  ],
                ),
              ),
            );
          }).toList(),
          const SizedBox(height: 8),
          if (_submitted) ...[
            const Divider(),
            Text('Đáp án đúng: ${q.answer}. ${q.choices[q.answer] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            if (q.explanation != null && q.explanation!.trim().isNotEmpty)
              Text('Giải thích: ${q.explanation}', style: const TextStyle(color: Colors.black87)),
          ],
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_qs.isEmpty) return Scaffold(appBar: AppBar(title: const Text('Quiz')), body: const Center(child: Text('Không có câu hỏi')));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.exerciseId != null ? 'Bài tập' : 'Quiz'),
        actions: [
          if (!_submitted) TextButton(onPressed: _submit, child: const Text('Nộp', style: TextStyle(color: Colors.white))),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          if (_submitted)
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Text('Kết quả: ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Text('$_score / ${_qs.length}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: () {
                        final attempt = QuizExerciseAttempt(
                          questions: _qs,
                          userAnswers: {for (var e in _qs) if (_answers[e.id] != null) e.id.toString(): _answers[e.id]!},
                        );
                        final result = QuizResult.create(
                          quizTitle: widget.exerciseId != null ? 'Bài ${widget.exerciseId}' : 'Quiz ${widget.assetPath.split('/').last}',
                          totalQuestions: _qs.length,
                          correctAnswers: _score,
                          attemptDetails: attempt,
                        );
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => HistoryDetailPage(result: result, isImmediateResult: true)));
                      },
                      child: const Text('Xem lại'),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: _qs.length,
              itemBuilder: (_, idx) => _buildQuestionCard(_qs[idx], idx),
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _submitted ? () => Navigator.of(context).pop() : _submit,
                child: Text(_submitted ? 'Hoàn tất' : 'Nộp'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _answers = {};
                    _submitted = false;
                    _score = 0;
                  });
                },
                child: const Text('Làm lại'),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
