import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_colors.dart';

/// Passport / PNFL entry form, a native port of the web login `FormComponent`.
///
/// Emits the chosen identifier and whether it is a PNFL once validated, matching
/// the web client's `is_pnfl` toggle and validation rules.
class KarantinPassportForm extends StatefulWidget {
  const KarantinPassportForm({
    super.key,
    required this.onSubmit,
    this.systemName,
  });

  /// Called with (identifier, isPnfl) when the form validates successfully.
  final void Function(String identifier, bool isPnfl) onSubmit;

  /// Target system name shown under the form ("Tizim: …").
  final String? systemName;

  @override
  State<KarantinPassportForm> createState() => _KarantinPassportFormState();
}

class _KarantinPassportFormState extends State<KarantinPassportForm> {
  // App theme green; the "Davom etish" button and field accents follow it.
  static const _accent = kGreen;

  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  bool _isPnfl = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setMode(bool isPnfl) {
    if (_isPnfl == isPnfl) return;
    setState(() {
      _isPnfl = isPnfl;
      _controller.clear();
    });
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final value = _controller.text.trim();
    widget.onSubmit(_isPnfl ? value : value.toUpperCase(), _isPnfl);
  }

  String? _validate(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return "Ushbu maydonni to'ldirish majburiy";
    if (_isPnfl) {
      if (!RegExp(r'^\d{14}$').hasMatch(value)) {
        return 'PNFL (JSHSHR) 14 xonali raqam bo‘lishi kerak';
      }
    } else {
      if (!RegExp(r'^[A-Z]{2}\d{7}$').hasMatch(value.toUpperCase())) {
        return 'Pasport raqamini to‘g‘ri kiriting (masalan, AA1234567)';
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Yuz orqali tizimga kirish',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _InfoAlert(isPnfl: _isPnfl),
          const SizedBox(height: 16),
          _buildInput(),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _submit,
            style: FilledButton.styleFrom(
              backgroundColor: _accent,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Davom etish', style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(height: 16),
          _buildSegmented(),
          if (widget.systemName != null &&
              widget.systemName!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text.rich(
              TextSpan(
                text: 'Tizim: ',
                style: const TextStyle(color: _accent, fontSize: 13),
                children: [
                  TextSpan(
                    text: widget.systemName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInput() {
    if (_isPnfl) {
      return TextFormField(
        controller: _controller,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(14),
        ],
        validator: _validate,
        decoration: _decoration(
          label: 'PNFLingizni kiriting',
          hint: '12345678901234',
        ),
      );
    }
    return TextFormField(
      controller: _controller,
      textCapitalization: TextCapitalization.characters,
      inputFormatters: [
        LengthLimitingTextInputFormatter(9),
        _UpperCaseFormatter(),
      ],
      validator: _validate,
      decoration: _decoration(
        label: 'Passport seriya va raqamni kiriting',
        hint: 'AA1234567',
      ),
    );
  }

  InputDecoration _decoration({required String label, required String hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _accent, width: 2),
      ),
    );
  }

  Widget _buildSegmented() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F5),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _segment(
            label: 'Passport',
            icon: Icons.badge_outlined,
            selected: !_isPnfl,
            onTap: () => _setMode(false),
          ),
          _segment(
            label: 'JSHSHR (PINFL)',
            icon: Icons.fingerprint,
            selected: _isPnfl,
            onTap: () => _setMode(true),
          ),
        ],
      ),
    );
  }

  Widget _segment({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? _accent : const Color(0xFF868E96),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? const Color(0xFF212529) : const Color(0xFF868E96),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoAlert extends StatelessWidget {
  const _InfoAlert({required this.isPnfl});

  final bool isPnfl;

  @override
  Widget build(BuildContext context) {
    final what = isPnfl
        ? 'JSHSHR (PINFL) raqamingizni'
        : 'pasport seriya va raqamingizni';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE7F5FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Color(0xFF228BE6), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: 'Face ID orqali tizimga kirish uchun avval ',
                style: const TextStyle(fontSize: 13, color: Color(0xFF1864AB)),
                children: [
                  TextSpan(
                    text: what,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(
                    text: ' kiriting. So‘ng kameraga yuzingizni tuting',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
