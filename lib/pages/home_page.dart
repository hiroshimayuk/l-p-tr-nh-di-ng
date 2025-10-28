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
import 'settings_page.dart'; // Giữ nguyên import nếu nó được dùng ở chỗ khác
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
  // Biến để theo dõi xem người dùng đang tìm kiếm hay không
  bool get _isSearching => _searchEnController.text.trim().isNotEmpty || _searchViController.text.trim().isNotEmpty;

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
        'áàảãạăắằẳẵặâấầẩẫậđéèẻẽẹêếềểễệíìỉĩịóòỏõọôốồổỗộơớờởỡợúùủũụưứừửữựýỳỷỹỵÁÀẢÃẠĂẮẰẲẴẶÂẤẦẨẪẬĐÉẺẼẸÊẾỀỂỄỆÍÌỈỊÓÒỎÕỌÔỐỒỔỖỘƠỚỜỞỠỢÚÙỦŨỤƯỨỪỮỰÝỲỶỸỴ';
    const noDia =
        'aaaaaaaaaaaaaaaaadddeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuyyyyyAAAAAAAAAAAAAAAAADDDEEEEEEEEEEEIIIIIOOOOOOOOOOOOOOOOOOUUUUUUUUUUYYYYY';
    for (int i = 0; i < withDia.length; i++) {
      str = str.replaceAll(withDia[i], noDia[i]);
    }
    return str;
  }

  String _normalize(String s) => _removeDiacritics(s.toLowerCase().trim());

  void _onSearchChanged({required String lang}) {
    if (lang == 'en' && _searchEnController.text.trim().isNotEmpty && _searchViController.text.isNotEmpty) {
      _searchViController.clear();
    } else if (lang == 'vi' && _searchViController.text.trim().isNotEmpty && _searchEnController.text.isNotEmpty) {
      _searchEnController.clear();
    }

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), () => _performSearch(lang: lang));

    if ((lang == 'en' && _searchEnController.text.trim().isEmpty) && (lang == 'vi' && _searchViController.text.trim().isEmpty)) {
      if (mounted) setState(() => _suggestions = []);
    }
    if (mounted) setState(() {});
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
  bool _isLoggedIn() => context.read<AuthService>().isLoggedIn;

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
              // Nút Quiz theo cấp độ (Làm quiz) - DÀNH CHO TẤT CẢ USER
              if (!_isAdmin()) ...[
                ListTile(
                  leading: const Icon(Icons.school, color: Colors.green),
                  title: const Text('Làm quiz - Nhập môn'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    Navigator.push(ctx, MaterialPageRoute(builder: (_) => QuizPackExercisesPage(assetPath: 'assets/data/bai_tap_tieng_anh_nhap_mon.json', title: 'Nhập môn')));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.trending_up, color: Colors.orange),
                  title: const Text('Làm quiz - Trung cấp'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    Navigator.push(ctx, MaterialPageRoute(builder: (_) => QuizPackExercisesPage(assetPath: 'assets/data/bai_tap_tieng_anh_trung_cap.json', title: 'Trung cấp')));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.rocket_launch, color: Colors.red),
                  title: const Text('Làm quiz - Nâng cao'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    Navigator.push(ctx, MaterialPageRoute(builder: (_) => QuizPackExercisesPage(assetPath: 'assets/data/bai_tap_tieng_anh_nang_cao.json', title: 'Nâng cao')));
                  },
                ),
                const Divider(),
              ],

              // 🚨 QUẢN LÝ QUIZ: CHỈ HIỂN THỊ KHI LÀ ADMIN
              if (_isAdmin()) ...[
                ListTile(
                  leading: const Icon(Icons.manage_accounts, color: Colors.blue),
                  title: const Text('Quản lý Quiz - Nhập môn'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _openQuizManage('assets/data/bai_tap_tieng_anh_nhap_mon.json', 'Quản lý Quiz (Nhập môn)');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.manage_accounts, color: Colors.blue),
                  title: const Text('Quản lý Quiz - Trung cấp'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _openQuizManage('assets/data/bai_tap_tieng_anh_trung_cap.json', 'Quản lý Quiz (Trung cấp)');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.manage_accounts, color: Colors.blue),
                  title: const Text('Quản lý Quiz - Nâng cao'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _openQuizManage('assets/data/bai_tap_tieng_anh_nang_cao.json', 'Quản lý Quiz (Nâng cao)');
                  },
                ),
              ],
              const SizedBox(height: 8),
            ]),
          ),
        );
      },
    );
  }

  // --- Widget Mới: Logo và Tên ứng dụng trên Body ---
  Widget _buildWelcomeLogo(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Logo hình tròn (Sử dụng Image.asset)
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/logo.png', // <-- ĐƯỜNG DẪN LOGO TỪ ASSETS
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.translate, // Fallback icon
                      size: 48,
                      color: theme.colorScheme.secondary,
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Tên ứng dụng
            Text(
              'FOUR ROCK',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color: theme.primaryColor,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Từ điển Anh-Việt nhanh chóng và hiệu quả',
              style: TextStyle(color: Colors.black54, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            const Text(
              'Nhập ký tự tiếng Anh hoặc tiếng Việt để tìm từ',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
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
        title: const Text('Xác nhận Xóa'),
        content: Text('Bạn có chắc muốn xóa vĩnh viễn từ "${v.en}" không?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
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
      // 🚨 SỬA LẠI LOGIC SETTINGS THÀNH PROFILE
    } else if (value == 'settings') {
      // Logic cũ của Settings (đã bị xóa)
      // Nếu không có SettingsPage, chuyển đến ProfilePage
      Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage()));
    } else if (value == 'manage_accounts') {
      if (!auth.isAdmin) {
        _showForbiddenMessage('quản lý tài khoản');
        return;
      }
      Navigator.push(context, MaterialPageRoute(builder: (_) => const UserManagementPage()));
    } else if (value == 'profile') {
      // Logic của Profile
      Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage()));
    }
  }

  // --- Widget Mới: Gộp Search Box ---
  Widget _buildSearchFields() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              // Search English
              TextField(
                controller: _searchEnController,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.abc, color: Colors.blue),
                  hintText: 'Tìm từ tiếng Anh (ví dụ: apple)',
                  border: InputBorder.none,
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
              const Divider(height: 1),
              // Search Vietnamese
              TextField(
                controller: _searchViController,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.translate, color: Colors.green),
                  hintText: 'Tìm tiếng Việt (ví dụ: táo)',
                  border: InputBorder.none,
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
            ],
          ),
        ),
      ),
    );
  }

  // --- Widget Mới: Drawer ---
  Widget _buildDrawer(AuthService auth) {
    final theme = Theme.of(context);
    final usernameDisplay = auth.isLoggedIn ? auth.currentUser?.username ?? 'Người dùng' : 'Khách';
    final isUser = !auth.isAdmin; // Xác định user thường hoặc khách

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          // BẮT ĐẦU: PHẦN HEADER MỚI CÓ LOGO (ẢNH) VÀ TÊN APP
          DrawerHeader(
            decoration: BoxDecoration(
              color: theme.primaryColor,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Logo hình tròn (Sử dụng Image.asset)
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/logo.png', // <-- Đường dẫn ảnh logo
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        // Dùng Icon dự phòng thân thiện thay vì Icon lỗi màu đỏ
                        return Icon(
                          Icons.book_online, // Icon dự phòng
                          size: 48,
                          color: theme.colorScheme.secondary,
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Tên ứng dụng
                const Text(
                  'FOUR ROCK',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                // Thông tin tài khoản
                GestureDetector(
                  onTap: auth.isLoggedIn ? () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage())); } : null,
                  child: Row(
                    children: [
                      Icon(auth.isLoggedIn ? Icons.account_circle : Icons.login, color: Colors.white70, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Tài khoản: $usernameDisplay',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // KẾT THÚC: PHẦN HEADER MỚI VỚI ẢNH LOGO

          // Các mục Menu
          ListTile(
            leading: const Icon(Icons.favorite, color: Colors.red),
            title: const Text('Từ yêu thích'),
            onTap: () {
              Navigator.pop(context);
              _openFavorites();
            },
          ),
          // 🚨 FLASHCARD & LỊCH SỬ LÀM BÀI: CHỈ HIỂN THỊ KHI KHÔNG PHẢI ADMIN
          if (isUser)
            ListTile(
              leading: const Icon(Icons.casino, color: Colors.orange),
              title: const Text('Flashcard học từ'),
              onTap: () {
                Navigator.pop(context);
                _openFlashcard();
              },
            ),
          if (isUser)
            ListTile(
              leading: const Icon(Icons.history, color: Colors.grey),
              title: const Text('Lịch sử làm bài'),
              onTap: () {
                Navigator.pop(context);
                _openHistory();
              },
            ),
          const Divider(),
          if (auth.isAdmin)
            ListTile(
              leading: const Icon(Icons.admin_panel_settings, color: Colors.blue),
              title: const Text('Quản lý Tài khoản (Admin)'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const UserManagementPage()));
              },
            ),
          // 🚨 TÀI KHOẢN CÁ NHÂN: Hiển thị cho User thường và Khách
          if (isUser || !auth.isLoggedIn)
            ListTile(
              leading: const Icon(Icons.person_pin, color: Colors.teal), // Dùng icon khác để phân biệt
              title: const Text('Tài khoản cá nhân'), // Đổi tên thành Tài khoản cá nhân
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage())); // Dùng ProfilePage
              },
            ),
          const Divider(),
          if (auth.isLoggedIn)
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.deepOrange),
              title: const Text('Đăng xuất'),
              onTap: () {
                Navigator.pop(context);
                _logout();
              },
            )
          else
            ListTile(
              leading: const Icon(Icons.login, color: Colors.green),
              title: const Text('Đăng nhập'),
              onTap: () {
                Navigator.pop(context);
                _openLogin();
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    // 🚨 XÁC ĐỊNH LẠI: isUser là KHÔNG PHẢI ADMIN
    final isUser = !auth.isAdmin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Từ Điển Vocab'),
        actions: [
          // Nút Quiz (Giữ lại vì là chức năng tương tác chính)
          IconButton(icon: const Icon(Icons.quiz), onPressed: _showQuizBottomSheet, tooltip: 'Quiz'),
          // Nút Tài khoản/Đăng nhập
          PopupMenuButton<String>(
            tooltip: auth.isLoggedIn ? 'Tài khoản (${auth.currentUser?.username})' : 'Tài khoản',
            icon: Icon(auth.isLoggedIn ? Icons.account_circle : Icons.login),
            onSelected: _onAccountMenuSelected,
            itemBuilder: (context) {
              final List<PopupMenuEntry<String>> items = [];
              if (auth.isLoggedIn) {
                items.add(PopupMenuItem(value: 'profile', child: Text('Tài khoản: ${auth.currentUser?.username}', style: const TextStyle(fontWeight: FontWeight.bold))));
                if (isUser) {
                  // 🚨 TÀI KHOẢN CÁ NHÂN TRONG POPUP CHO USER THƯỜNG
                  items.add(const PopupMenuDivider());
                  items.add(const PopupMenuItem(value: 'profile', child: Text('Thông tin cá nhân'))); // Dùng lại value 'profile'
                }
                if (auth.isAdmin) {
                  items.add(const PopupMenuItem(value: 'manage_accounts', child: Text('Quản lý tài khoản (Admin)')));
                  items.add(const PopupMenuDivider());
                }
                items.add(const PopupMenuItem(value: 'logout', child: Text('Đăng xuất')));
              } else {
                items.add(const PopupMenuItem(value: 'login', child: Text('Đăng nhập')));
                // 🚨 TÀI KHOẢN CÁ NHÂN CHO KHÁCH (Khách không cần thấy profile nếu chưa đăng nhập, nhưng vẫn cần tùy chọn này nếu muốn truy cập cài đặt không cần login)
                // Tuy nhiên, theo logic mới, mục 'profile' trong Popup sẽ được dùng để xem thông tin
                items.add(const PopupMenuItem(value: 'profile', child: Text('Thông tin cá nhân'))); // Dẫn tới ProfilePage
              }
              return items;
            },
          ),
        ],
      ),
      drawer: _buildDrawer(auth), // Thêm Drawer
      body: Column(children: [
        _buildSearchFields(), // Thanh tìm kiếm
        Expanded(
          child: !_isSearching
              ? _buildWelcomeLogo(context) // Sử dụng logo và tên app khi chưa tìm kiếm
              : _suggestions.isEmpty
              ? const Center(child: Text('Không tìm thấy từ phù hợp'))
              : ListView.separated(
            itemCount: _suggestions.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
            itemBuilder: (context, idx) {
              final v = _suggestions[idx];
              final isFav = _favorites.contains(v.id);
              return ListTile(
                title: Text(v.en, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(v.vi, style: const TextStyle(color: Colors.black87)),
                leading: IconButton(
                  icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Colors.red : Colors.grey),
                  onPressed: () => _toggleFavorite(v),
                  tooltip: isFav ? 'Bỏ yêu thích' : 'Thêm vào yêu thích',
                ),
                trailing: auth.isAdmin
                    ? PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'edit') await _showEditDialog(context, v);
                    if (value == 'delete') await _confirmDelete(context, v);
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 'edit', child: Text('Sửa từ')),
                    const PopupMenuItem(value: 'delete', child: Text('Xóa từ', style: TextStyle(color: Colors.red))),
                  ],
                )
                    : null, // Chỉ hiển thị menu nếu là Admin
                onTap: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => DetailPage(vocab: v, isFavorite: isFav, onToggleFav: () => _toggleFavorite(v))));
                  await _loadFavoritesForUser();
                },
              );
            },
          ),
        ),
      ]),
      // Floating Action Button cho chức năng Admin
      floatingActionButton: auth.isAdmin
          ? FloatingActionButton.extended(
        onPressed: _openAddPage,
        label: const Text('Thêm từ'),
        icon: const Icon(Icons.add),
        backgroundColor: Theme.of(context).colorScheme.secondary,
      )
          : null,
    );
  }
}