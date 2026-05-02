import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/business_provider.dart';
import '../../../providers/notification_provider.dart';
import '../shared/ticket_list_screen.dart';

class CustomerSettingsScreen extends StatefulWidget {
  const CustomerSettingsScreen({super.key});

  @override
  State<CustomerSettingsScreen> createState() => _CustomerSettingsScreenState();
}

class _CustomerSettingsScreenState extends State<CustomerSettingsScreen> {
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

  void _loadData() {
    final user = context.read<AuthProvider>().currentUser;
    if (user != null) {
      _nameController.text = user.name;
      _emailController.text = user.email;
      _phoneController.text = user.phone;
    }
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

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    // If new password is provided, require current password
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
      setState(() {
        _isEditing = false;
        _passwordController.clear();
        _currentPasswordController.clear();
      });
      _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error ?? 'Update failed'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            _buildSection(
              title: 'PERSONAL INFORMATION',
              icon: Icons.person_outline_rounded,
              color: AppColors.primary,
              child: Column(
                children: [
                  _buildField(_nameController, 'Full Name', Icons.person_outline),
                  _buildDivider(),
                  _buildField(_emailController, 'Email Address', Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress),
                  _buildDivider(),
                  _buildField(_phoneController, 'Phone Number', Icons.phone_outlined,
                      keyboardType: TextInputType.phone),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildSection(
              title: 'SECURITY',
              icon: Icons.lock_outline_rounded,
              color: AppColors.secondary,
              child: Column(
                children: [
                  _buildField(
                    _currentPasswordController,
                    'Current Password',
                    Icons.lock_outline_rounded,
                    isPassword: true,
                    required: false,
                  ),
                  _buildDivider(),
                  _buildField(
                    _passwordController,
                    'New Password (leave blank to keep)',
                    Icons.lock_reset_rounded,
                    isPassword: true,
                    required: false,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildSection(
              title: 'NOTIFICATIONS',
              icon: Icons.notifications_outlined,
              color: AppColors.info,
              child: Consumer<AuthProvider>(
                builder: (context, auth, _) {
                  final notificationsEnabled = auth.currentUser?.notificationsEnabled ?? true;
                  return SwitchListTile.adaptive(
                    value: notificationsEnabled,
                    onChanged: _updatingNotifications ? null : _toggleNotifications,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    title: const Text('Receive notifications'),
                    subtitle: const Text('Queue, message, ticket, and purchase updates are enabled by default.'),
                    activeTrackColor: AppColors.primary.withValues(alpha: 0.3),
                  );
                },
              ),
            ),
            const SizedBox(height: 32),
            if (_isEditing) ...[
              _buildSaveButton(),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  _loadData();
                  _passwordController.clear();
                  _currentPasswordController.clear();
                  setState(() => _isEditing = false);
                },
                child: const Text('Cancel', style: TextStyle(color: AppColors.textHint)),
              ),
            ] else ...[
              _buildEditButton(),
            ],
            const SizedBox(height: 24),
            _buildSupportButton(),
            const SizedBox(height: 12),
            _buildLogoutButton(),
            const SizedBox(height: 12),
            _buildDeleteAccountButton(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required IconData icon, required Color color, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color.withValues(alpha: 0.7)),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: 1.1,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.glassBorder, width: 0.5),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: child,
          ),
        ),
      ],
    );
  }

  Widget _buildField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    TextInputType? keyboardType,
    bool isPassword = false,
    bool required = true,
  }) {
    final canEdit = _isEditing;
    return Container(
      color: canEdit ? Colors.transparent : Colors.black.withValues(alpha: 0.05),
      child: TextFormField(
        controller: controller,
        enabled: canEdit,
        obscureText: isPassword,
        keyboardType: keyboardType,
        style: TextStyle(
          fontSize: 15,
          color: canEdit ? AppColors.textPrimary : AppColors.textHint,
          fontWeight: canEdit ? FontWeight.w500 : FontWeight.normal,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
          prefixIcon: Icon(icon, size: 20, color: canEdit ? AppColors.primaryLight : AppColors.textHint),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
        validator: required
            ? (v) => v == null || v.isEmpty ? 'This field cannot be empty' : null
            : null,
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, color: AppColors.glassBorder.withValues(alpha: 0.3), indent: 20, endIndent: 20);
  }

  Widget _buildEditButton() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _isEditing = true),
          borderRadius: BorderRadius.circular(16),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.edit_note_rounded, color: AppColors.primary, size: 20),
                SizedBox(width: 8),
                Text('Edit Profile', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        return Container(
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8)),
            ],
          ),
          child: ElevatedButton(
            onPressed: auth.isLoading ? null : _saveChanges,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: auth.isLoading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        );
      },
    );
  }

  Widget _buildSupportButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder, width: 0.5),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TicketListScreen())),
          borderRadius: BorderRadius.circular(16),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.support_agent_rounded, color: AppColors.primary, size: 20),
                SizedBox(width: 8),
                Text('Support Tickets', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Container(
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
    );
  }

  Widget _buildDeleteAccountButton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withValues(alpha: 0.15)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                backgroundColor: AppColors.surface,
                title: const Text('Delete Account', style: TextStyle(color: Colors.redAccent)),
                content: const Text('This will permanently delete your account and all your data. This action cannot be undone.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                  TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.redAccent))),
                ],
              ),
            );
            if (!mounted || confirm != true) return;
            await context.read<AuthProvider>().deleteAccount();
          },
          borderRadius: BorderRadius.circular(16),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 18),
                SizedBox(width: 8),
                Text('Delete Account', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600, fontSize: 14)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
