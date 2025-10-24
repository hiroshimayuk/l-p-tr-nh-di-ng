import 'package:flutter/material.dart';
import '../models/quiz_models.dart';
import '../services/quiz_storage_service.dart';
import 'quiz_from_pack_page.dart';

class QuizPackExercisesPage extends StatefulWidget {
  final String assetPath;
  final String? title;
  const QuizPackExercisesPage({super.key, required this.assetPath, this.title});

  @override
  State<QuizPackExercisesPage> createState() => _QuizPackExercisesPageState();
}

class _QuizPackExercisesPageState extends State<QuizPackExercisesPage> {
  final QuizStorageService _store = QuizStorageService();
  QuizPack? _pack;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPack();
  }

  Future<void> _loadPack() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p = await _store.loadPack(widget.assetPath);
      if (!mounted) return;
      setState(() {
        _pack = p;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Không thể load file quiz';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? (_pack?.level ?? 'Quiz pack')),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadPack),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : _pack == null
          ? const Center(child: Text('Không có dữ liệu'))
          : Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mức: ${_pack!.level}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Tổng bài: ${_pack!.exercises.length}, Tổng câu: ${_pack!.exercises.fold<int>(0, (p,e) => p + e.questions.length)}'),
            const SizedBox(height: 12),
            const Text('Chọn bài để làm', style: TextStyle(fontSize: 15)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                itemCount: _pack!.exercises.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (ctx, idx) {
                  final ex = _pack!.exercises[idx];
                  return ListTile(
                    title: Text(ex.title),
                    subtitle: Text('${ex.questions.length} câu • ${ex.instructions}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => QuizFromPackPage(assetPath: widget.assetPath, exerciseId: ex.id)));
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final all = <QuestionItem>[];
                  for (final e in _pack!.exercises) {
                    all.addAll(e.questions);
                  }
                  Navigator.push(context, MaterialPageRoute(builder: (_) => QuizFromPackPage(assetPath: widget.assetPath, questionsOverride: all)));
                },
                child: const Text('Làm toàn bộ các câu (tất cả bài)'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
