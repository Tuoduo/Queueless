import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/validators.dart';
import '../../../models/user_model.dart';
import '../../../models/business_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/business_provider.dart';
import 'role_selection_screen.dart';
import 'dart:math' as math;

class RegisterScreen extends StatefulWidget {
  final UserRole? selectedRole;
  const RegisterScreen({super.key, this.selectedRole});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  late UserRole _selectedRole;
  ServiceType _selectedServiceType = ServiceType.both;
  BusinessCategory _selectedCategory = BusinessCategory.other;
  final _businessNameController = TextEditingController();
  final _businessImageController = TextEditingController();
  final _businessAddressController = TextEditingController();

  late AnimationController _fadeController;
  late AnimationController _bgController;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.selectedRole ?? UserRole.customer;
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _businessNameController.dispose();
    _businessImageController.dispose();
    _businessAddressController.dispose();
    _fadeController.dispose();
    _bgController.dispose();
    super.dispose();
  }

  void _register() async {
    if (_formKey.currentState!.validate()) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final businessProvider = Provider.of<BusinessProvider>(context, listen: false);

      final success = await authProvider.register(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        phone: _phoneController.text.trim(),
        role: _selectedRole,
        serviceType: _selectedRole == UserRole.businessOwner ? _selectedServiceType : null,
        businessName: _selectedRole == UserRole.businessOwner ? _businessNameController.text.trim() : null,
        businessCategory: _selectedRole == UserRole.businessOwner ? _selectedCategory : null,
        businessAddress: _selectedRole == UserRole.businessOwner ? _businessAddressController.text.trim() : null,
      );

      if (success && _selectedRole == UserRole.businessOwner && mounted) {
        final newUser = authProvider.currentUser!;
        await businessProvider.loadOwnerBusiness(newUser.id);
      }

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration successful')),
        );
        Navigator.popUntil(context, (route) => route.isFirst);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.error ?? 'Registration failed'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.selectedRole == null) {
      return const RoleSelectionScreen();
    }

    return Scaffold(
      body: Stack(
        children: [
          // Animated background
          AnimatedBuilder(
            animation: _bgController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: const [
                      Color(0xFF06060F),
                      Color(0xFF0E0A2A),
                      Color(0xFF080D1E),
                    ],
                    begin: Alignment(
                      math.cos(_bgController.value * 2 * math.pi) * 0.5,
                      math.sin(_bgController.value * 2 * math.pi) * 0.5,
                    ),
                    end: Alignment(
                      -math.cos(_bgController.value * 2 * math.pi) * 0.5,
                      -math.sin(_bgController.value * 2 * math.pi) * 0.5,
                    ),
                  ),
                ),
              );
            },
          ),
          // Floating orb
          Positioned(
            top: -80,
            right: -60,
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _bgController,
                builder: (context, _) {
                  return Transform.translate(
                    offset: Offset(
                      15 * math.sin(_bgController.value * 2 * math.pi),
                      10 * math.cos(_bgController.value * 2 * math.pi),
                    ),
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            (_selectedRole == UserRole.customer
                                ? AppColors.primary : AppColors.secondary).withOpacity(0.15),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          // Content
          SafeArea(
            child: Column(
              children: [
                // Custom app bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.glassWhite,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.glassBorder, width: 0.5),
                          ),
                          child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Create Account',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              _selectedRole == UserRole.businessOwner ? 'Business Account' : 'Customer Account',
                              style: TextStyle(color: AppColors.textHint, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      // Role indicator
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _selectedRole == UserRole.customer
                                ? [AppColors.primary.withOpacity(0.15), AppColors.primary.withOpacity(0.05)]
                                : [AppColors.secondary.withOpacity(0.15), AppColors.secondary.withOpacity(0.05)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          _selectedRole == UserRole.customer ? Icons.person_outline : Icons.storefront_outlined,
                          color: _selectedRole == UserRole.customer ? AppColors.primary : AppColors.secondary,
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Form
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: AnimatedBuilder(
                      animation: _fadeController,
                      builder: (context, child) {
                        final progress = Curves.easeOutCubic.transform(_fadeController.value.clamp(0.0, 1.0));
                        return Opacity(
                          opacity: progress,
                          child: Transform.translate(
                            offset: Offset(0, 20 * (1 - progress)),
                            child: child,
                          ),
                        );
                      },
                      child: _buildForm(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color.withOpacity(0.7)),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 11,
            letterSpacing: 1.1,
            color: Colors.white.withOpacity(0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader('PERSONAL INFORMATION', Icons.person_outline_rounded, AppColors.primary),
          const SizedBox(height: 12),
          _buildGlassField(
            child: Column(
              children: [
                _buildInputField(
                  controller: _nameController,
                  label: AppStrings.fullName,
                  icon: Icons.person_outline,
                  validator: Validators.validateName,
                ),
                _buildDivider(),
                _buildInputField(
                  controller: _emailController,
                  label: AppStrings.email,
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.validateEmail,
                ),
                _buildDivider(),
                _buildInputField(
                  controller: _phoneController,
                  label: AppStrings.phone,
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: Validators.validatePhone,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('SECURITY', Icons.lock_outline_rounded, AppColors.primary),
          const SizedBox(height: 12),
          _buildGlassField(
            child: Column(
              children: [
                _buildInputField(
                  controller: _passwordController,
                  label: AppStrings.password,
                  icon: Icons.lock_outline,
                  isObscure: true,
                  validator: Validators.validatePassword,
                ),
                _buildDivider(),
                _buildInputField(
                  controller: _confirmPasswordController,
                  label: AppStrings.confirmPassword,
                  icon: Icons.lock_outline,
                  isObscure: true,
                  validator: (val) => Validators.validateConfirmPassword(val, _passwordController.text),
                ),
              ],
            ),
          ),

          if (_selectedRole == UserRole.businessOwner) ...[
            const SizedBox(height: 24),
            _buildSectionHeader('BUSINESS PROFILE', Icons.storefront_rounded, AppColors.secondary),
            const SizedBox(height: 12),
            _buildGlassField(
              child: Column(
                children: [
                  _buildInputField(
                    controller: _businessNameController,
                    label: 'Business Name',
                    icon: Icons.business_outlined,
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  _buildDivider(),
                  _buildInputField(
                    controller: _businessImageController,
                    label: 'Business Image URL (Optional)',
                    icon: Icons.image_outlined,
                  ),
                  _buildDivider(),
                  _buildInputField(
                    controller: _businessAddressController,
                    label: 'Business Address',
                    icon: Icons.location_on_outlined,
                  ),
                  _buildDivider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: DropdownButtonFormField<BusinessCategory>(
                      initialValue: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Business Category',
                        prefixIcon: Icon(Icons.category_outlined, size: 20),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                      dropdownColor: AppColors.surface,
                      items: BusinessCategory.values.map((cat) {
                        return DropdownMenuItem(
                          value: cat,
                          child: Text(cat.name[0].toUpperCase() + cat.name.substring(1)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => _selectedCategory = value);
                      },
                    ),
                  ),
                  _buildDivider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: DropdownButtonFormField<ServiceType>(
                      initialValue: _selectedServiceType == ServiceType.both ? ServiceType.queue : _selectedServiceType,
                      decoration: const InputDecoration(
                        labelText: 'Management System',
                        prefixIcon: Icon(Icons.settings_applications, size: 20),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                      dropdownColor: AppColors.surface,
                      items: const [
                        DropdownMenuItem(value: ServiceType.queue, child: Text('Queue Only')),
                        DropdownMenuItem(value: ServiceType.appointment, child: Text('Appointment Only')),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _selectedServiceType = value);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 32),

          // Register Button
          Consumer<AuthProvider>(
            builder: (context, auth, _) {
              return Container(
                decoration: BoxDecoration(
                  gradient: _selectedRole == UserRole.customer
                      ? AppColors.primaryGradient
                      : AppColors.accentGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: (_selectedRole == UserRole.customer
                          ? AppColors.primary : AppColors.secondary).withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: auth.isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 17),
                  ),
                  child: auth.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(AppStrings.signUp, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded, size: 20),
                          ],
                        ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(AppStrings.hasAccount, style: TextStyle(color: AppColors.textHint)),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(AppStrings.signIn, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryLight)),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildGlassField({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.glassGradient,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.glassBorder.withOpacity(0.4), width: 0.5),
      ),
      child: child,
    );
  }

  Widget _buildDivider() {
    return Divider(color: AppColors.glassBorder.withOpacity(0.2), height: 1);
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool isObscure = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
        prefixIcon: Icon(icon, color: AppColors.textHint, size: 20),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      keyboardType: keyboardType,
      obscureText: isObscure,
      validator: validator,
      style: const TextStyle(color: AppColors.textPrimary),
    );
  }
}
