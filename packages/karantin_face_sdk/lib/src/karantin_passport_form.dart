import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'karantin_face_config.dart';

/// Passport / PNFL entry form, a native port of the web login `FormComponent`.
///
/// Emits the chosen identifier and whether it is a PNFL once validated, matching
/// the web client's `is_pnfl` toggle and validation rules.
class KarantinPassportForm extends StatefulWidget {
  const KarantinPassportForm({
    super.key,
    required this.onSubmit,
    required this.primaryColor,
    required this.strings,
    this.systemName,
  });

  /// Called with (identifier, isPnfl) when the form validates successfully.
  final void Function(String identifier, bool isPnfl) onSubmit;

  /// Accent colour for the button and field focus.
  final Color primaryColor;

  /// UI strings.
  final KarantinFaceStrings strings;

  /// Target system name shown under the form ("Tizim: …").
  final String? systemName;

  @override
  State<KarantinPassportForm> createState() => _KarantinPassportFormState();
}

class _KarantinPassportFormState extends State<KarantinPassportForm> {
  Color get _accent => widget.primaryColor;

  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _isPnfl = false;

  // Passport is 2 letters + 7 digits: start on the text keyboard, switch to the
  // number pad after the two letters, and switch back if they are deleted.
  TextInputType _passportKeyboard = TextInputType.text;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onInputChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onInputChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    final length = _controller.text.length;

    // Passport only: switch to the number keyboard once the two letters are in,
    // and back if they are deleted.
    if (!_isPnfl) {
      final next = length >= 2 ? TextInputType.number : TextInputType.text;
      if (next != _passportKeyboard) {
        setState(() => _passportKeyboard = next);
        // Changing keyboardType does not re-open a visible keyboard, so briefly
        // drop and restore focus to force the platform to swap it.
        if (_focusNode.hasFocus) {
          _focusNode.unfocus();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _controller.text.length < _fullLength) {
              _focusNode.requestFocus();
            }
          });
        }
      }
    }

    // Once the full number is entered (passport 9, PNFL 14), dismiss the keyboard.
    if (length >= _fullLength && _focusNode.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.text.length >= _fullLength) {
          _focusNode.unfocus();
        }
      });
    }
  }

  int get _fullLength => _isPnfl ? 14 : 9;

  void _setMode(bool isPnfl) {
    if (_isPnfl == isPnfl) return;
    HapticFeedback.selectionClick();
    setState(() {
      _isPnfl = isPnfl;
      _controller.clear();
      _passportKeyboard = TextInputType.text;
    });
  }

  void _submit() {
    HapticFeedback.mediumImpact();
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
          Text(
            widget.strings.formTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
            child: Text(
              widget.strings.continueButton,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          const SizedBox(height: 16),
          _buildSegmented(),
          if (widget.systemName != null && widget.systemName!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text.rich(
              TextSpan(
                text: 'Tizim: ',
                style: TextStyle(color: _accent, fontSize: 13),
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
        focusNode: _focusNode,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(14),
        ],
        validator: _validate,
        decoration: _decoration(
          label: widget.strings.pnflLabel,
          hint: '12345678901234',
        ),
      );
    }
    return TextFormField(
      controller: _controller,
      focusNode: _focusNode,
      keyboardType: _passportKeyboard,
      textCapitalization: TextCapitalization.characters,
      inputFormatters: [
        LengthLimitingTextInputFormatter(9),
        _PassportFormatter(),
      ],
      validator: _validate,
      decoration: _decoration(
        label: widget.strings.passportLabel,
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
        borderSide: BorderSide(color: _accent, width: 2),
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
            label: widget.strings.passportTab,
            icon: Icons.badge_outlined,
            selected: !_isPnfl,
            onTap: () => _setMode(false),
          ),
          _segment(
            label: widget.strings.pnflTab,
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
                    color: selected
                        ? const Color(0xFF212529)
                        : const Color(0xFF868E96),
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

/// Enforces the passport shape AA1234567: the first two characters are letters,
/// the rest are digits, everything upper-cased. Invalid characters per position
/// are dropped so the number keyboard (shown after the two letters) can only add
/// digits and a stray letter/number cannot land in the wrong slot.
class _PassportFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text.toUpperCase();
    final buffer = StringBuffer();
    for (final ch in raw.split('')) {
      final pos = buffer.length;
      if (pos >= 9) break;
      final isLetter = RegExp(r'[A-Z]').hasMatch(ch);
      final isDigit = RegExp(r'[0-9]').hasMatch(ch);
      if (pos < 2 ? isLetter : isDigit) buffer.write(ch);
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
