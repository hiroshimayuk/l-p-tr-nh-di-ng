import 'package:flutter/material.dart';

class AddWordPage extends StatefulWidget {
  const AddWordPage({super.key});

  @override
  State<AddWordPage> createState() => _AddWordPageState();
}

class _AddWordPageState extends State<AddWordPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _enController = TextEditingController();
  final TextEditingController _viController = TextEditingController();

  @override
  void dispose() {
    _enController.dispose();
    _viController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final en = _enController.text.trim();
    final vi = _viController.text.trim();
    Navigator.of(context).pop({'en': en, 'vi': vi});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thêm từ mới'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _enController,
                decoration: const InputDecoration(labelText: 'English', border: OutlineInputBorder()),
                textCapitalization: TextCapitalization.none,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Nhập từ tiếng Anh';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _viController,
                decoration: const InputDecoration(labelText: 'Tiếng Việt', border: OutlineInputBorder()),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Nhập nghĩa tiếng Việt';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _save,
                      child: const Text('Lưu'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Hủy'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
