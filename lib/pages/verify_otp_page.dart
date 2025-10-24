// lib/pages/verify_otp_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/email_service.dart';

enum VerifyPurpose { register, reset }

class VerifyOtpPage extends StatefulWidget {
  final String identifier; // username for register flow, username or email for reset flow
  final VerifyPurpose purpose;

  const VerifyOtpPage({
    super.key,
    required this.identifier,
    this.purpose = VerifyPurpose.register,
  });

  @override
  State<VerifyOtpPage> createState() => _VerifyOtpPageState();
}

class _VerifyOtpPageState extends State<VerifyOtpPage> {
  final _otpCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController(); // used only for reset flow
  bool _loading = false;
  String? _status;
  bool _obscure = true;

  @override
  void dispose() {
    _otpCtrl.dispose();
    _newPassCtrl.dispose();
    super.dispose();
  }

  void _setLoading(bool v) => setState(() => _loading = v);
  void _setStatus(String? s) => setState(() => _status = s);

  Future<void> _confirm() async {
    final otp = _otpCtrl.text.trim();
    if (otp.isEmpty) {
      _setStatus('Nhập mã OTP');
      return;
    }

    _setLoading(true);
    _setStatus(null);
    final auth = Provider.of<AuthService>(context, listen: false);

    bool ok = false;
    if (widget.purpose == VerifyPurpose.register) {
      // identifier is username
      ok = await auth.confirmRegisterOtp(username: widget.identifier, otp: otp);
      _setLoading(false);
      if (ok) {
        _setStatus('Xác thực thành công. Tài khoản đã được tạo.');
        if (!mounted) return;
        await Future.delayed(const Duration(seconds: 1));
        Navigator.of(context).popUntil((r) => r.isFirst);
      } else {
        _setStatus('Xác thực thất bại hoặc OTP đã hết hạn.');
      }
    } else {
      // reset flow requires new password
      final newPass = _newPassCtrl.text;
      if (newPass.isEmpty || newPass.length < 6) {
        _setLoading(false);
        _setStatus('Mật khẩu mới tối thiểu 6 ký tự');
        return;
      }
      // For reset flow, widget.identifier may be username or email. AuthService.confirmResetOtp expects username.
      // If user provided email when requesting reset, AuthService.requestResetOtp resolved username and stored OTP by username.
      // Here we assume caller navigated with resolved username; if not, user should supply username instead.
      ok = await auth.confirmResetOtp(username: widget.identifier, otp: otp, newPassword: newPass);
      _setLoading(false);
      if (ok) {
        _setStatus('Đổi mật khẩu thành công. Bạn có thể đăng nhập bằng mật khẩu mới.');
        if (!mounted) return;
        await Future.delayed(const Duration(seconds: 1));
        Navigator.of(context).popUntil((r) => r.isFirst);
      } else {
        _setStatus('Xác thực OTP thất bại hoặc OTP đã hết hạn.');
      }
    }
  }

  Future<void> _resendOtp() async {
    _setLoading(true);
    _setStatus(null);
    final emailSvc = Provider.of<EmailService>(context, listen: false);
    final auth = Provider.of<AuthService>(context, listen: false);

    bool sent = false;
    if (widget.purpose == VerifyPurpose.register) {
      // We need the original password and email stored by requestRegisterOtp in secure storage via AuthService,
      // but here we attempt to re-request using minimal info: username + reading stored email/password handled inside AuthService.requestRegisterOtp if you adapt it.
      // For simplicity we call requestRegisterOtp only when caller provides email & password; otherwise inform user to re-register.
      _setLoading(false);
      _setStatus('Để gửi lại OTP cho đăng ký, thực hiện lại bước đăng ký (Gửi OTP)');
      return;
    } else {
      // reset flow: try to re-request reset OTP by username/email
      sent = await auth.requestResetOtp(usernameOrEmail: widget.identifier, emailService: emailSvc);
    }

    _setLoading(false);
    if (sent) {
      _setStatus('OTP đã được gửi lại. Kiểm tra email.');
    } else {
      _setStatus('Không thể gửi lại OTP. Kiểm tra cấu hình SMTP hoặc thông tin tài khoản.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isReset = widget.purpose == VerifyPurpose.reset;
    return Scaffold(
      appBar: AppBar(title: Text(isReset ? 'Xác thực OTP - Đổi mật khẩu' : 'Xác thực OTP - Đăng ký')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(children: [
            Text(isReset
                ? 'Nhập mã OTP để đổi mật khẩu cho: ${widget.identifier}'
                : 'Nhập mã OTP gửi tới tài khoản: ${widget.identifier}'),
            const SizedBox(height: 12),
            TextField(
              controller: _otpCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'OTP'),
            ),
            if (isReset) ...[
              const SizedBox(height: 12),
              TextField(
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
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _confirm,
                child: _loading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(isReset ? 'Xác nhận và đổi mật khẩu' : 'Xác nhận OTP'),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _loading ? null : _resendOtp,
              child: const Text('Gửi lại OTP'),
            ),
            const SizedBox(height: 12),
            if (_status != null) Text(_status!, style: const TextStyle(color: Colors.blue)),
          ]),
        ),
      ),
    );
  }
}
