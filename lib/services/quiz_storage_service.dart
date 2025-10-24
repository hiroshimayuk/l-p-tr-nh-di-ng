import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../models/quiz_models.dart';

class QuizStorageService {
  Future<QuizPack> loadPack(String assetPath) async {
    final f = await _userFileForAsset(assetPath);
    if (await f.exists()) {
      final s = await f.readAsString();
      final Map<String, dynamic> j = json.decode(s) as Map<String, dynamic>;
      return QuizPack.fromJson(j);
    } else {
      final s = await rootBundle.loadString(assetPath);
      final Map<String, dynamic> j = json.decode(s) as Map<String, dynamic>;
      return QuizPack.fromJson(j);
    }
  }

  Future<void> savePack(String assetPath, QuizPack pack) async {
    final f = await _userFileForAsset(assetPath);
    final j = json.encode(pack.toJson());
    await f.writeAsString(j, flush: true);
  }

  Future<void> deleteUserPack(String assetPath) async {
    final f = await _userFileForAsset(assetPath);
    if (await f.exists()) await f.delete();
  }

  Future<File> _userFileForAsset(String assetPath) async {
    final dir = await getApplicationDocumentsDirectory();
    final name = assetPath.split('/').last;
    return File('${dir.path}/$name');
  }

  // Helpers to add/edit/delete exercises
  Future<void> addExercise(String assetPath, Exercise ex) async {
    final pack = await loadPack(assetPath);
    final maxId = pack.exercises.fold<int>(0, (p, e) => e.id > p ? e.id : p);
    ex.id = maxId + 1;
    pack.exercises.add(ex);
    await savePack(assetPath, pack);
  }

  Future<void> editExercise(String assetPath, Exercise ex) async {
    final pack = await loadPack(assetPath);
    final idx = pack.exercises.indexWhere((e) => e.id == ex.id);
    if (idx >= 0) {
      pack.exercises[idx] = ex;
      await savePack(assetPath, pack);
    } else {
      throw Exception('Exercise not found');
    }
  }

  Future<void> deleteExercise(String assetPath, int exerciseId) async {
    final pack = await loadPack(assetPath);
    pack.exercises.removeWhere((e) => e.id == exerciseId);
    await savePack(assetPath, pack);
  }
}
