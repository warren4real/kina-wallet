import 'package:flutter/material.dart';

import 'wallet_design.dart';

/// App-owned PIN input: no text field or operating-system keyboard.
class PinKeypad extends StatelessWidget {
  const PinKeypad({
    super.key,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });
  final String value;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final keySize = (constraints.maxWidth / 4.3).clamp(54.0, 76.0);
      final dotSize = (constraints.maxWidth / 8).clamp(28.0, 42.0);
      return Column(
        children: [
          Semantics(
            key: const ValueKey('app-pin-field'),
            label: 'Six-digit PIN',
            value: '${value.length} of 6 digits entered',
            child: ExcludeSemantics(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(
                  6,
                  (index) => Container(
                    key: ValueKey('pin-dot-$index'),
                    width: dotSize,
                    height: dotSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: designNavy, width: 1.5),
                    ),
                    child: index < value.length
                        ? const Center(
                            child: Icon(
                              Icons.circle,
                              size: 12,
                              color: designNavy,
                            ),
                          )
                        : null,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Never share your PIN with anyone.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54, fontSize: 12),
          ),
          const SizedBox(height: 24),
          for (final row in const [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
            ['delete', '0', 'clear'],
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  for (final key in row)
                    Expanded(
                      child: Center(
                        child: SizedBox(
                          width: keySize,
                          height: keySize,
                          child: key == 'clear'
                              ? TextButton(
                                  key: const ValueKey('pin-clear'),
                                  onPressed: enabled
                                      ? () => onChanged('')
                                      : null,
                                  style: TextButton.styleFrom(
                                    foregroundColor: designNavy,
                                    padding: EdgeInsets.zero,
                                  ),
                                  child: const Text(
                                    'Clear',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                )
                              : key == 'delete'
                              ? IconButton(
                                  key: const ValueKey('pin-delete'),
                                  tooltip: 'Delete last digit',
                                  onPressed: enabled && value.isNotEmpty
                                      ? () => onChanged(
                                          value.substring(0, value.length - 1),
                                        )
                                      : null,
                                  icon: const Icon(Icons.backspace_outlined),
                                  color: designNavy,
                                )
                              : OutlinedButton(
                                  key: ValueKey('pin-key-$key'),
                                  onPressed: enabled && value.length < 6
                                      ? () => onChanged('$value$key')
                                      : null,
                                  style: OutlinedButton.styleFrom(
                                    shape: const CircleBorder(),
                                    padding: EdgeInsets.zero,
                                    foregroundColor: designNavy,
                                    side: const BorderSide(
                                      color: designNavy,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Text(
                                    key,
                                    style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      );
    },
  );
}
