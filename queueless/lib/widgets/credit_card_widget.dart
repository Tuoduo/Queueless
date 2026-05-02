import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants/app_colors.dart';

/// Formats card number: "4111 1111 1111 1111"
String _formatCardNumber(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  final buf = StringBuffer();
  for (int i = 0; i < digits.length && i < 16; i++) {
    if (i > 0 && i % 4 == 0) buf.write(' ');
    buf.write(digits[i]);
  }
  return buf.toString();
}

/// Shows the virtual card payment sheet; resolves with card data map or null.
Future<Map<String, String>?> showCreditCardSheet(BuildContext context) {
  return showModalBottomSheet<Map<String, String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _CardSheet(),
  );
}

class _CardSheet extends StatefulWidget {
  const _CardSheet();

  @override
  State<_CardSheet> createState() => _CardSheetState();
}

class _CardSheetState extends State<_CardSheet> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final _numberController = TextEditingController();
  final _nameController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();

  final _numberFocus = FocusNode();
  final _nameFocus = FocusNode();
  final _expiryFocus = FocusNode();
  final _cvvFocus = FocusNode();

  late final AnimationController _flipController;
  late final Animation<double> _flipAnimation;
  bool _showBack = false;
  bool _isFlipping = false;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );

    _cvvFocus.addListener(() {
      if (_cvvFocus.hasFocus && !_showBack) {
        _flipToBack();
      } else if (!_cvvFocus.hasFocus && _showBack) {
        _flipToFront();
      }
    });
  }

  Future<void> _flipToBack() async {
    if (_isFlipping) return;
    _isFlipping = true;
    await _flipController.forward();
    setState(() => _showBack = true);
    _isFlipping = false;
  }

  Future<void> _flipToFront() async {
    if (_isFlipping) return;
    _isFlipping = true;
    await _flipController.reverse();
    setState(() => _showBack = false);
    _isFlipping = false;
  }

  @override
  void dispose() {
    _flipController.dispose();
    _numberController.dispose();
    _nameController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _numberFocus.dispose();
    _nameFocus.dispose();
    _expiryFocus.dispose();
    _cvvFocus.dispose();
    super.dispose();
  }

  String get _displayNumber {
    final formatted = _formatCardNumber(_numberController.text);
    if (formatted.isEmpty) return '•••• •••• •••• ••••';
    final padded = formatted.padRight(19, '•');
    // Replace trailing dots only in groups
    return padded.length > 19 ? padded.substring(0, 19) : padded;
  }

  String get _displayName =>
      _nameController.text.isEmpty ? 'FULL NAME' : _nameController.text.toUpperCase();

  String get _displayExpiry =>
      _expiryController.text.isEmpty ? 'MM/YY' : _expiryController.text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.textHint.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Card Details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),

              // Animated card
              _buildCard(),
              const SizedBox(height: 28),

              // Form fields
              _buildNumberField(),
              const SizedBox(height: 14),
              _buildNameField(),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _buildExpiryField()),
                  const SizedBox(width: 14),
                  Expanded(child: _buildCvvField()),
                ],
              ),
              const SizedBox(height: 28),

              // Confirm button
              Container(
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: const Text(
                    'Confirm Payment',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.clamp(0.0, 380.0);
        return Center(
          child: SizedBox(
            width: width,
            child: AspectRatio(
              aspectRatio: 1.586,
              child: AnimatedBuilder(
                animation: _flipAnimation,
                builder: (context, child) {
                  final angle = _flipAnimation.value * 3.14159;
                  final isBack = angle > 1.5708;
                  return Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..rotateY(angle),
                    child: isBack ? _buildCardBack() : _buildCardFront(),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCardFront() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1a237e), Color(0xFF0d47a1), Color(0xFF1565c0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1a237e).withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            top: -30,
            right: -30,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            left: 40,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Chip + network logo row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Chip
                    Container(
                      width: 44,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    // Network label
                    const Text(
                      'VISA',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // Card number
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 150),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 3,
                    fontFamily: 'monospace',
                  ),
                  child: Text(_displayNumber),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CARD HOLDER',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 9,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'EXPIRES',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 9,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _displayExpiry,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardBack() {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()..rotateY(3.14159),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1a237e), Color(0xFF0d47a1), Color(0xFF1565c0)],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1a237e).withValues(alpha: 0.4),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            const SizedBox(height: 24),
            // Magnetic stripe
            Container(height: 40, color: Colors.black.withValues(alpha: 0.7)),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(6)),
                      ),
                    ),
                  ),
                  Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(6)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _cvvController.text.isEmpty ? '•••' : _cvvController.text,
                      style: const TextStyle(
                        color: Color(0xFF1a237e),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'CVV',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 10,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberField() {
    return TextFormField(
      controller: _numberController,
      focusNode: _numberFocus,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        _CardNumberFormatter(),
      ],
      maxLength: 19,
      onChanged: (_) => setState(() {}),
      style: const TextStyle(color: AppColors.textPrimary, letterSpacing: 2),
      decoration: _inputDeco('Card Number', Icons.credit_card_rounded),
      validator: (v) {
        final digits = (v ?? '').replaceAll(' ', '');
        if (digits.length < 13) return 'Enter a valid card number';
        return null;
      },
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      focusNode: _nameFocus,
      textCapitalization: TextCapitalization.characters,
      onChanged: (_) => setState(() {}),
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: _inputDeco('Cardholder Name', Icons.person_outline_rounded),
      validator: (v) =>
          (v == null || v.trim().isEmpty) ? 'Enter cardholder name' : null,
    );
  }

  Widget _buildExpiryField() {
    return TextFormField(
      controller: _expiryController,
      focusNode: _expiryFocus,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        _ExpiryFormatter(),
      ],
      maxLength: 5,
      onChanged: (_) => setState(() {}),
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: _inputDeco('MM/YY', Icons.calendar_month_outlined),
      validator: (v) {
        if (v == null || v.length != 5) return 'Invalid';
        final parts = v.split('/');
        if (parts.length != 2) return 'Invalid';
        final month = int.tryParse(parts[0]);
        if (month == null || month < 1 || month > 12) return 'Invalid month';
        return null;
      },
    );
  }

  Widget _buildCvvField() {
    return TextFormField(
      controller: _cvvController,
      focusNode: _cvvFocus,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
      maxLength: 3,
      obscureText: false,
      onChanged: (_) => setState(() {}),
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: _inputDeco('CVV', Icons.credit_card_rounded),
      validator: (v) {
        if (v == null || v.length != 3) return 'Invalid';
        return null;
      },
    );
  }

  InputDecoration _inputDeco(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textHint),
      prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
      filled: true,
      fillColor: AppColors.surfaceLight,
      counterText: '',
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.glassBorder, width: 0.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.glassBorder, width: 0.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error, width: 1),
      ),
    );
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      Navigator.pop(context, {
        'number': _numberController.text.replaceAll(' ', ''),
        'name': _nameController.text.trim(),
        'expiry': _expiryController.text,
        'cvv': _cvvController.text,
      });
    }
  }
}

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(' ', '');
    final buf = StringBuffer();
    for (int i = 0; i < digits.length && i < 16; i++) {
      if (i > 0 && i % 4 == 0) buf.write(' ');
      buf.write(digits[i]);
    }
    final formatted = buf.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll('/', '');
    final buf = StringBuffer();
    for (int i = 0; i < digits.length && i < 4; i++) {
      if (i == 2) buf.write('/');
      buf.write(digits[i]);
    }
    final formatted = buf.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
