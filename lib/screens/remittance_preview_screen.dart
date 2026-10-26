import 'package:flutter/material.dart';

import '../models/remittance_quote.dart';
import '../models/recipient.dart';
import 'saved_recipients_screen.dart';

class RemittancePreviewScreen extends StatefulWidget {
  const RemittancePreviewScreen({super.key});
  @override
  State<RemittancePreviewScreen> createState() =>
      _RemittancePreviewScreenState();
}

class _RemittancePreviewScreenState extends State<RemittancePreviewScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _amount = TextEditingController();
  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _choose() async {
    final recipient = await Navigator.of(context).push<Recipient>(
      MaterialPageRoute<Recipient>(
        builder: (_) => const SavedRecipientsScreen(),
      ),
    );
    if (!mounted || recipient == null) return;
    _name.text = recipient.name;
    _phone.text = recipient.phoneNumber;
  }

  void _review() {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final quote = RemittanceQuote(RemittanceQuote.parseCentavos(_amount.text)!);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RemittanceReviewScreen(
          recipient: Recipient(
            name: _name.text.trim(),
            phoneNumber: _phone.text.trim(),
          ),
          quote: quote,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Philippines → PNG')),
    body: SafeArea(
      child: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Send home from the Philippines',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'PREVIEW ONLY · All rates, fees and delivery estimates below are fictional examples. No money is collected or sent.',
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _choose,
              icon: const Icon(Icons.people_outline),
              label: const Text('Choose saved recipient'),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _name,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Recipient name'),
              validator: (v) => (v?.trim().isEmpty ?? true)
                  ? 'Enter the recipient name'
                  : null,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'PNG mobile number',
                prefixText: '+675 ',
              ),
              validator: (v) => RegExp(r'^\d{8}$').hasMatch(v?.trim() ?? '')
                  ? null
                  : 'Enter 8 digits without spaces',
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Amount to convert (PHP)',
                helperText: 'The sample PHP 50 fee is added separately.',
              ),
              validator: (v) {
                final amount = RemittanceQuote.parseCentavos(v ?? '');
                if (amount == null || amount <= 0 || amount > 10000000) {
                  return 'Enter PHP 0.01–100,000 with up to 2 decimals';
                }
                if (RemittanceQuote(amount).recipientToea == 0) {
                  return 'Use at least PHP 0.08 for this sample conversion';
                }
                return null;
              },
              onFieldSubmitted: (_) => _review(),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _review,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
              ),
              child: const Text('Review sample quote'),
            ),
            const SizedBox(height: 20),
            const Text(
              'Your saved kina balance and Activity remain unchanged throughout this preview.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  );
}

class RemittanceReviewScreen extends StatefulWidget {
  final Recipient recipient;
  final RemittanceQuote quote;
  const RemittanceReviewScreen({
    super.key,
    required this.recipient,
    required this.quote,
  });
  @override
  State<RemittanceReviewScreen> createState() => _RemittanceReviewScreenState();
}

class _RemittanceReviewScreenState extends State<RemittanceReviewScreen> {
  bool _finished = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        _finished ? 'Sample Remittance Summary' : 'Review Sample Quote',
      ),
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Icon(
            _finished ? Icons.visibility_outlined : Icons.swap_horiz,
            size: 64,
            color: const Color(0xFF1769EF),
          ),
          const SizedBox(height: 16),
          Text(
            _finished ? 'Preview complete' : 'Recipient would receive',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            RemittanceQuote.kina(widget.quote.recipientToea),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Card(
            elevation: 0,
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detail('Recipient', widget.recipient.name),
                  _detail('PNG mobile', '+675 ${widget.recipient.phoneNumber}'),
                  const Divider(),
                  _detail(
                    'Amount converted',
                    RemittanceQuote.php(widget.quote.principalCentavos),
                  ),
                  _detail(
                    'Sample exchange rate',
                    RemittanceQuote.sampleRateLabel,
                  ),
                  _detail(
                    'Sample fee (added)',
                    RemittanceQuote.php(RemittanceQuote.sampleFeeCentavos),
                  ),
                  _detail(
                    'Total sender would pay',
                    RemittanceQuote.php(widget.quote.totalCentavos),
                  ),
                  _detail(
                    'Recipient would receive',
                    RemittanceQuote.kina(widget.quote.recipientToea),
                  ),
                  _detail(
                    'Illustrative delivery estimate',
                    '1–2 business days · example only',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'FICTIONAL SAMPLE · Not a provider quote, guaranteed delivery time, or proof of payment. No PHP is charged, no PGK is credited, and no Activity entry is created.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              if (_finished) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              } else {
                setState(() => _finished = true);
              }
            },
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
            ),
            child: Text(_finished ? 'Back Home' : 'Finish preview'),
          ),
          if (!_finished) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Edit details'),
            ),
          ],
        ],
      ),
    ),
  );
  Widget _detail(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.black54)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}
