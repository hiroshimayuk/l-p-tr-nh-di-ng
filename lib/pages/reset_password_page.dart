import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/email_service.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _identifierCtrl = TextEditingController(); // username or email
  final _otpCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();

  bool _loading = false;
  bool _stageOtp = false;
  String? _statusMsg;
  bool _obscure = true;

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _otpCtrl.dispose();
    _newPassCtrl.dispose();
    super.dispose();
  }

  void _setLoading(bool v) => setState(() => _loading = v);

  void _setStatus(String? m) => setState(() => _statusMsg = m);

  Future<void> _requestOtp() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final id = _identifierCtrl.text.trim();
    if (id.isEmpty) return;
    _setLoading(true);
    _setStatus(null);

    final emailSvc = Provider.of<EmailService>(context, listen: false);
    final auth = Provider.of<AuthService>(context, listen: false);

    // AuthService.requestResetOtp will locate username by email/username and send OTP via EmailService
    final ok = await auth.requestResetOtp(usernameOrEmail: id, emailService: emailSvc);
    _setLoading(false);

    if (ok) {
      _setStatus('OTP đã được gửi tới email liên kết (nếu tồn tại). Kiểm tra hộp thư.');
      setState(() => _stageOtp = true);
    } else {
      _setStatus('Không gửi được OTP. Kiểm tra tên đăng nhập/email hoặc cấu hình SMTP.');
    }
  }

  Future<void> _confirmReset() async {
    final id = _identifierCtrl.text.trim();
    final otp = _otpCtrl.text.trim();
    final newPass = _newPassCtrl.text;

    if (otp.isEmpty) {
      _setStatus('Vui lòng nhập OTP');
      return;
    }
    if (newPass.isEmpty || newPass.length < 6) {
      _setStatus('Mật khẩu mới tối thiểu 6 ký tự');
      return;
    }

    _setLoading(true);
    _setStatus(null);
    final auth = Provider.of<AuthService>(context, listen: false);
    final success = await auth.confirmResetOtp(username: id, otp: otp, newPassword: newPass);
    _setLoading(false);

    if (success) {
      _setStatus('Đổi mật khẩu thành công. Bạn có thể đăng nhập bằng mật khẩu mới.');
      // optionally navigate back to login after short delay
      Future.delayed(const Duration(seconds: 1), () {
        if (!mounted) return;
        Navigator.of(context).popUntil((r) => r.isFirst);
      });
    } else {
      _setStatus('Xác thực OTP thất bại hoặc OTP đã hết hạn.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đổi mật khẩu')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Form(
                key: _formKey,
                child: Column(children: [
                  TextFormField(
                    controller: _identifierCtrl,
                    decoration: const InputDecoration(labelText: 'Email hoặc Tên đăng nhập'),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Nhập email hoặc tên đăng nhập' : null,
                    enabled: !_stageOtp,
                  ),
                  const SizedBox(height: 12),
                  if (!_stageOtp) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _requestOtp,
                        child: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Gửi OTP'),
                      ),
                    ),
                  ],
                  if (_stageOtp) ...[
                    TextFormField(
                      controller: _otpCtrl,
                      decoration: const InputDecoration(labelText: 'OTP'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _newPassCtrl,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: 'Mật khẩu mới',
                        suffixIcon: IconButton(
                          icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _confirmReset,
                        child: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Xác nhận và đổi mật khẩu'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () {
                        setState(() {
                          _stageOtp = false;
                          _otpCtrl.clear();
                          _newPassCtrl.clear();
                          _setStatus(null);
                        });
                      },
                      child: const Text('Gửi lại bằng tên khác / Quay lại'),
                    ),
                  ],
                ]),
              ),
              const SizedBox(height: 16),
              if (_statusMsg != null) Text(_statusMsg!, style: const TextStyle(color: Colors.blue)),
            ],
          ),
        ),
      ),
    );
  }
}
