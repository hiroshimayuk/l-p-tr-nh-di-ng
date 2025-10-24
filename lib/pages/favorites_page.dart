// lib/pages/favorites_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/vocab.dart';
import '../services/storage_service.dart';
import '../services/auth_service.dart';
import 'detail_page.dart';
import '../services/vocab_service.dart';

class FavoritesPage extends StatefulWidget {
  /// If [favorites] is provided it will be displayed directly.
  /// Otherwise the page will load favorites for the current user.
  final List<Vocab>? favorites;
  const FavoritesPage({Key? key, this.favorites}) : super(key: key);

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  final StorageService _storage = StorageService();
  final VocabService _vocabService = VocabService();
  List<Vocab> _favorites = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.favorites != null) {
      _favorites = List<Vocab>.from(widget.favorites!);
      _loading = false;
    } else {
      _loadFavoritesForUser();
    }
  }

  Future<void> _loadFavoritesForUser() async {
    setState(() {
      _loading = true;
      _favorites = [];
    });

    final auth = context.read<AuthService>();
    final username = auth.currentUsername; // null => guest key

    final favIds = await _storage.loadFavorites(username: username);

    final userVocabs = await _storage.loadUserVocab();
    final found = <Vocab>[];

    for (final id in favIds) {
      final idx = userVocabs.indexWhere((v) => v.id == id);
      if (idx >= 0) found.add(userVocabs[idx]);
    }

    try {
      final base = await _vocabService.loadFromAssets('assets/data/vocabulary_en_vi.json');
      for (final id in favIds) {
        if (found.any((v) => v.id == id)) continue;
        final idx = base.indexWhere((v) => v.id == id);
        if (idx >= 0) found.add(base[idx]);
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _favorites = found;
      _loading = false;
    });
  }

  Future<void> _toggleFavorite(Vocab v) async {
    final auth = context.read<AuthService>();
    final username = auth.currentUsername;
    final ids = await _storage.loadFavorites(username: username);
    final set = ids.toSet();
    if (set.contains(v.id))
      set.remove(v.id);
    else
      set.add(v.id);
    await _storage.saveFavorites(set.toList(), username: username);

    if (mounted) {
      setState(() {
        _favorites.removeWhere((x) => x.id == v.id);
      });
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cập nhật yêu thích')));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final title = auth.isLoggedIn ? 'Yêu thích (${auth.currentUsername})' : 'Yêu thích (guest)';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _favorites.isEmpty
          ? const Center(child: Text('Không có favorites'))
          : ListView.builder(
        itemCount: _favorites.length,
        itemBuilder: (context, i) {
          final v = _favorites[i];
          return ListTile(
            title: Text(v.en),
            subtitle: Text(v.vi),
            trailing: IconButton(
              icon: const Icon(Icons.favorite, color: Colors.redAccent),
              onPressed: () => _toggleFavorite(v),
              tooltip: 'Bỏ yêu thích',
            ),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DetailPage(
                    vocab: v,
                    isFavorite: true,
                    onToggleFav: () async {
                      await _toggleFavorite(v);
                    },
                  ),
                ),
              );
              if (widget.favorites == null) await _loadFavoritesForUser();
            },
          );
        },
      ),
    );
  }
}
