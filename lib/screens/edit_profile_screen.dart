import 'package:flutter/material.dart';

import '../models/profile_store.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: profileStore.profile.name);
  late final _phone = TextEditingController(
    text: profileStore.profile.phoneNumber,
  );
  bool _saving = false;
  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    final error = await profileStore.update(
      name: _name.text,
      phoneNumber: _phone.text,
    );
    if (!mounted) return;
    if (error != null) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Edit Demo Profile')),
    body: SafeArea(
      child: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Your demo details',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'These details appear on Profile and My QR. Use fictional details. Editing them does not register or verify an account.',
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _name,
              enabled: !_saving,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Demo name'),
              validator: (value) =>
                  (value == null ||
                      value.trim().isEmpty ||
                      value.trim().length > 80)
                  ? 'Enter a name with 1–80 characters'
                  : null,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _phone,
              enabled: !_saving,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'PNG mobile number',
                prefixText: '+675 ',
              ),
              validator: (value) =>
                  RegExp(r'^\d{8}$').hasMatch(value?.trim() ?? '')
                  ? null
                  : 'Enter 8 digits without spaces',
              onFieldSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
              ),
              child: Text(_saving ? 'Saving…' : 'Save demo profile'),
            ),
          ],
        ),
      ),
    ),
  );
}
