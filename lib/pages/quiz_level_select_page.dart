import 'package:flutter/material.dart';
import 'quiz_pack_exercises_page.dart';

class QuizLevelSelectPage extends StatelessWidget {
  const QuizLevelSelectPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chọn mức Quiz')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            const Text('Chọn mức độ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _levelButton(context, 'Nhập môn', 'assets/data/bai_tap_tieng_anh_nhap_mon.json'),
            const SizedBox(height: 8),
            _levelButton(context, 'Trung cấp', 'assets/data/bai_tap_tieng_anh_trung_cap.json'),
            const SizedBox(height: 8),
            _levelButton(context, 'Nâng cao', 'assets/data/bai_tap_tieng_anh_nang_cao.json'),
          ],
        ),
      ),
    );
  }

  Widget _levelButton(BuildContext ctx, String title, String asset) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => QuizPackExercisesPage(assetPath: asset, title: title))),
        child: Text(title),
      ),
    );
  }
}
