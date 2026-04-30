import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../services/api_service.dart';
import '../../services/socket_service.dart';
import '../shared/live_business_chat_screen.dart';

class BusinessChatInboxScreen extends StatefulWidget {
  final String businessId;
  final String businessName;

  const BusinessChatInboxScreen({
    super.key,
    required this.businessId,
    required this.businessName,
  });

  @override
  State<BusinessChatInboxScreen> createState() => _BusinessChatInboxScreenState();
}

class _BusinessChatInboxScreenState extends State<BusinessChatInboxScreen> {
  final SocketService _socketService = SocketService();
  List<Map<String, dynamic>> _conversations = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _socketService.connect();
    _socketService.joinBusiness(widget.businessId);
    _socketService.onChatUpdate(_handleChatUpdate);
    _load();
  }

  @override
  void dispose() {
    _socketService.offChatUpdate(_handleChatUpdate);
    _socketService.leaveBusiness(widget.businessId);
    super.dispose();
  }

  String _cleanError(Object error) {
    return error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
  }

  void _handleChatUpdate(Map<String, dynamic> data) {
    if (data['businessId']?.toString() != widget.businessId || !mounted) return;
    _load(showLoader: false);
  }

  Future<void> _load({bool showLoader = true}) async {
    if (showLoader) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final result = await ApiService.get('/chats/businesses/${widget.businessId}/conversations');
      if (!mounted) return;
      setState(() {
        _conversations = List<Map<String, dynamic>>.from(result['conversations'] ?? const []);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _cleanError(e);
      });
    }
  }

  Future<void> _openConversation(Map<String, dynamic> conversation) async {
    final conversationId = conversation['id']?.toString() ?? '';
    final customerName = conversation['customer_name']?.toString() ?? 'Customer';
    if (conversationId.isEmpty) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LiveBusinessChatScreen(
          conversationId: conversationId,
          title: customerName,
          subtitle: widget.businessName,
        ),
      ),
    );

    if (mounted) {
      _load(showLoader: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Customer Chats', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            Text(widget.businessName, style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 38, color: AppColors.error),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textHint)),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _conversations.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.mark_chat_read_outlined, size: 42, color: AppColors.textHint),
                            SizedBox(height: 12),
                            Text('No customer conversations yet', style: TextStyle(fontWeight: FontWeight.w700)),
                            SizedBox(height: 6),
                            Text(
                              'When a customer starts chatting from the business page, the conversation will appear here live.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: AppColors.textHint),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _conversations.length,
                        itemBuilder: (context, index) {
                          final conversation = _conversations[index];
                          final customerName = conversation['customer_name']?.toString() ?? 'Customer';
                          final isBanned = conversation['is_banned'] == true || conversation['is_banned'] == 1;
                          final preview = conversation['last_message']?.toString().trim().isNotEmpty == true
                              ? conversation['last_message'].toString()
                              : 'Conversation started';
                          final createdAt = conversation['last_message_created_at'] != null
                              ? DateTime.tryParse(conversation['last_message_created_at'].toString())
                              : null;

                          return GestureDetector(
                            onTap: () => _openConversation(conversation),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                gradient: AppColors.cardGradient,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.glassBorder, width: 0.5),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundColor: AppColors.primary.withValues(alpha: 0.14),
                                    child: Text(
                                      customerName.isNotEmpty ? customerName[0].toUpperCase() : '?',
                                      style: const TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(customerName, style: const TextStyle(fontWeight: FontWeight.w700)),
                                            ),
                                            if (isBanned)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: AppColors.error.withValues(alpha: 0.14),
                                                  borderRadius: BorderRadius.circular(999),
                                                ),
                                                child: const Text(
                                                  'Blocked',
                                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.error),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          isBanned ? (conversation['ban_reason']?.toString().trim().isNotEmpty == true ? conversation['ban_reason'].toString() : 'Customer cannot message this business right now.') : preview,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 12, color: AppColors.textHint),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      if (createdAt != null)
                                        Text(
                                          DateFormat('HH:mm').format(createdAt),
                                          style: const TextStyle(fontSize: 11, color: AppColors.textHint),
                                        ),
                                      const SizedBox(height: 10),
                                      const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}