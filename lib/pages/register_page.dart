// lib/pages/register_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/email_service.dart';
import 'verify_otp_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _form = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _obscure = true;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  String? _validateUsername(String? v) {
    if (v == null || v.trim().isEmpty) return 'Nhập tên đăng nhập';
    if (v.trim().length < 3) return 'Tên đăng nhập tối thiểu 3 ký tự';
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Nhập mật khẩu';
    if (v.length < 6) return 'Mật khẩu tối thiểu 6 ký tự';
    return null;
  }

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Nhập email';
    final s = v.trim();
    final emailRegex = RegExp(r"^[^\s@]+@[^\s@]+\.[^\s@]+$");
    if (!emailRegex.hasMatch(s)) return 'Email không hợp lệ';
    return null;
  }

  void _setLoading(bool v) => setState(() => _loading = v);
  void _setError(String? m) => setState(() => _error = m);

  Future<void> _submit() async {
    _setError(null);
    if (!(_form.currentState?.validate() ?? false)) return;

    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text;
    final email = _emailCtrl.text.trim();

    _setLoading(true);

    try {
      final emailSvc = Provider.of<EmailService>(context, listen: false);
      final auth = Provider.of<AuthService>(context, listen: false);

      final ok = await auth.requestRegisterOtp(username: username, password: password, email: email, emailService: emailSvc);
      _setLoading(false);

      if (!ok) {
        _setError('Không thể tạo yêu cầu đăng ký. Tên đăng nhập có thể đã tồn tại hoặc SMTP chưa cấu hình.');
        return;
      }

      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => VerifyOtpPage(identifier: username, purpose: VerifyPurpose.register)));
    } catch (e) {
      _setLoading(false);
      _setError('Lỗi khi gửi OTP. Vui lòng thử lại.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng ký')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(controller: _usernameCtrl, decoration: const InputDecoration(labelText: 'Tên đăng nhập'), validator: _validateUsername),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordCtrl,
                  decoration: InputDecoration(
                    labelText: 'Mật khẩu',
                    suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => _obscure = !_obscure)),
                  ),
                  obscureText: _obscure,
                  validator: _validatePassword,
                ),
                const SizedBox(height: 12),
                TextFormField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress, validator: _validateEmail),
                const SizedBox(height: 20),
                if (_error != null) ...[
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Gửi mã xác thực (OTP)'),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(onPressed: _loading ? null : () => Navigator.of(context).pop(), child: const Text('Quay lại')),
                const SizedBox(height: 8),
                const Text('Lưu ý: mã OTP có hiệu lực trong 5 phút. Kiểm tra hộp thư hoặc mục Spam.'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
