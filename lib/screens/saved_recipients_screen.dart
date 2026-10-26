import 'package:flutter/material.dart';

import '../models/recipient.dart';
import '../models/recipient_store.dart';

class SavedRecipientsScreen extends StatelessWidget {
  const SavedRecipientsScreen({super.key});

  Future<void> _openForm(BuildContext context, {Recipient? recipient}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AddRecipientScreen(recipient: recipient),
      ),
    );
  }

  Future<void> _removeRecipient(
    BuildContext context,
    Recipient recipient,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove recipient?'),
        content: Text(
          'Remove ${recipient.name} from saved recipients?\n\n'
          'Your balance and past transactions will stay unchanged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (!context.mounted || confirmed != true) return;

    final error = await recipientStore.removeRecipient(
      phoneNumber: recipient.phoneNumber,
    );

    if (!context.mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(error ?? 'Recipient removed')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Recipients'),
        actions: [
          IconButton(
            tooltip: 'Add recipient',
            onPressed: () => _openForm(context),
            icon: const Icon(Icons.person_add_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: recipientStore,
          builder: (context, child) {
            final recipients = recipientStore.recipients;

            if (recipients.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.people_outline,
                        size: 64,
                        color: Color(0xFF1769EF),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No saved recipients yet',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Save a name and mobile number '
                        'to use in your demo transfers.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: () => _openForm(context),
                        child: const Text('Add recipient'),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(24),
              itemCount: recipients.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final recipient = recipients[index];

                return Card(
                  elevation: 0,
                  color: Colors.white,
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.person_outline),
                    ),
                    title: Text(recipient.name),
                    subtitle: Text('+675 ${recipient.phoneNumber}'),

                    // Tap the row to choose this recipient.
                    onTap: () {
                      Navigator.pop<Recipient>(context, recipient);
                    },

                    // Use the menu to manage their saved details.
                    trailing: PopupMenuButton<String>(
                      tooltip: 'Manage recipient',
                      onSelected: (action) {
                        if (action == 'edit') {
                          _openForm(context, recipient: recipient);
                        } else if (action == 'remove') {
                          _removeRecipient(context, recipient);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'remove', child: Text('Remove')),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class AddRecipientScreen extends StatefulWidget {
  // Null means adding; an existing recipient means editing.
  final Recipient? recipient;

  const AddRecipientScreen({super.key, this.recipient});

  @override
  State<AddRecipientScreen> createState() => _AddRecipientScreenState();
}

class _AddRecipientScreenState extends State<AddRecipientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _saving = false;

  bool get _editing => widget.recipient != null;

  @override
  void initState() {
    super.initState();

    final recipient = widget.recipient;

    if (recipient != null) {
      _nameController.text = recipient.name;
      _phoneController.text = recipient.phoneNumber;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveRecipient() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    final String? error;
    final original = widget.recipient;

    if (original == null) {
      error = await recipientStore.addRecipient(
        name: _nameController.text,
        phoneNumber: _phoneController.text,
      );
    } else {
      error = await recipientStore.updateRecipient(
        originalPhoneNumber: original.phoneNumber,
        name: _nameController.text,
        phoneNumber: _phoneController.text,
      );
    }

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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Edit Recipient' : 'Add Recipient'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                _editing ? 'Update saved details' : 'Save someone you send to',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Use fictional details for this prototype. '
                'Saving a recipient does not verify their account.',
              ),
              const SizedBox(height: 28),
              TextFormField(
                controller: _nameController,
                enabled: !_saving,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Recipient name'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter the recipient’s name';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _phoneController,
                enabled: !_saving,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'PNG mobile number',
                  prefixText: '+675 ',
                  hintText: 'Enter 8 digits',
                ),
                validator: (value) {
                  final phone = value?.trim() ?? '';

                  if (!RegExp(r'^\d{8}$').hasMatch(phone)) {
                    return 'Enter 8 digits without spaces';
                  }

                  return null;
                },
                onFieldSubmitted: (_) => _saveRecipient(),
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _saving ? null : _saveRecipient,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1769EF),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(54),
                ),
                child: Text(
                  _saving
                      ? 'Saving…'
                      : _editing
                      ? 'Save changes'
                      : 'Save recipient',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
