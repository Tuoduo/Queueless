import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/category_themes.dart';
import '../../models/business_model.dart';
import '../../services/api_service.dart';

class AdminBusinessesScreen extends StatefulWidget {
  final String initialStatusFilter;

  const AdminBusinessesScreen({super.key, this.initialStatusFilter = 'pending'});

  @override
  State<AdminBusinessesScreen> createState() => _AdminBusinessesScreenState();
}

class _AdminBusinessesScreenState extends State<AdminBusinessesScreen> {
  List<Map<String, dynamic>> _businesses = [];
  bool _loading = true;
  String? _error;
  int _page = 1;
  int _total = 0;
  late String _statusFilter;
  String _categoryFilter = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _statusFilter = widget.initialStatusFilter;
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load([int page = 1]) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var url = '/admin/businesses?page=$page&limit=20';
      if (_statusFilter.isNotEmpty) url += '&status=$_statusFilter';
      if (_categoryFilter.isNotEmpty) url += '&category=$_categoryFilter';
      final query = _searchController.text.trim();
      if (query.isNotEmpty) url += '&search=${Uri.encodeQueryComponent(query)}';
      final result = await ApiService.get(url);
      if (!mounted) return;
      setState(() {
        _businesses = List<Map<String, dynamic>>.from(result['businesses'] ?? []);
        _total = (result['total'] as num?)?.toInt() ?? 0;
        _page = page;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _cleanError(error);
      });
    }
  }

  Future<void> _approve(String id) async {
    try {
      await ApiService.put('/admin/businesses/$id/approve', {});
      _load(_page);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_cleanError(error)), backgroundColor: AppColors.error));
    }
  }

  Future<void> _reject(String id) async {
    try {
      await ApiService.put('/admin/businesses/$id/reject', {});
      _load(_page);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_cleanError(error)), backgroundColor: AppColors.error));
    }
  }

  Future<void> _openBusinessDetail(Map<String, dynamic> business) async {
    final businessId = business['id']?.toString() ?? '';
    if (businessId.isEmpty) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _AdminBusinessDetailSheet(
        businessId: businessId,
        businessName: business['name']?.toString() ?? 'Business',
        onUpdated: () => _load(_page),
      ),
    );

    if (mounted) _load(_page);
  }

  @override
  Widget build(BuildContext context) {
    final isPendingTab = _statusFilter == 'pending';
    final isAllTab = _statusFilter.isEmpty;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search businesses...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onSubmitted: (_) => _load(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: _load,
                    icon: const Icon(Icons.search_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ChoiceChip(
                    label: const Text('Pending Approval'),
                    selected: isPendingTab,
                    onSelected: (_) {
                      if (_statusFilter == 'pending') return;
                      setState(() => _statusFilter = 'pending');
                      _load();
                    },
                  ),
                  ChoiceChip(
                    label: const Text('All Businesses'),
                    selected: isAllTab,
                    onSelected: (_) {
                      if (_statusFilter.isEmpty) return;
                      setState(() => _statusFilter = '');
                      _load();
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Managed Businesses'),
                    selected: !isPendingTab && !isAllTab,
                    onSelected: (_) {
                      if (_statusFilter == 'approved') return;
                      setState(() => _statusFilter = 'approved');
                      _load();
                    },
                  ),
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<String>(
                      key: ValueKey(_categoryFilter),
                      isExpanded: true,
                      initialValue: _categoryFilter.isEmpty ? null : _categoryFilter,
                      isDense: true,
                      decoration: InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: [
                        const DropdownMenuItem<String>(value: '', child: Text('All categories')),
                        ..._categoryValues.map(
                          (value) => DropdownMenuItem<String>(
                            value: value,
                            child: Text(_formatCategoryLabel(value)),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() => _categoryFilter = value ?? '');
                        _load();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${isPendingTab ? 'Pending approval' : isAllTab ? 'All businesses' : 'Managed businesses'}: $_total',
              style: const TextStyle(color: AppColors.textHint, fontSize: 12),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _buildErrorState()
                  : _businesses.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: () => _load(_page),
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: _businesses.length,
                            itemBuilder: (context, index) => _buildBusinessCard(_businesses[index]),
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.18)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.store_mall_directory_outlined, size: 34, color: AppColors.error),
              const SizedBox(height: 12),
              const Text('Could not load businesses', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(_error ?? '', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textHint, fontSize: 12)),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: AppColors.cardGradient,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.glassBorder, width: 0.5),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.storefront_outlined, size: 34, color: AppColors.textHint),
              SizedBox(height: 12),
              Text('No businesses match this filter', style: TextStyle(fontWeight: FontWeight.w700)),
              SizedBox(height: 6),
              Text('Adjust the search or category filter and try again.', style: TextStyle(color: AppColors.textHint, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBusinessCard(Map<String, dynamic> business) {
    final name = business['name']?.toString() ?? 'Unknown';
    final ownerName = business['owner_name']?.toString() ?? '';
    final category = business['category']?.toString() ?? 'other';
    final serviceType = business['service_type']?.toString() ?? 'queue';
    final status = business['approval_status']?.toString() ?? 'pending';
    final id = business['id']?.toString() ?? '';
    final rating = _asDouble(business['rating']);
    final theme = _categoryTheme(category);

    final statusColor = switch (status) {
      'approved' => AppColors.success,
      'rejected' => AppColors.error,
      _ => AppColors.warning,
    };

    return GestureDetector(
      onTap: () => _openBusinessDetail(business),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: AppColors.cardGradient,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.glassBorder, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      if (ownerName.isNotEmpty)
                        Text('Owner: $ownerName', style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor),
                      ),
                    ),
                    if (rating > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, size: 14, color: AppColors.vip),
                          Text(rating.toStringAsFixed(1), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _CategoryChip(label: _formatCategoryLabel(category), theme: theme),
                _InfoChip(icon: Icons.tune_rounded, label: _formatServiceType(serviceType), color: theme.accentColor),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: id.isEmpty ? null : () => _openBusinessDetail(business),
                    icon: const Icon(Icons.settings_suggest_rounded, size: 18),
                    label: const Text('Manage'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.primaryColor,
                      side: BorderSide(color: theme.primaryColor.withValues(alpha: 0.35)),
                    ),
                  ),
                ),
                if (status == 'pending') ...[
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => _reject(id),
                    icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.error),
                    label: const Text('Reject', style: TextStyle(color: AppColors.error)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _approve(id),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminBusinessDetailSheet extends StatefulWidget {
  final String businessId;
  final String businessName;
  final VoidCallback onUpdated;

  const _AdminBusinessDetailSheet({
    required this.businessId,
    required this.businessName,
    required this.onUpdated,
  });

  @override
  State<_AdminBusinessDetailSheet> createState() => _AdminBusinessDetailSheetState();
}

class _AdminBusinessDetailSheetState extends State<_AdminBusinessDetailSheet> {
  Map<String, dynamic>? _business;
  Map<String, dynamic>? _queue;
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _slots = [];
  List<Map<String, dynamic>> _queueEntries = [];
  List<Map<String, dynamic>> _appointments = [];
  bool _loading = true;
  String? _error;

  String get _serviceType => _business?['service_type']?.toString() ?? 'queue';
  String get _categoryKey => _business?['category']?.toString() ?? 'other';
  CategoryTheme get _theme => _categoryTheme(_categoryKey);

  List<Map<String, dynamic>> get _servingEntries {
    final items = _queueEntries.where((entry) => entry['status']?.toString() == 'serving').toList();
    items.sort((a, b) => _asInt(a['position']).compareTo(_asInt(b['position'])));
    return items;
  }

  List<Map<String, dynamic>> get _waitingEntries {
    final items = _queueEntries.where((entry) => entry['status']?.toString() == 'waiting').toList();
    items.sort((a, b) => _asInt(a['position']).compareTo(_asInt(b['position'])));
    return items;
  }

  String get _catalogLabel {
    switch (_serviceType) {
      case 'appointment':
        return 'Services';
      case 'both':
        return 'Products & Services';
      default:
        return 'Products';
    }
  }

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail({bool showLoader = true}) async {
    if (showLoader) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final result = await ApiService.get('/admin/businesses/${widget.businessId}/detail');
      if (!mounted) return;
      setState(() {
        _business = Map<String, dynamic>.from(result['business'] ?? const {});
        _queue = result['queue'] == null ? null : Map<String, dynamic>.from(result['queue']);
        _products = List<Map<String, dynamic>>.from(result['products'] ?? const []);
        _slots = List<Map<String, dynamic>>.from(result['slots'] ?? const []);
        _queueEntries = List<Map<String, dynamic>>.from(result['queueEntries'] ?? const []);
        _appointments = List<Map<String, dynamic>>.from(result['appointments'] ?? const []);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _cleanError(error);
      });
    }
  }

  Future<void> _editBusinessInfo() async {
    if (_business == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final nameController = TextEditingController(text: _business?['name']?.toString() ?? '');
    final descriptionController = TextEditingController(text: _business?['description']?.toString() ?? '');
    final addressController = TextEditingController(text: _business?['address']?.toString() ?? '');
    final phoneController = TextEditingController(text: _business?['phone']?.toString() ?? '');
    var category = _categoryKey;
    var serviceType = _serviceType;
    var approvalStatus = _business?['approval_status']?.toString() ?? 'pending';
    var isActive = _asBool(_business?['is_active'], fallback: true);
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> save() async {
              if (saving) return;
              setDialogState(() => saving = true);
              try {
                await ApiService.put('/admin/businesses/${widget.businessId}', {
                  'name': nameController.text.trim(),
                  'description': descriptionController.text.trim(),
                  'address': addressController.text.trim(),
                  'phone': phoneController.text.trim(),
                  'category': category,
                  'service_type': serviceType,
                  'approval_status': approvalStatus,
                  'is_active': isActive,
                });
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                await _loadDetail(showLoader: false);
                widget.onUpdated();
                messenger.showSnackBar(const SnackBar(content: Text('Business details updated.')));
              } catch (error) {
                messenger.showSnackBar(SnackBar(content: Text(_cleanError(error)), backgroundColor: AppColors.error));
                if (dialogContext.mounted) setDialogState(() => saving = false);
              }
            }

            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Text('Edit Business'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Business name')),
                    const SizedBox(height: 12),
                    TextField(controller: descriptionController, maxLines: 3, decoration: const InputDecoration(labelText: 'Description')),
                    const SizedBox(height: 12),
                    TextField(controller: addressController, decoration: const InputDecoration(labelText: 'Address')),
                    const SizedBox(height: 12),
                    TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Phone')),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: _categoryValues
                          .map((value) => DropdownMenuItem(value: value, child: Text(_formatCategoryLabel(value))))
                          .toList(),
                      onChanged: (value) => setDialogState(() => category = value ?? category),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: serviceType,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Service type'),
                      items: const [
                        DropdownMenuItem(value: 'queue', child: Text('Queue')),
                        DropdownMenuItem(value: 'appointment', child: Text('Appointments')),
                        DropdownMenuItem(value: 'both', child: Text('Queue + Appointments')),
                      ],
                      onChanged: (value) => setDialogState(() => serviceType = value ?? serviceType),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: approvalStatus,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Approval status'),
                      items: const [
                        DropdownMenuItem(value: 'pending', child: Text('Pending')),
                        DropdownMenuItem(value: 'approved', child: Text('Approved')),
                        DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                      ],
                      onChanged: (value) => setDialogState(() => approvalStatus = value ?? approvalStatus),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                      value: isActive,
                      onChanged: (value) => setDialogState(() => isActive = value),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Business active'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: saving ? null : save,
                  child: saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _editProduct(Map<String, dynamic> product) async {
    final messenger = ScaffoldMessenger.of(context);
    final nameController = TextEditingController(text: product['name']?.toString() ?? '');
    final priceController = TextEditingController(text: _asDouble(product['price']).toStringAsFixed(2));
    final durationController = TextEditingController(text: _asInt(product['duration_minutes']).toString());
    final stockController = TextEditingController(text: _asInt(product['stock']).toString());

    var isAvailable = _asBool(product['is_available'], fallback: true);
    var isOffSale = _asBool(product['is_off_sale']);
    var submitting = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> save() async {
              if (submitting) return;
              setDialogState(() => submitting = true);
              try {
                await ApiService.put('/admin/products/${product['id']}', {
                  'name': nameController.text.trim(),
                  'price': double.tryParse(priceController.text.trim()) ?? 0,
                  'duration_minutes': int.tryParse(durationController.text.trim()) ?? 0,
                  'stock': int.tryParse(stockController.text.trim()) ?? 0,
                  'is_available': isAvailable,
                  'is_off_sale': isOffSale,
                });
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                await _loadDetail(showLoader: false);
                widget.onUpdated();
                messenger.showSnackBar(const SnackBar(content: Text('Catalog item updated successfully')));
              } catch (error) {
                messenger.showSnackBar(SnackBar(content: Text(_cleanError(error)), backgroundColor: AppColors.error));
                if (dialogContext.mounted) setDialogState(() => submitting = false);
              }
            }

            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Text('Edit ${_serviceType == 'appointment' ? 'Service' : 'Item'}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Price'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: durationController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Duration (minutes)'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: stockController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Stock (0 = unlimited)'),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      value: isAvailable,
                      onChanged: (value) => setDialogState(() => isAvailable = value),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Available'),
                    ),
                    SwitchListTile.adaptive(
                      value: isOffSale,
                      onChanged: (value) => setDialogState(() => isOffSale = value),
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: const Color(0xFF7AAF91),
                      activeTrackColor: const Color(0xFFDDEFE3),
                      inactiveThumbColor: const Color(0xFFF4F8F5),
                      inactiveTrackColor: const Color(0xFFDDE7E1),
                      title: const Text('Off sale'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: submitting ? null : save,
                  child: submitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showSlotEditor({Map<String, dynamic>? slot}) async {
    final messenger = ScaffoldMessenger.of(context);
    final initialStart = _tryParseDateTime(slot?['start_time']) ?? DateTime.now().add(const Duration(hours: 1));
    final initialEnd = _tryParseDateTime(slot?['end_time']) ?? initialStart.add(const Duration(hours: 1));
    var selectedDate = DateTime(initialStart.year, initialStart.month, initialStart.day);
    var startTime = TimeOfDay.fromDateTime(initialStart);
    var endTime = TimeOfDay.fromDateTime(initialEnd);
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pickDate() async {
              final picked = await showDatePicker(
                context: dialogContext,
                initialDate: selectedDate,
                firstDate: DateTime.now().subtract(const Duration(days: 1)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null && dialogContext.mounted) {
                setDialogState(() => selectedDate = picked);
              }
            }

            Future<void> pickStartTime() async {
              final picked = await showTimePicker(
                context: dialogContext,
                initialTime: startTime,
                helpText: 'Select start time',
              );
              if (picked != null && dialogContext.mounted) {
                setDialogState(() => startTime = picked);
              }
            }

            Future<void> pickEndTime() async {
              final picked = await showTimePicker(
                context: dialogContext,
                initialTime: endTime,
                helpText: 'Select end time',
              );
              if (picked != null && dialogContext.mounted) {
                setDialogState(() => endTime = picked);
              }
            }

            Future<void> save() async {
              if (saving) return;

              final startDateTime = DateTime(
                selectedDate.year,
                selectedDate.month,
                selectedDate.day,
                startTime.hour,
                startTime.minute,
              );
              final endDateTime = DateTime(
                selectedDate.year,
                selectedDate.month,
                selectedDate.day,
                endTime.hour,
                endTime.minute,
              );

              if (!endDateTime.isAfter(startDateTime)) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('End time must be after start time.'),
                    backgroundColor: AppColors.error,
                  ),
                );
                return;
              }

              setDialogState(() => saving = true);

              try {
                final payload = {
                  'business_id': widget.businessId,
                  'start_time': startDateTime.toIso8601String(),
                  'end_time': endDateTime.toIso8601String(),
                };

                if (slot == null) {
                  await ApiService.post('/appointments/slots', payload);
                } else {
                  await ApiService.put('/appointments/slots/${slot['id']}', payload);
                }

                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                await _loadDetail(showLoader: false);
                widget.onUpdated();
                messenger.showSnackBar(
                  SnackBar(content: Text(slot == null ? 'Time slot created.' : 'Time slot updated.')),
                );
              } catch (error) {
                messenger.showSnackBar(
                  SnackBar(content: Text(_cleanError(error)), backgroundColor: AppColors.error),
                );
                if (dialogContext.mounted) setDialogState(() => saving = false);
              }
            }

            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Text(slot == null ? 'Add Time Slot' : 'Edit Time Slot'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_rounded, color: AppColors.primary),
                    title: const Text('Date'),
                    subtitle: Text(_formatDateTime(selectedDate)),
                    onTap: pickDate,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.login_rounded, color: AppColors.secondary),
                    title: const Text('Start time'),
                    subtitle: Text(startTime.format(dialogContext)),
                    onTap: pickStartTime,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.logout_rounded, color: AppColors.warning),
                    title: const Text('End time'),
                    subtitle: Text(endTime.format(dialogContext)),
                    onTap: pickEndTime,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: saving ? null : save,
                  child: saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteSlot(Map<String, dynamic> slot) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Delete Time Slot'),
          content: const Text('This will remove the selected availability block. Booked slots cannot be deleted.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await ApiService.delete('/appointments/slots/${slot['id']}');
      await _loadDetail(showLoader: false);
      widget.onUpdated();
      messenger.showSnackBar(const SnackBar(content: Text('Time slot deleted.')));
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(_cleanError(error)), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _reorderQueue(List<Map<String, dynamic>> reorderedEntries) async {
    try {
      await ApiService.post('/admin/businesses/${widget.businessId}/queue/reorder', {
        'orderedEntryIds': reorderedEntries.map((entry) => entry['id']).toList(),
      });
      await _loadDetail(showLoader: false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Queue order updated.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_cleanError(error)), backgroundColor: AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.55,
      maxChildSize: 0.96,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 36, color: AppColors.error),
                          const SizedBox(height: 12),
                          Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textHint)),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _loadDetail,
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      controller: scrollController,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(widget.businessName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 4),
                                  Text(
                                    _business?['address']?.toString() ?? 'No address available',
                                    style: const TextStyle(color: AppColors.textHint, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded)),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: AppColors.cardGradient,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.glassBorder, width: 0.5),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  _CategoryChip(label: _formatCategoryLabel(_categoryKey), theme: _theme),
                                  _InfoChip(icon: Icons.tune_rounded, label: _formatServiceType(_serviceType), color: _theme.accentColor),
                                  _InfoChip(icon: Icons.inventory_2_outlined, label: '${_products.length} $_catalogLabel', color: AppColors.info),
                                  if (_serviceType != 'queue')
                                    _InfoChip(icon: Icons.calendar_today_rounded, label: '${_appointments.length} active appointments', color: AppColors.warning),
                                  if (_serviceType != 'appointment')
                                    _InfoChip(icon: Icons.people_outline_rounded, label: '${_queueEntries.length} active queue', color: AppColors.success),
                                  _InfoChip(
                                    icon: _asBool(_business?['is_active'], fallback: true) ? Icons.check_circle_outline_rounded : Icons.pause_circle_outline_rounded,
                                    label: _asBool(_business?['is_active'], fallback: true) ? 'Active' : 'Disabled',
                                    color: _asBool(_business?['is_active'], fallback: true) ? AppColors.success : AppColors.error,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(_business?['description']?.toString().trim().isNotEmpty == true ? _business!['description'].toString() : 'No description provided.'),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 10,
                                runSpacing: 8,
                                children: [
                                  if ((_business?['phone']?.toString() ?? '').isNotEmpty)
                                    Text('Phone: ${_business?['phone']}', style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
                                  Text('Approval: ${(_business?['approval_status'] ?? 'pending').toString()}', style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
                                ],
                              ),
                              const SizedBox(height: 14),
                              OutlinedButton.icon(
                                onPressed: _editBusinessInfo,
                                icon: const Icon(Icons.edit_rounded, size: 16),
                                label: const Text('Edit Business Info'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _theme.primaryColor,
                                  side: BorderSide(color: _theme.primaryColor.withValues(alpha: 0.35)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        _SectionCard(
                          title: _catalogLabel,
                          subtitle: 'Admin can intervene in this business catalog directly from the moderation panel.',
                          child: _products.isEmpty
                              ? const Text('This business has no catalog items yet.', style: TextStyle(color: AppColors.textHint))
                              : Column(
                                  children: _products.map((product) {
                                    final isAvailable = _asBool(product['is_available'], fallback: true);
                                    final isOffSale = _asBool(product['is_off_sale']);
                                    final stock = _asInt(product['stock']);
                                    final duration = _asInt(product['duration_minutes']);
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        gradient: AppColors.cardGradient,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: AppColors.glassBorder, width: 0.5),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(product['name']?.toString() ?? 'Unnamed item', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                                    const SizedBox(height: 4),
                                                    Text('\$${_asDouble(product['price']).toStringAsFixed(2)}', style: const TextStyle(color: AppColors.secondary, fontWeight: FontWeight.w700)),
                                                  ],
                                                ),
                                              ),
                                              OutlinedButton.icon(
                                                onPressed: () => _editProduct(product),
                                                icon: const Icon(Icons.edit_rounded, size: 16),
                                                label: const Text('Edit'),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              _InfoChip(
                                                icon: isAvailable ? Icons.check_circle_outline_rounded : Icons.pause_circle_outline_rounded,
                                                label: isAvailable ? 'Available' : 'Hidden',
                                                color: isAvailable ? AppColors.success : AppColors.warning,
                                              ),
                                              _InfoChip(icon: Icons.timelapse_rounded, label: '$duration min', color: AppColors.primary),
                                              _InfoChip(
                                                icon: Icons.inventory_2_outlined,
                                                label: stock == 0 ? 'Unlimited stock' : '$stock in stock',
                                                color: AppColors.info,
                                              ),
                                              if (isOffSale)
                                                const _InfoChip(icon: Icons.block_rounded, label: 'Off sale', color: Color(0xFF7AAF91)),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                        ),
                        if (_serviceType != 'appointment') ...[
                          const SizedBox(height: 18),
                          _SectionCard(
                            title: 'Queue Management',
                            subtitle: 'Inspect each queued customer and drag waiting entries into a new order.',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_queue != null)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        _InfoChip(
                                          icon: _asBool(_queue?['is_paused']) ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded,
                                          label: _asBool(_queue?['is_paused']) ? 'Queue paused' : 'Queue live',
                                          color: _asBool(_queue?['is_paused']) ? AppColors.warning : AppColors.success,
                                        ),
                                        _InfoChip(
                                          icon: Icons.people_outline_rounded,
                                          label: '${_waitingEntries.length + _servingEntries.length} active customers',
                                          color: AppColors.info,
                                        ),
                                      ],
                                    ),
                                  ),
                                if (_servingEntries.isNotEmpty) ...[
                                  const Text('Serving Now', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 8),
                                  ..._servingEntries.map((entry) => _AdminQueueEntryCard(entry: entry, onViewDetails: () => _showQueueEntryDetails(entry))),
                                  const SizedBox(height: 14),
                                ],
                                const Text('Waiting Queue', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 4),
                                const Text('Drag to change who will be called next.', style: TextStyle(fontSize: 12, color: AppColors.textHint)),
                                const SizedBox(height: 10),
                                if (_waitingEntries.isEmpty)
                                  const Text('No waiting customers.', style: TextStyle(color: AppColors.textHint))
                                else
                                  DragBoundary(
                                    child: Container(
                                      clipBehavior: Clip.hardEdge,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: ReorderableListView.builder(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        buildDefaultDragHandles: false,
                                        dragBoundaryProvider: DragBoundary.forRectOf,
                                        itemCount: _waitingEntries.length,
                                        onReorder: (oldIndex, newIndex) async {
                                          if (newIndex > oldIndex) newIndex -= 1;
                                          final reordered = List<Map<String, dynamic>>.from(_waitingEntries);
                                          final moved = reordered.removeAt(oldIndex);
                                          reordered.insert(newIndex, moved);
                                          await _reorderQueue(reordered);
                                        },
                                        itemBuilder: (context, index) {
                                          final entry = _waitingEntries[index];
                                          return _AdminQueueEntryCard(
                                            key: ValueKey(entry['id']),
                                            entry: entry,
                                            onViewDetails: () => _showQueueEntryDetails(entry),
                                            dragHandle: ReorderableDragStartListener(
                                              index: index,
                                              child: Container(
                                                padding: const EdgeInsets.all(10),
                                                decoration: BoxDecoration(
                                                  color: AppColors.surfaceLight,
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: const Icon(Icons.drag_indicator_rounded, color: AppColors.textHint),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                        if (_serviceType != 'queue') ...[
                          const SizedBox(height: 18),
                          _SectionCard(
                            title: 'Active Appointments',
                            subtitle: 'Pending and confirmed bookings are visible here for moderation and audit.',
                            child: _appointments.isEmpty
                                ? const Text('No active appointments.', style: TextStyle(color: AppColors.textHint))
                                : Column(
                                    children: _appointments.map((appointment) {
                                      final dateTime = _tryParseDateTime(appointment['date_time']);
                                      final finalPrice = _asDouble(appointment['final_price']);
                                      final originalPrice = _asDouble(appointment['original_price']);
                                      final discountAmount = _asDouble(appointment['discount_amount']);
                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 10),
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceLight,
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: AppColors.glassBorder, width: 0.5),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(appointment['customer_name']?.toString() ?? 'Customer', style: const TextStyle(fontWeight: FontWeight.w700)),
                                                      const SizedBox(height: 4),
                                                      Text(appointment['service_name']?.toString() ?? 'Service', style: const TextStyle(color: AppColors.textHint, fontSize: 12)),
                                                    ],
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.primary.withValues(alpha: 0.12),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Text(
                                                    (appointment['status']?.toString() ?? 'pending').toUpperCase(),
                                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 10),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: [
                                                if (dateTime != null)
                                                  _InfoChip(icon: Icons.event_rounded, label: _formatDateTime(dateTime), color: AppColors.warning),
                                                if (finalPrice > 0)
                                                  _InfoChip(icon: Icons.payments_outlined, label: '\$${finalPrice.toStringAsFixed(2)}', color: AppColors.secondary),
                                                if (originalPrice > 0 && discountAmount > 0)
                                                  _InfoChip(icon: Icons.sell_outlined, label: '-\$${discountAmount.toStringAsFixed(2)}', color: AppColors.success),
                                                if ((appointment['discount_code']?.toString() ?? '').isNotEmpty)
                                                  _InfoChip(icon: Icons.confirmation_number_outlined, label: appointment['discount_code'].toString(), color: AppColors.info),
                                              ],
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                          ),
                          const SizedBox(height: 18),
                          _SectionCard(
                            title: 'Time Slots',
                              subtitle: 'Create, edit, or remove appointment availability blocks.',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: OutlinedButton.icon(
                                      onPressed: () => _showSlotEditor(),
                                      icon: const Icon(Icons.add_rounded, size: 16),
                                      label: const Text('Add Slot'),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  if (_slots.isEmpty)
                                    const Text('No appointment slots configured.', style: TextStyle(color: AppColors.textHint))
                                  else
                                    Column(
                                      children: _slots.take(24).map((slot) {
                                        final start = _tryParseDateTime(slot['start_time']);
                                        final end = _tryParseDateTime(slot['end_time']);
                                        final isBooked = _asBool(slot['is_booked']);
                                        final timeLabel = start != null && end != null
                                            ? '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')} - ${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}'
                                            : '${slot['start_time'] ?? '--:--'} - ${slot['end_time'] ?? '--:--'}';
                                        final dateLabel = start != null ? _formatDateTime(start) : 'Unknown date';

                                        return Container(
                                          margin: const EdgeInsets.only(bottom: 10),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: AppColors.surfaceLight,
                                            borderRadius: BorderRadius.circular(14),
                                            border: Border.all(color: AppColors.glassBorder, width: 0.5),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(timeLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                                                    const SizedBox(height: 4),
                                                    Text(dateLabel, style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
                                                  ],
                                                ),
                                              ),
                                              if (isBooked)
                                                Container(
                                                  margin: const EdgeInsets.only(right: 8),
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.warning.withValues(alpha: 0.12),
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                  child: const Text('BOOKED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.warning)),
                                                ),
                                              IconButton(
                                                tooltip: 'Edit slot',
                                                onPressed: isBooked ? null : () => _showSlotEditor(slot: slot),
                                                icon: const Icon(Icons.edit_rounded),
                                              ),
                                              IconButton(
                                                tooltip: 'Delete slot',
                                                onPressed: isBooked ? null : () => _deleteSlot(slot),
                                                icon: const Icon(Icons.delete_outline_rounded),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                ],
                              ),
                          ),
                        ],
                      ],
                    ),
        );
      },
    );
  }

  void _showQueueEntryDetails(Map<String, dynamic> entry) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        final maxHeight = MediaQuery.of(context).size.height * 0.78;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(entry['customer_name']?.toString() ?? 'Customer', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        ),
                        IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _DetailRow(label: 'Queue position', value: _asInt(entry['position']).toString()),
                    _DetailRow(label: 'Purchased items', value: (entry['notes']?.toString() ?? '').isNotEmpty ? entry['notes'].toString() : 'Not specified'),
                    _DetailRow(label: 'Total paid', value: '\$${_asDouble(entry['total_price']).toStringAsFixed(2)}'),
                    _DetailRow(
                      label: 'Discount',
                      value: _asDouble(entry['discount_amount']) > 0 ? '-\$${_asDouble(entry['discount_amount']).toStringAsFixed(2)}' : 'No coupon applied',
                    ),
                    _DetailRow(
                      label: 'Coupon code',
                      value: (entry['discount_code']?.toString() ?? '').isNotEmpty ? entry['discount_code'].toString() : 'No coupon applied',
                    ),
                    _DetailRow(label: 'Estimated service time', value: _durationLabel(_asInt(entry['product_duration_minutes']))),
                    _DetailRow(
                      label: 'Joined at',
                      value: _tryParseDateTime(entry['joined_at']) != null ? _formatDateTime(_tryParseDateTime(entry['joined_at'])!) : '-',
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AdminQueueEntryCard extends StatelessWidget {
  final Map<String, dynamic> entry;
  final VoidCallback onViewDetails;
  final Widget? dragHandle;

  const _AdminQueueEntryCard({super.key, required this.entry, required this.onViewDetails, this.dragHandle});

  @override
  Widget build(BuildContext context) {
    final isServing = entry['status']?.toString() == 'serving';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isServing ? AppColors.secondary.withValues(alpha: 0.35) : AppColors.glassBorder,
          width: isServing ? 1.1 : 0.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: isServing ? AppColors.servingGradient : AppColors.primaryGradient,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: isServing
                ? const Icon(Icons.flash_on_rounded, color: Colors.white)
                : Text('${_asInt(entry['position'])}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(entry['customer_name']?.toString() ?? 'Customer', style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    if (_asBool(entry['is_vip']))
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: AppColors.vip.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                        child: const Text('VIP', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.vip)),
                      ),
                  ],
                ),
                if ((entry['notes']?.toString() ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(entry['notes'].toString(), style: const TextStyle(fontSize: 12, color: AppColors.textHint), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoChip(icon: Icons.payments_outlined, label: '\$${_asDouble(entry['total_price']).toStringAsFixed(2)}', color: AppColors.secondary),
                    if (_asDouble(entry['discount_amount']) > 0)
                      _InfoChip(icon: Icons.local_offer_outlined, label: '-\$${_asDouble(entry['discount_amount']).toStringAsFixed(2)}', color: AppColors.success),
                    if ((entry['discount_code']?.toString() ?? '').isNotEmpty)
                      _InfoChip(icon: Icons.confirmation_number_outlined, label: entry['discount_code'].toString(), color: AppColors.warning),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(onPressed: onViewDetails, icon: const Icon(Icons.info_outline_rounded, color: AppColors.primary)),
              ?dragHandle,
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SectionCard({required this.title, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.glassBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final CategoryTheme theme;

  const _CategoryChip({required this.label, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        gradient: theme.backgroundGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.primaryColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.category_rounded, size: 14, color: theme.primaryColor),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: theme.primaryColor)),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textHint, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

int _asInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

bool _asBool(dynamic value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final normalized = value?.toString().trim().toLowerCase();
  if (normalized == 'true' || normalized == '1') return true;
  if (normalized == 'false' || normalized == '0') return false;
  return fallback;
}

String _cleanError(Object error) {
  return error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
}

String _formatServiceType(String value) {
  switch (value) {
    case 'appointment':
      return 'Appointments';
    case 'both':
      return 'Queue + Appointments';
    default:
      return 'Queue';
  }
}

final List<String> _categoryValues = BusinessCategory.values.map((category) => category.name).toList();

String _formatCategoryLabel(String value) {
  if (value.isEmpty) return 'Other';
  final normalized = value.replaceAll('_', ' ');
  return normalized[0].toUpperCase() + normalized.substring(1);
}

CategoryTheme _categoryTheme(String value) {
  final category = switch (value) {
    'bakery' => BusinessCategory.bakery,
    'barber' => BusinessCategory.barber,
    'restaurant' => BusinessCategory.restaurant,
    'clinic' => BusinessCategory.clinic,
    'bank' => BusinessCategory.bank,
    'repair' => BusinessCategory.repair,
    'beauty' => BusinessCategory.beauty,
    'dentist' => BusinessCategory.dentist,
    'gym' => BusinessCategory.gym,
    'pharmacy' => BusinessCategory.pharmacy,
    'grocery' => BusinessCategory.grocery,
    'government' => BusinessCategory.government,
    'cafe' => BusinessCategory.cafe,
    'vet' => BusinessCategory.vet,
    _ => BusinessCategory.other,
  };
  return CategoryThemes.getTheme(category);
}

DateTime? _tryParseDateTime(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

String _formatDateTime(DateTime dateTime) {
  final day = dateTime.day.toString().padLeft(2, '0');
  final month = dateTime.month.toString().padLeft(2, '0');
  final year = dateTime.year.toString();
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '$day/$month/$year $hour:$minute';
}

String _durationLabel(int minutes) {
  if (minutes <= 0) return '-';
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final remainingMinutes = minutes % 60;
  return remainingMinutes == 0 ? '${hours}h' : '${hours}h ${remainingMinutes}m';
}