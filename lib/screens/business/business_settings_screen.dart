import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/category_themes.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/business_provider.dart';
import '../../../providers/notification_provider.dart';
import '../../../models/business_model.dart';
import '../../../widgets/business_location_picker.dart';
import '../../../widgets/category_background.dart';
import '../shared/ticket_list_screen.dart';
import 'discount_management_screen.dart';

class BusinessSettingsScreen extends StatefulWidget {
  const BusinessSettingsScreen({super.key});

  @override
  State<BusinessSettingsScreen> createState() => _BusinessSettingsScreenState();
}

class _BusinessSettingsScreenState extends State<BusinessSettingsScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _ownerNameController = TextEditingController();
  final _ownerPhoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _passwordController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _imageController = TextEditingController();
  final _addressController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _businessPhoneController = TextEditingController();
  LatLng? _selectedLocation;
  
  bool _isEditing = false;
  bool _updatingNotifications = false;
  BusinessModel? _currentBusiness;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
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
    final auth = context.read<AuthProvider>();
    final businessProvider = context.read<BusinessProvider>();
    final user = auth.currentUser;
    
    if (user != null) {
      _ownerNameController.text = user.name;
      _ownerPhoneController.text = user.phone;
      _emailController.text = user.email;
      _currentBusiness = businessProvider.getBusinessByOwnerId(user.id);
      
      if (_currentBusiness != null) {
        _businessNameController.text = _currentBusiness!.name;
        _descriptionController.text = _currentBusiness!.description;
        _imageController.text = _currentBusiness!.imageUrl ?? '';
        _addressController.text = _currentBusiness!.address;
        _selectedLocation = _currentBusiness!.hasCoordinates
            ? LatLng(_currentBusiness!.latitude!, _currentBusiness!.longitude!)
            : null;
        _latitudeController.text = _selectedLocation?.latitude.toStringAsFixed(7) ?? '';
        _longitudeController.text = _selectedLocation?.longitude.toStringAsFixed(7) ?? '';
        _businessPhoneController.text = _currentBusiness!.phone;
      } else {
        _selectedLocation = null;
        _latitudeController.clear();
        _longitudeController.clear();
        _businessPhoneController.clear();
      }
      setState(() {});
    }
  }

  @override
  void dispose() {
    _ownerNameController.dispose();
    _ownerPhoneController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _passwordController.dispose();
    _businessNameController.dispose();
    _descriptionController.dispose();
    _imageController.dispose();
    _addressController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _businessPhoneController.dispose();
    super.dispose();
  }

  void _setSelectedLocation(LatLng? location) {
    _selectedLocation = location;
    _latitudeController.text = location?.latitude.toStringAsFixed(7) ?? '';
    _longitudeController.text = location?.longitude.toStringAsFixed(7) ?? '';
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _saveChanges() async {
    if (_formKey.currentState!.validate()) {
      final auth = context.read<AuthProvider>();
      final businessProvider = context.read<BusinessProvider>();

      // If new password, require current password
      if (_passwordController.text.isNotEmpty && _currentPasswordController.text.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter your current password to change it'), backgroundColor: AppColors.error),
          );
        }
        return;
      }
      
      if (_currentBusiness != null) {
        try {
          final latitude = _selectedLocation?.latitude;
          final longitude = _selectedLocation?.longitude;
          await businessProvider.updateBusiness(_currentBusiness!.id, {
            'name': _businessNameController.text.trim(),
            'description': _descriptionController.text.trim(),
            'image_url': _imageController.text.trim().isNotEmpty ? _imageController.text.trim() : null,
            'address': _addressController.text.trim(),
            'latitude': latitude,
            'longitude': longitude,
            'phone': _businessPhoneController.text.trim(),
            'category': _currentBusiness!.category.name,
            'service_type': _currentBusiness!.serviceType.name,
          });
          _currentBusiness = businessProvider.getBusinessById(_currentBusiness!.id) ?? _currentBusiness;
          // Update owner profile data if it changed.
          final currentEmail = auth.currentUser?.email ?? '';
          final currentName = auth.currentUser?.name ?? '';
          final currentPhone = auth.currentUser?.phone ?? '';
          final hasNameChange = _ownerNameController.text.trim() != currentName;
          final hasEmailChange = _emailController.text.trim() != currentEmail;
          final hasPhoneChange = _ownerPhoneController.text.trim() != currentPhone;
          final hasPasswordChange = _passwordController.text.isNotEmpty;
          if (hasNameChange || hasEmailChange || hasPhoneChange || hasPasswordChange) {
            await auth.updateProfile(
              name: _ownerNameController.text.trim(),
              email: _emailController.text.trim(),
              phone: _ownerPhoneController.text.trim(),
              password: hasPasswordChange ? _passwordController.text : null,
              currentPassword: hasPasswordChange ? _currentPasswordController.text : null,
            );
          }
          
          if (mounted) {
            setState(() => _isEditing = false);
            _passwordController.clear();
            _currentPasswordController.clear();
            _loadData();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Settings updated successfully')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
            );
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = _currentBusiness != null 
        ? CategoryThemes.getTheme(_currentBusiness!.category)
        : CategoryThemes.getTheme(BusinessCategory.other);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Dynamic category background for the top
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 220,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
              child: CategoryBackground(
                theme: theme,
                width: double.maxFinite,
                height: double.maxFinite,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black.withValues(alpha: 0.2), Colors.black.withValues(alpha: 0.6)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 20),
                          _buildPremiumSection(
                            title: 'BUSINESS PROFILE',
                            icon: Icons.storefront_rounded,
                            color: theme.primaryColor,
                            child: Column(
                              children: [
                                _buildGlassTextField(_businessNameController, 'Business Name', Icons.business_rounded),
                                _buildDivider(),
                                _buildGlassTextField(_descriptionController, 'Description', Icons.description_outlined, maxLines: 3),
                                _buildDivider(),
                                _buildGlassTextField(
                                  _businessPhoneController,
                                  'Business Phone Number',
                                  Icons.phone_outlined,
                                  required: false,
                                ),
                                _buildDivider(),
                                _buildGlassTextField(
                                  _imageController,
                                  'Cover Image URL',
                                  Icons.image_search_rounded,
                                  required: false,
                                ),
                                _buildDivider(),
                                _buildGlassTextField(_addressController, 'Business Address', Icons.location_on_outlined),
                                _buildDivider(),
                                Padding(
                                  padding: const EdgeInsets.all(18),
                                  child: BusinessLocationPicker(
                                    isEditing: _isEditing,
                                    selectedLocation: _selectedLocation,
                                    onLocationChanged: _setSelectedLocation,
                                  ),
                                ),
                                _buildDivider(),
                                _buildGlassTextField(
                                  _latitudeController,
                                  'Latitude',
                                  Icons.my_location_rounded,
                                  enabled: false,
                                  required: false,
                                ),
                                _buildDivider(),
                                _buildGlassTextField(
                                  _longitudeController,
                                  'Longitude',
                                  Icons.explore_outlined,
                                  enabled: false,
                                  required: false,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          _buildPremiumSection(
                            title: 'DISCOUNT & COUPONS',
                            icon: Icons.local_offer_rounded,
                            color: AppColors.primary,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  if (_currentBusiness != null) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => DiscountManagementScreen(businessId: _currentBusiness!.id),
                                      ),
                                    );
                                  }
                                },
                                borderRadius: BorderRadius.circular(22),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.local_offer_rounded, color: AppColors.primaryLight, size: 22),
                                      const SizedBox(width: 14),
                                      const Expanded(
                                        child: Text(
                                          'Manage Discount Coupons',
                                          style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                      const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          _buildPremiumSection(
                            title: 'ACCOUNT ACCESS',
                            icon: Icons.vpn_key_rounded,
                            color: AppColors.secondary,
                            child: Column(
                              children: [
                                _buildGlassTextField(_ownerNameController, 'Owner Name', Icons.person_outline_rounded),
                                _buildDivider(),
                                _buildGlassTextField(_ownerPhoneController, 'Owner Phone Number', Icons.phone_rounded),
                                _buildDivider(),
                                _buildGlassTextField(_emailController, 'Email Address', Icons.alternate_email_rounded),
                                _buildDivider(),
                                _buildGlassTextField(_currentPasswordController, 'Current Password', Icons.lock_outline_rounded, isObscure: true, required: false),
                                _buildDivider(),
                                _buildGlassTextField(_passwordController, 'New Password', Icons.lock_reset_rounded, isObscure: true, required: false),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          _buildPremiumSection(
                            title: 'NOTIFICATIONS',
                            icon: Icons.notifications_active_outlined,
                            color: AppColors.info,
                            child: Consumer<AuthProvider>(
                              builder: (context, auth, _) {
                                final notificationsEnabled = auth.currentUser?.notificationsEnabled ?? true;
                                return SwitchListTile.adaptive(
                                  value: notificationsEnabled,
                                  onChanged: _updatingNotifications ? null : _toggleNotifications,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                                  title: const Text('Receive notifications'),
                                  subtitle: const Text('Messages, queue changes, approvals, and support replies are enabled by default.'),
                                  activeTrackColor: AppColors.primary.withValues(alpha: 0.3),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 32),
                          if (!_isEditing) ...[_buildSupportButton(), const SizedBox(height: 12), _buildLogoutButton(), const SizedBox(height: 16), _buildDeleteAccountButton()] else const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _isEditing ? FloatingActionButton.extended(
        onPressed: _saveChanges,
        backgroundColor: theme.primaryColor,
        icon: const Icon(Icons.save_rounded, color: Colors.white),
        label: const Text('Save Changes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ) : null,
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Settings',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          if (!_isEditing)
            IconButton(
              onPressed: () => setState(() => _isEditing = true),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.glassWhite,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.edit_note_rounded, color: Colors.white),
            )
          else
            TextButton(
              onPressed: () {
                _loadData();
                _passwordController.clear();
                _currentPasswordController.clear();
                setState(() => _isEditing = false);
              },
              child: const Text('Cancel', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }

  Widget _buildPremiumSection({required String title, required IconData icon, required Color color, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: color.withValues(alpha: 0.8)),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                letterSpacing: 1.2,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.glassBorder, width: 0.5),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: child,
          ),
        ),
      ],
    );
  }

  Widget _buildGlassTextField(TextEditingController controller, String hint, IconData icon, {bool isObscure = false, int maxLines = 1, bool enabled = true, bool required = true, TextInputType? keyboardType}) {
    final bool canEdit = _isEditing && enabled;
    return Container(
      color: canEdit ? Colors.transparent : Colors.black.withValues(alpha: 0.05),
      child: TextFormField(
        controller: controller,
        obscureText: isObscure,
        maxLines: maxLines,
        enabled: canEdit,
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
          onTap: () => context.read<AuthProvider>().logout(),
          borderRadius: BorderRadius.circular(16),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
                SizedBox(width: 8),
                Text(
                  'Sign Out',
                  style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 15),
                ),
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
                content: const Text('This will permanently delete your business and account. This action cannot be undone.'),
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
