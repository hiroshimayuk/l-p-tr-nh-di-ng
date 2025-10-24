// lib/pages/home_page.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/vocab.dart';
import '../services/vocab_service.dart';
import '../services/storage_service.dart';
import '../services/auth_service.dart';

import 'add_word_page.dart';
import 'detail_page.dart';
import 'flashcard_page.dart';
import 'favorites_page.dart';
import 'quiz_level_select_page.dart';
import 'quiz_pack_exercises_page.dart';
import 'quiz_manage_page.dart';
import 'history_page.dart';
import 'login_page.dart';
import 'settings_page.dart';
import 'profile_page.dart';
import 'user_management_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final VocabService _vocabService = VocabService();
  final StorageService _storage = StorageService();
  final TextEditingController _searchEnController = TextEditingController();
  final TextEditingController _searchViController = TextEditingController();
  final Uuid _uuid = const Uuid();

  List<Vocab> _all = [];
  List<Vocab> _suggestions = [];
  Set<String> _favorites = {};
  bool _loading = true;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchEnController.addListener(() => _onSearchChanged(lang: 'en'));
    _searchViController.addListener(() => _onSearchChanged(lang: 'vi'));
    _initLoadSafe();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadFavoritesForUser();
  }

  @override
  void dispose() {
    _searchEnController.removeListener(() => _onSearchChanged(lang: 'en'));
    _searchViController.removeListener(() => _onSearchChanged(lang: 'vi'));
    _debounce?.cancel();
    _searchEnController.dispose();
    _searchViController.dispose();
    super.dispose();
  }

  Future<void> _initLoadSafe() async {
    try {
      await _initLoad();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _all = [];
        _favorites = {};
        _suggestions = [];
        _loading = false;
      });
    }
  }

  Future<void> _initLoad() async {
    if (!mounted) return;
    setState(() => _loading = true);

    final base = await _vocabService.loadFromAssets('assets/data/vocabulary_en_vi.json');
    final user = await _storage.loadUserVocab();
    final deletedIds = await _storage.loadDeletedIds();
    final merged = _vocabService.merge(base, user).where((v) => !deletedIds.contains(v.id)).toList();
    merged.sort((a, b) => a.en.toLowerCase().compareTo(b.en.toLowerCase()));

    if (!mounted) return;
    setState(() {
      _all = merged;
      _suggestions = [];
      _loading = false;
    });

    await _loadFavoritesForUser();
  }

  // Remove Vietnamese diacritics
  String _removeDiacritics(String str) {
    const withDia =
        'áàảãạăắằẳẵặâấầẩẫậđéèẻẽẹêếềểễệíìỉĩịóòỏõọôốồổỗộơớờởỡợúùủũụưứừửữựýỳỷỹỵÁÀẢÃẠĂẮẰẲẴẶÂẤẦẨẪẬĐÉÈẺẼẸÊẾỀỂỄỆÍÌỈĨỊÓÒỎÕỌÔỐỒỔỖỘƠỚỜỞỠỢÚÙỦŨỤƯỨỪỬỮỰÝỲỶỸỴ';
    const noDia =
        'aaaaaaaaaaaaaaaaadddeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuyyyyyAAAAAAAAAAAAAAAAADDDEEEEEEEEEEEIIIIIOOOOOOOOOOOOOOOOOOUUUUUUUUUUYYYYY';
    for (int i = 0; i < withDia.length; i++) {
      str = str.replaceAll(withDia[i], noDia[i]);
    }
    return str;
  }

  String _normalize(String s) => _removeDiacritics(s.toLowerCase().trim());

  void _onSearchChanged({required String lang}) {
    // Ensure only one search box has text at a time: clear the other
    if (lang == 'en' && _searchEnController.text.trim().isNotEmpty && _searchViController.text.isNotEmpty) {
      _searchViController.clear();
    } else if (lang == 'vi' && _searchViController.text.trim().isNotEmpty && _searchEnController.text.isNotEmpty) {
      _searchEnController.clear();
    }

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), () => _performSearch(lang: lang));

    // Immediate clear suggestions if field is empty
    if ((lang == 'en' && _searchEnController.text.trim().isEmpty) || (lang == 'vi' && _searchViController.text.trim().isEmpty)) {
      if (mounted) setState(() => _suggestions = []);
    }
  }

  void _performSearch({required String lang}) {
    final raw = lang == 'en' ? _searchEnController.text : _searchViController.text;
    final q = raw.trim();
    if (q.isEmpty) {
      if (!mounted) return;
      setState(() => _suggestions = []);
      return;
    }

    final nq = _normalize(q);
    final List<Vocab> starts = [];
    final List<Vocab> contains = [];

    for (final v in _all) {
      final enNorm = _normalize(v.en);
      final viNorm = _normalize(v.vi);
      bool matchStart = false;
      bool matchContain = false;
      if (lang == 'en') {
        matchStart = enNorm.startsWith(nq);
        matchContain = enNorm.contains(nq);
      } else {
        matchStart = viNorm.startsWith(nq);
        matchContain = viNorm.contains(nq);
      }
      if (matchStart)
        starts.add(v);
      else if (matchContain) contains.add(v);
    }

    starts.sort((a, b) => a.en.toLowerCase().compareTo(b.en.toLowerCase()));
    contains.sort((a, b) => a.en.toLowerCase().compareTo(b.en.toLowerCase()));
    final result = <Vocab>[]..addAll(starts)..addAll(contains);
    final limited = result.length > 200 ? result.sublist(0, 200) : result;

    if (!mounted) return;
    setState(() => _suggestions = limited);
  }

  bool _isAdmin() => context.read<AuthService>().isAdmin;

  void _showForbiddenMessage(String action) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Chỉ admin mới được $action')));
  }

  Future<void> _addVocab(String en, String vi) async {
    if (!_isAdmin()) {
      _showForbiddenMessage('thêm từ');
      return;
    }
    final v = Vocab(id: _uuid.v4(), en: en.trim(), vi: vi.trim(), userAdded: true);
    final userList = await _storage.loadUserVocab();
    userList.add(v);
    await _storage.saveUserVocab(userList);
    await _initLoad();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã lưu từ mới')));
  }

  Future<void> _editVocab(Vocab original, String newEn, String newVi) async {
    if (!_isAdmin()) {
      _showForbiddenMessage('sửa từ');
      return;
    }
    final userList = await _storage.loadUserVocab();
    final idx = userList.indexWhere((e) => e.id == original.id);
    final updated = Vocab(id: original.id, en: newEn.trim(), vi: newVi.trim(), userAdded: true);
    if (idx >= 0)
      userList[idx] = updated;
    else
      userList.add(updated);
    await _storage.saveUserVocab(userList);
    await _initLoad();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã sửa từ')));
  }

  Future<void> _deleteVocab(Vocab v) async {
    if (!_isAdmin()) {
      _showForbiddenMessage('xóa từ');
      return;
    }
    final userList = await _storage.loadUserVocab();
    userList.removeWhere((e) => e.id == v.id);
    await _storage.saveUserVocab(userList);

    final deletedIds = await _storage.loadDeletedIds();
    if (!deletedIds.contains(v.id)) {
      deletedIds.add(v.id);
      await _storage.saveDeletedIds(deletedIds);
    }

    final auth = context.read<AuthService>();
    final username = auth.currentUsername;
    final favs = Set<String>.from(await _storage.loadFavorites(username: username));
    if (favs.remove(v.id)) await _storage.saveFavorites(favs.toList(), username: username);

    await _initLoad();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xóa từ')));
  }

  Future<void> _loadFavoritesForUser() async {
    final auth = context.read<AuthService>();
    final username = auth.currentUsername;
    final ids = await _storage.loadFavorites(username: username);
    if (!mounted) return;
    setState(() => _favorites = ids.toSet());
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
    if (!mounted) return;
    setState(() {
      if (set.contains(v.id))
        _favorites.add(v.id);
      else
        _favorites.remove(v.id);
    });
  }

  Future<void> _openAddPage() async {
    if (!_isAdmin()) {
      _showForbiddenMessage('thêm từ');
      return;
    }
    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddWordPage()));
    if (result is Map<String, String>) {
      final en = result['en'] ?? '';
      final vi = result['vi'] ?? '';
      if (en.isNotEmpty && vi.isNotEmpty) await _addVocab(en, vi);
    }
  }

  void _openFavorites() {
    final favList = _all.where((v) => _favorites.contains(v.id)).toList();
    Navigator.push(context, MaterialPageRoute(builder: (_) => FavoritesPage(favorites: favList)));
  }

  void _openFlashcard() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => FlashcardPage(all: _all)));
  }

  void _openQuizLevelSelect() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const QuizLevelSelectPage()));
  }

  void _openQuizManage(String assetPath, String title) {
    if (!_isAdmin()) {
      _showForbiddenMessage('quản lý quiz');
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => QuizManagePage(assetPath: assetPath, title: title)));
  }

  void _openHistory() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryPage()));
  }

  void _showQuizBottomSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(
                title: const Text('Làm quiz - Nhập môn'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  Navigator.push(ctx, MaterialPageRoute(builder: (_) => QuizPackExercisesPage(assetPath: 'assets/data/bai_tap_tieng_anh_nhap_mon.json', title: 'Nhập môn')));
                },
              ),
              ListTile(
                title: const Text('Làm quiz - Trung cấp'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  Navigator.push(ctx, MaterialPageRoute(builder: (_) => QuizPackExercisesPage(assetPath: 'assets/data/bai_tap_tieng_anh_trung_cap.json', title: 'Trung cấp')));
                },
              ),
              ListTile(
                title: const Text('Làm quiz - Nâng cao'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  Navigator.push(ctx, MaterialPageRoute(builder: (_) => QuizPackExercisesPage(assetPath: 'assets/data/bai_tap_tieng_anh_nang_cao.json', title: 'Nâng cao')));
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.manage_accounts),
                title: const Text('Quản lý Quiz - Nhập môn'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _openQuizManage('assets/data/bai_tap_tieng_anh_nhap_mon.json', 'Quản lý Nhập môn');
                },
              ),
              ListTile(
                leading: const Icon(Icons.manage_accounts),
                title: const Text('Quản lý Quiz - Trung cấp'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _openQuizManage('assets/data/bai_tap_tieng_anh_trung_cap.json', 'Quản lý Trung cấp');
                },
              ),
              ListTile(
                leading: const Icon(Icons.manage_accounts),
                title: const Text('Quản lý Quiz - Nâng cao'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _openQuizManage('assets/data/bai_tap_tieng_anh_nang_cao.json', 'Quản lý Nâng cao');
                },
              ),
              const SizedBox(height: 8),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildEmptyHint() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: const [
        Icon(Icons.search, size: 56, color: Colors.grey),
        SizedBox(height: 12),
        Text('Nhập ký tự tiếng Anh hoặc tiếng Việt để tìm từ', style: TextStyle(color: Colors.grey)),
      ]),
    );
  }

  Future<void> _showEditDialog(BuildContext ctx, Vocab v) async {
    if (!_isAdmin()) {
      _showForbiddenMessage('sửa từ');
      return;
    }

    final enCtrl = TextEditingController(text: v.en);
    final viCtrl = TextEditingController(text: v.vi);
    final formKey = GlobalKey<FormState>();

    final res = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Sửa từ'),
        content: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(controller: enCtrl, decoration: const InputDecoration(labelText: 'English'), validator: (s) => (s == null || s.trim().isEmpty) ? 'Nhập từ' : null),
            const SizedBox(height: 8),
            TextFormField(controller: viCtrl, decoration: const InputDecoration(labelText: 'Tiếng Việt'), validator: (s) => (s == null || s.trim().isEmpty) ? 'Nhập nghĩa' : null),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Hủy')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Lưu')),
        ],
      ),
    );

    if (res == true) await _editVocab(v, enCtrl.text, viCtrl.text);
    enCtrl.dispose();
    viCtrl.dispose();
  }

  Future<void> _confirmDelete(BuildContext ctx, Vocab v) async {
    if (!_isAdmin()) {
      _showForbiddenMessage('xóa từ');
      return;
    }

    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Xác nhận'),
        content: Text('Bạn có chắc muốn xóa "${v.en}" không?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Hủy')),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Xóa')),
        ],
      ),
    );

    if (ok == true) await _deleteVocab(v);
  }

  Future<void> _openLogin() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginPage()));
    if (!mounted) return;
    await _loadFavoritesForUser();
  }

  Future<void> _logout() async {
    final auth = context.read<AuthService>();
    await auth.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginPage()), (r) => false);
  }

  void _onAccountMenuSelected(String value) async {
    final auth = context.read<AuthService>();
    if (value == 'login') {
      await _openLogin();
    } else if (value == 'logout') {
      await _logout();
    } else if (value == 'settings') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()));
    } else if (value == 'manage_accounts') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const UserManagementPage()));
    } else if (value == 'profile') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vocab Demo'),
        actions: [
          IconButton(icon: const Icon(Icons.history), onPressed: _openHistory, tooltip: 'Lịch sử làm bài'),
          IconButton(icon: const Icon(Icons.favorite), onPressed: _openFavorites, tooltip: 'Yêu thích'),
          IconButton(icon: const Icon(Icons.casino), onPressed: _openFlashcard, tooltip: 'Flashcard'),
          IconButton(icon: const Icon(Icons.quiz), onPressed: _showQuizBottomSheet, tooltip: 'Quiz'),
          if (auth.isAdmin) IconButton(icon: const Icon(Icons.add), onPressed: _openAddPage, tooltip: 'Thêm từ'),
          // Account popup menu
          PopupMenuButton<String>(
            tooltip: auth.isLoggedIn ? 'Tài khoản (${auth.currentUser?.username})' : 'Tài khoản',
            icon: Icon(auth.isLoggedIn ? Icons.account_circle : Icons.login),
            onSelected: _onAccountMenuSelected,
            itemBuilder: (context) {
              final List<PopupMenuEntry<String>> items = [];
              if (auth.isLoggedIn) {
                items.add(PopupMenuItem(value: 'profile', child: Text('Tài khoản: ${auth.currentUser?.username}')));
                items.add(const PopupMenuDivider());
                items.add(const PopupMenuItem(value: 'settings', child: Text('Cài đặt')));
                items.add(const PopupMenuItem(value: 'logout', child: Text('Đăng xuất')));
                if (auth.isAdmin) {
                  items.add(const PopupMenuDivider());
                  items.add(const PopupMenuItem(value: 'manage_accounts', child: Text('Quản lý tài khoản')));
                }
              } else {
                items.add(const PopupMenuItem(value: 'login', child: Text('Đăng nhập')));
                items.add(const PopupMenuItem(value: 'settings', child: Text('Cài đặt')));
              }
              return items;
            },
          ),
          if (auth.isAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings),
              tooltip: 'Quản lý Quiz',
              onPressed: () => _openQuizManage('assets/data/bai_tap_tieng_anh_nhap_mon.json', 'Quản lý Quiz'),
            ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _searchEnController,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Tìm tiếng Anh (ví dụ: apple)',
                  border: const OutlineInputBorder(),
                  suffixIcon: _searchEnController.text.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchEnController.clear();
                      if (mounted) setState(() => _suggestions = []);
                    },
                  )
                      : null,
                ),
                onSubmitted: (_) => _performSearch(lang: 'en'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchViController,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Tìm tiếng Việt (ví dụ: táo)',
                  border: const OutlineInputBorder(),
                  suffixIcon: _searchViController.text.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchViController.clear();
                      if (mounted) setState(() => _suggestions = []);
                    },
                  )
                      : null,
                ),
                onSubmitted: (_) => _performSearch(lang: 'vi'),
              ),
            ),
          ]),
        ),
        Expanded(
          child: (_searchEnController.text.trim().isEmpty && _searchViController.text.trim().isEmpty)
              ? _buildEmptyHint()
              : _suggestions.isEmpty
              ? const Center(child: Text('Không tìm thấy từ phù hợp'))
              : ListView.separated(
            itemCount: _suggestions.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, idx) {
              final v = _suggestions[idx];
              final isFav = _favorites.contains(v.id);
              return ListTile(
                title: Text(v.en),
                subtitle: Text(v.vi),
                leading: IconButton(
                  icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Colors.red : null),
                  onPressed: () => _toggleFavorite(v),
                ),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (auth.isAdmin) IconButton(icon: const Icon(Icons.edit), tooltip: 'Sửa', onPressed: () => _showEditDialog(context, v)),
                  if (auth.isAdmin) IconButton(icon: const Icon(Icons.delete), tooltip: 'Xóa', onPressed: () => _confirmDelete(context, v)),
                ]),
                onTap: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => DetailPage(vocab: v, isFavorite: isFav, onToggleFav: () => _toggleFavorite(v))));
                  await _loadFavoritesForUser();
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}
