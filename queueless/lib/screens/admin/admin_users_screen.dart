import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../services/api_service.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  int _page = 1;
  int _total = 0;
  String _roleFilter = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load([int page = 1]) async {
    setState(() => _loading = true);
    try {
      final q = _searchController.text.trim();
      var url = '/admin/users?page=$page&limit=20';
      if (_roleFilter.isNotEmpty) url += '&role=$_roleFilter';
      if (q.isNotEmpty) url += '&search=$q';
      final result = await ApiService.get(url);
      if (mounted) {
        setState(() {
          _users = List<Map<String, dynamic>>.from(result['users'] ?? []);
          _total = (result['total'] as num?)?.toInt() ?? 0;
          _page = page;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _banUser(String userId) async {
    final reason = await _showInputDialog('Ban Reason', 'Why is this user being banned?');
    if (reason == null || reason.isEmpty) return;
    try {
      await ApiService.post('/admin/users/$userId/ban', {'reason': reason});
      _load(_page);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
      }
    }
  }

  Future<void> _unbanUser(String userId) async {
    try {
      await ApiService.post('/admin/users/$userId/unban', {});
      _load(_page);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
      }
    }
  }

  Future<void> _deleteUser(String userId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete User?'),
        content: const Text('This will permanently delete this user and all their data. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiService.delete('/admin/users/$userId');
      _load(_page);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
      }
    }
  }

  Future<String?> _showInputDialog(String title, String hint) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: TextField(controller: controller, decoration: InputDecoration(hintText: hint)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(c, controller.text), child: const Text('Submit')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search users...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onSubmitted: (_) => _load(),
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _roleFilter.isEmpty ? null : _roleFilter,
                hint: const Text('Role', style: TextStyle(fontSize: 12)),
                items: const [
                  DropdownMenuItem(value: '', child: Text('All')),
                  DropdownMenuItem(value: 'customer', child: Text('Customer')),
                  DropdownMenuItem(value: 'businessOwner', child: Text('Business')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                ],
                onChanged: (v) { _roleFilter = v ?? ''; _load(); },
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('Total: $_total users', style: const TextStyle(color: AppColors.textHint, fontSize: 12)),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () => _load(_page),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _users.length,
                    itemBuilder: (context, i) => _buildUserCard(_users[i]),
                  ),
                ),
        ),
        if ((_total / 20).ceil() > 1)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_page > 1)
                  IconButton(onPressed: () => _load(_page - 1), icon: const Icon(Icons.chevron_left)),
                Text('Page $_page of ${(_total / 20).ceil()}'),
                if (_page < (_total / 20).ceil())
                  IconButton(onPressed: () => _load(_page + 1), icon: const Icon(Icons.chevron_right)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final isBanned = user['is_banned'] == 1;
    final role = user['role']?.toString() ?? 'customer';
    final name = user['name']?.toString() ?? 'Unknown';
    final email = user['email']?.toString() ?? '';
    final id = user['id']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isBanned ? AppColors.error.withValues(alpha: 0.3) : AppColors.glassBorder,
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: isBanned ? AppColors.error.withValues(alpha: 0.1) : AppColors.primary.withValues(alpha: 0.1),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(color: isBanned ? AppColors.error : AppColors.primary, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _roleColor(role).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(role, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: _roleColor(role))),
                    ),
                    if (isBanned) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('BANNED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.error)),
                      ),
                    ],
                  ],
                ),
                Text(email, style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                if (isBanned && user['ban_reason'] != null)
                  Text('Reason: ${user['ban_reason']}', style: const TextStyle(fontSize: 10, color: AppColors.error)),
              ],
            ),
          ),
          PopupMenuButton<String>(
            itemBuilder: (_) => [
              if (!isBanned) const PopupMenuItem(value: 'ban', child: Text('Ban User')),
              if (isBanned) const PopupMenuItem(value: 'unban', child: Text('Unban User')),
              const PopupMenuItem(value: 'delete', child: Text('Delete User', style: TextStyle(color: AppColors.error))),
            ],
            onSelected: (action) {
              switch (action) {
                case 'ban': _banUser(id); break;
                case 'unban': _unbanUser(id); break;
                case 'delete': _deleteUser(id); break;
              }
            },
          ),
        ],
      ),
    );
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'admin': return AppColors.warning;
      case 'businessOwner': return AppColors.secondary;
      default: return AppColors.primary;
    }
  }
}
