// lib/pages/history_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/storage_service.dart';
import '../services/auth_service.dart';
import '../models/quiz_result.dart';
import 'history_detail_page.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final StorageService _storage = StorageService();
  List<QuizResult> _history = [];
  bool _loading = true;
  String? _ownerUsername; // current username used for display

  @override
  void initState() {
    super.initState();
    _loadForCurrentUser();
  }

  Future<void> _loadForCurrentUser() async {
    setState(() {
      _loading = true;
      _history = [];
    });

    final auth = context.read<AuthService>();
    final username = auth.currentUsername;
    _ownerUsername = username ?? 'guest';
    final list = await _storage.loadQuizHistory(username: username);
    if (!mounted) return;
    setState(() {
      _history = list.reversed.toList(); // newest first
      _loading = false;
    });
  }

  Future<void> _clearHistory() async {
    final auth = context.read<AuthService>();
    final username = auth.currentUsername;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xác nhận'),
        content: const Text('Xóa toàn bộ lịch sử của bạn?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Hủy')),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Xóa')),
        ],
      ),
    );
    if (confirm != true) return;
    await _storage.clearQuizHistory(username: username);
    await _loadForCurrentUser();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Lịch sử làm bài (${_ownerUsername ?? ''})'),
        actions: [
          if (!auth.isLoggedIn)
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đăng nhập để lưu lịch sử theo tài khoản')));
              },
            ),
          IconButton(icon: const Icon(Icons.delete_sweep), onPressed: _clearHistory, tooltip: 'Xóa lịch sử'),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
          ? const Center(child: Text('Chưa có lịch sử'))
          : ListView.separated(
        itemCount: _history.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, idx) {
          final r = _history[idx];
          return ListTile(
            title: Text(r.quizTitle),
            subtitle: Text('${r.correctAnswers} / ${r.totalQuestions} — ${r.timestamp.toLocal()}'),
            trailing: Text('${(r.score * 100).toStringAsFixed(0)}%'),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => HistoryDetailPage(result: r))),
          );
        },
      ),
    );
  }
}
