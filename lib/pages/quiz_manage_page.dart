import 'package:flutter/material.dart';
import '../models/quiz_models.dart';
import '../services/quiz_storage_service.dart';
import 'quiz_edit_exercise_page.dart';
import 'quiz_from_pack_page.dart';

class QuizManagePage extends StatefulWidget {
  final String assetPath;
  final String title;
  const QuizManagePage({super.key, required this.assetPath, required this.title});

  @override
  State<QuizManagePage> createState() => _QuizManagePageState();
}

class _QuizManagePageState extends State<QuizManagePage> {
  final QuizStorageService _storage = QuizStorageService();
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
      final p = await _storage.loadPack(widget.assetPath);
      if (!mounted) return;
      setState(() {
        _pack = p;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Không load được pack';
        _loading = false;
      });
    }
  }

  Future<void> _onAdd() async {
    final ex = Exercise(
      id: 0,
      title: 'Bài mới',
      instructions: 'Chọn đáp án',
      questions: List.generate(20, (i) => QuestionItem(id: i + 1, question: 'Câu ${i + 1}', choices: {'A': '', 'B': '', 'C': '', 'D': ''}, answer: 'A')),
    );
    final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => QuizEditExercisePage(exercise: ex, isNew: true)));
    if (res is Exercise) {
      await _storage.addExercise(widget.assetPath, res);
      await _loadPack();
    }
  }

  Future<void> _onEdit(Exercise ex) async {
    final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => QuizEditExercisePage(exercise: ex, isNew: false)));
    if (res is Exercise) {
      await _storage.editExercise(widget.assetPath, res);
      await _loadPack();
    }
  }

  Future<void> _onDelete(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc muốn xóa bài này?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xóa')),
        ],
      ),
    );
    if (ok == true) {
      await _storage.deleteExercise(widget.assetPath, id);
      await _loadPack();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          actions: [
            IconButton(icon: const Icon(Icons.refresh), onPressed: _loadPack),
            IconButton(icon: const Icon(Icons.add), onPressed: _onAdd),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(child: Text(_error!))
            : Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Expanded(
                child: ListView.separated(
                  itemCount: _pack!.exercises.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (_, idx) {
                    final ex = _pack!.exercises[idx];
                    return ListTile(
                      title: Text(ex.title),
                      subtitle: Text('${ex.questions.length} câu • ${ex.instructions}'),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(icon: const Icon(Icons.edit), onPressed: () => _onEdit(ex)),
                        IconButton(icon: const Icon(Icons.delete), onPressed: () => _onDelete(ex.id)),
                      ]),
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => QuizFromPackPage(assetPath: widget.assetPath, exerciseId: ex.id)));
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: ElevatedButton(onPressed: () async {
                  await _storage.deleteUserPack(widget.assetPath);
                  await _loadPack();
                }, child: const Text('Khôi phục gốc'))),
              ]),
            ],
          ),
        ));
  }
}
