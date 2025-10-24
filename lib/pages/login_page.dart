// lib/pages/login_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'register_page.dart';
import 'settings_page.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final TextEditingController _userCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _obscure = true;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _doLogin() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final auth = context.read<AuthService>();
    final ok = await auth.login(_userCtrl.text.trim(), _passCtrl.text);
    setState(() => _loading = false);

    if (ok) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
    } else {
      setState(() => _error = 'Tên đăng nhập hoặc mật khẩu không đúng');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    if (!auth.isInitialized) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    if (auth.isLoggedIn) {
      // If already logged in, go to Home
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Đăng nhập')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _form,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: _userCtrl,
              decoration: const InputDecoration(labelText: 'Tên đăng nhập'),
              validator: (s) => s == null || s.trim().isEmpty ? 'Nhập tên đăng nhập' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passCtrl,
              decoration: InputDecoration(
                labelText: 'Mật khẩu',
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              obscureText: _obscure,
              validator: (s) => s == null || s.isEmpty ? 'Nhập mật khẩu' : null,
            ),
            const SizedBox(height: 12),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 8),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _doLogin,
                child: _loading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Đăng nhập'),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterPage())), child: const Text('Đăng ký')),
            TextButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsPage())), child: const Text('Cài đặt SMTP')),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Tài khoản demo'),
                  content: const Text('Dùng: admin/admin (admin) hoặc user/user (user)'),
                  actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Đóng'))],
                ),
              ),
              child: const Text('Tài khoản demo'),
            ),
          ]),
        ),
      ),
    );
  }
}
