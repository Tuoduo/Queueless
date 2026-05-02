import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/business_provider.dart';
import '../../providers/notification_provider.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isEditing = false;
  bool _updatingNotifications = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  void _loadData() {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    _nameController.text = user.name;
    _emailController.text = user.email;
    _phoneController.text = user.phone;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _currentPasswordController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordController.text.isNotEmpty && _currentPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your current password to change it'), backgroundColor: AppColors.error),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final success = await auth.updateProfile(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      password: _passwordController.text.isNotEmpty ? _passwordController.text : null,
      currentPassword: _currentPasswordController.text.isNotEmpty ? _currentPasswordController.text : null,
    );

    if (!mounted) return;
    if (success) {
      _passwordController.clear();
      _currentPasswordController.clear();
      _loadData();
      setState(() => _isEditing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully'), backgroundColor: AppColors.success),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(auth.error ?? 'Could not update the profile.'), backgroundColor: AppColors.error),
    );
  }

  Future<void> _toggleNotifications(bool enabled) async {
    setState(() => _updatingNotifications = true);
    final auth = context.read<AuthProvider>();
    final notificationProvider = context.read<NotificationProvider>();
    final success = await auth.updateNotificationPreference(enabled);
    if (success && enabled) {
      await notificationProvider.enableDeviceAlerts();
    }
    if (!mounted) return;
    setState(() => _updatingNotifications = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success
            ? (enabled ? 'Notifications are turned on.' : 'Notifications are turned off.')
            : (auth.error ?? 'Could not update notification settings.')),
        backgroundColor: success ? AppColors.success : AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final notificationsEnabled = auth.currentUser?.notificationsEnabled ?? true;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Form(
          key: _formKey,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppColors.cardGradient,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.glassBorder, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.person_outline_rounded, color: AppColors.primary),
                    SizedBox(width: 10),
                    Text('Profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 16),
                _buildField(_nameController, 'Full Name', Icons.person_outline_rounded),
                const SizedBox(height: 12),
                _buildField(_phoneController, 'Phone Number', Icons.phone_outlined, keyboardType: TextInputType.phone),
                const SizedBox(height: 12),
                _buildField(_emailController, 'Email Address', Icons.alternate_email_rounded, keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 12),
                _buildField(_currentPasswordController, 'Current Password', Icons.lock_outline_rounded, obscureText: true, required: false),
                const SizedBox(height: 12),
                _buildField(_passwordController, 'New Password', Icons.lock_reset_rounded, obscureText: true, required: false),
                const SizedBox(height: 16),
                if (_isEditing)
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: auth.isLoading ? null : _saveProfile,
                          child: auth.isLoading
                              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Save Profile'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: () {
                          _loadData();
                          _passwordController.clear();
                          _currentPasswordController.clear();
                          setState(() => _isEditing = false);
                        },
                        child: const Text('Cancel'),
                      ),
                    ],
                  )
                else
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _isEditing = true),
                    icon: const Icon(Icons.edit_note_rounded),
                    label: const Text('Edit Profile'),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppColors.cardGradient,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.glassBorder, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.notifications_active_outlined, color: AppColors.primary),
                  SizedBox(width: 10),
                  Text(
                    'Notifications',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Admin alerts stay enabled by default. Turn them off here if you do not want new business, ticket, or moderation updates.',
                style: TextStyle(color: AppColors.textHint, height: 1.4),
              ),
              const SizedBox(height: 16),
              SwitchListTile.adaptive(
                value: notificationsEnabled,
                onChanged: _updatingNotifications ? null : _toggleNotifications,
                contentPadding: EdgeInsets.zero,
                title: const Text('Receive notifications'),
                subtitle: const Text('Applies to the bell, in-app alerts, and device notifications.'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.1)),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                context.read<AuthProvider>().logout();
                context.read<BusinessProvider>().reset();
              },
              borderRadius: BorderRadius.circular(16),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
                    SizedBox(width: 8),
                    Text('Sign Out', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    bool obscureText = false,
    bool required = true,
  }) {
    return TextFormField(
      controller: controller,
      enabled: _isEditing,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
      validator: required ? (value) => value == null || value.trim().isEmpty ? 'This field cannot be empty' : null : null,
    );
  }
}