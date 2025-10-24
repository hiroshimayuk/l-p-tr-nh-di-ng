// lib/pages/profile_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _newPassCtrl = TextEditingController();
  bool _loading = false;
  String? _status;

  @override
  void dispose() {
    _newPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final newPass = _newPassCtrl.text;
    if (newPass.length < 6) {
      setState(() => _status = 'Mật khẩu cần tối thiểu 6 ký tự');
      return;
    }
    setState(() { _loading = true; _status = null; });
    final auth = Provider.of<AuthService>(context, listen: false);
    final username = auth.currentUsername;
    if (username == null) {
      setState(() { _loading = false; _status = 'Không tìm thấy tài khoản'; });
      return;
    }
    final ok = await auth.resetPassword(username, newPass);
    setState(() { _loading = false; _status = ok ? 'Đổi mật khẩu thành công' : 'Đổi mật khẩu thất bại'; });
    if (ok) _newPassCtrl.clear();
  }

  Future<void> _logout() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    await auth.logout();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final username = auth.currentUsername ?? 'khách';
    final isAdmin = auth.isAdmin;

    return Scaffold(
      appBar: AppBar(title: const Text('Thông tin cá nhân')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Tên đăng nhập: $username', style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 8),
          Text('Vai trò: ${isAdmin ? "Admin" : "User"}'),
          const SizedBox(height: 16),
          const Text('Đổi mật khẩu', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(controller: _newPassCtrl, decoration: const InputDecoration(labelText: 'Mật khẩu mới'), obscureText: true),
          const SizedBox(height: 12),
          Row(children: [
            ElevatedButton(onPressed: _loading ? null : _changePassword, child: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Lưu')),
            const SizedBox(width: 12),
            OutlinedButton(onPressed: _logout, child: const Text('Đăng xuất')),
          ]),
          const SizedBox(height: 12),
          if (_status != null) Text(_status!, style: const TextStyle(color: Colors.green)),
        ]),
      ),
    );
  }
}
