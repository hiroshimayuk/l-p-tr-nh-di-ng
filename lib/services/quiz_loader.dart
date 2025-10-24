import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/quiz_models.dart';

class QuizLoader {
  Future<QuizPack> loadFromAsset(String assetPath) async {
    final s = await rootBundle.loadString(assetPath);
    final Map<String,dynamic> j = json.decode(s) as Map<String,dynamic>;
    return QuizPack.fromJson(j);
  }
}
