// lib/pages/user_management_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../models/user.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});
  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  List<User> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final auth = Provider.of<AuthService>(context, listen: false);
    final list = await auth.listUsers();
    if (!mounted) return;
    setState(() {
      _users = list;
      _loading = false;
    });
  }

  Future<void> _toggleAdmin(String username) async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final ok = await auth.toggleAdmin(username);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Cập nhật quyền thành công' : 'Không thể cập nhật quyền')));
    await _load();
  }

  Future<void> _removeUser(String username) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xác nhận'),
        content: Text('Xóa tài khoản "$username"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Hủy')),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Xóa')),
        ],
      ),
    );
    if (confirm != true) return;
    final auth = Provider.of<AuthService>(context, listen: false);
    final ok = await auth.removeUser(username);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Đã xóa' : 'Không thể xóa (còn admin duy nhất?)')));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý tài khoản')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _load,
        child: ListView.separated(
          itemCount: _users.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final u = _users[i];
            return ListTile(
              title: Text(u.username),
              subtitle: Text(u.isAdmin ? 'Admin' : 'User'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  icon: Icon(u.isAdmin ? Icons.shield : Icons.shield_outlined),
                  tooltip: u.isAdmin ? 'Thu hồi quyền admin' : 'Đặt làm admin',
                  onPressed: () => _toggleAdmin(u.username),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: 'Xóa tài khoản',
                  onPressed: () => _removeUser(u.username),
                ),
              ]),
            );
          },
        ),
      ),
    );
  }
}
