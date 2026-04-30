import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../services/api_service.dart';
import '../../services/socket_service.dart';

class LiveBusinessChatScreen extends StatefulWidget {
  final String title;
  final String? subtitle;
  final String? businessId;
  final String? conversationId;

  const LiveBusinessChatScreen({
    super.key,
    required this.title,
    this.subtitle,
    this.businessId,
    this.conversationId,
  });

  @override
  State<LiveBusinessChatScreen> createState() => _LiveBusinessChatScreenState();
}

class _LiveBusinessChatScreenState extends State<LiveBusinessChatScreen> {
  final SocketService _socketService = SocketService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String? _conversationId;
  Map<String, dynamic>? _conversation;
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;

  bool get _canLoadFromBusiness => widget.businessId != null && widget.businessId!.isNotEmpty;
  bool get _hasConversation => _conversationId != null && _conversationId!.isNotEmpty;
  bool get _isBanned => _conversation?['is_banned'] == true || _conversation?['is_banned'] == 1;
  String? get _banReason {
    final value = _conversation?['ban_reason']?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }

  @override
  void initState() {
    super.initState();
    _conversationId = widget.conversationId;
    _socketService.connect();
    if (_hasConversation) {
      _socketService.joinChat(_conversationId!);
      context.read<NotificationProvider>().setActiveConversation(_conversationId);
    }
    _socketService.onChatUpdate(_handleChatUpdate);
    _load();
  }

  @override
  void dispose() {
    if (_hasConversation) {
      _socketService.leaveChat(_conversationId!);
    }
    context.read<NotificationProvider>().setActiveConversation(null);
    _socketService.offChatUpdate(_handleChatUpdate);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _cleanError(Object error) {
    return error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
  }

  void _handleChatUpdate(Map<String, dynamic> data) {
    final eventConversationId = data['conversationId']?.toString() ?? '';
    final eventBusinessId = data['businessId']?.toString() ?? '';

    final matchesConversation = _hasConversation && eventConversationId == _conversationId;
    final matchesBusiness = _canLoadFromBusiness && eventBusinessId == widget.businessId;

    if (!matchesConversation && !matchesBusiness) return;
    if (!mounted) return;

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
      final endpoint = _hasConversation
          ? '/chats/conversations/$_conversationId'
          : '/chats/businesses/${widget.businessId}';
      final result = await ApiService.get(endpoint);
      if (!mounted) return;
      final conversation = Map<String, dynamic>.from(result['conversation'] ?? const {});
      final nextConversationId = conversation['id']?.toString() ?? _conversationId ?? '';
      final notificationProvider = context.read<NotificationProvider>();

      if (nextConversationId.isNotEmpty && nextConversationId != _conversationId) {
        if (_hasConversation) {
          _socketService.leaveChat(_conversationId!);
        }
        _conversationId = nextConversationId;
        _socketService.joinChat(nextConversationId);
        notificationProvider.setActiveConversation(nextConversationId);
      }

      setState(() {
        _conversation = conversation;
        _messages = List<Map<String, dynamic>>.from(result['messages'] ?? const []);
        _loading = false;
      });
      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _cleanError(error);
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending || _isBanned) return;

    if (!_hasConversation) {
      await _load(showLoader: false);
    }

    if (!_hasConversation || _isBanned) return;

    setState(() => _sending = true);
    try {
      await ApiService.post('/chats/conversations/$_conversationId/messages', {
        'message': text,
      });
      _messageController.clear();
      await _load(showLoader: false);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_cleanError(error)), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _setBan(bool shouldBan) async {
    if (!_hasConversation) return;

    String? reason;
    if (shouldBan) {
      final reasonController = TextEditingController(text: _banReason ?? '');
      reason = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Text('Block Customer'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Blocked customers can no longer send messages to this business.',
                style: TextStyle(fontSize: 12, color: AppColors.textHint),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Reason (optional)',
                  hintText: 'Spam, abuse, repeated harassment...',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(reasonController.text.trim()),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
              child: const Text('Block'),
            ),
          ],
        ),
      );
      if (reason == null) return;
    }

    try {
      if (shouldBan) {
        await ApiService.post('/chats/conversations/$_conversationId/ban', {'reason': reason ?? ''});
      } else {
        await ApiService.delete('/chats/conversations/$_conversationId/ban');
      }
      await _load(showLoader: false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(shouldBan ? 'Customer blocked from this chat' : 'Customer chat access restored')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_cleanError(error)), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Widget _buildBanner() {
    if (!_isBanned) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0x2218FFFF), Color(0x117B6FFF)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          border: Border(bottom: BorderSide(color: AppColors.glassBorder, width: 0.5)),
        ),
        child: const Row(
          children: [
            Icon(Icons.bolt_rounded, size: 16, color: AppColors.secondary),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Live chat is active. New messages appear here instantly.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.12),
        border: Border(bottom: BorderSide(color: AppColors.error.withValues(alpha: 0.3))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.block_rounded, size: 16, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('This conversation is blocked.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.error)),
                if (_banReason != null) ...[
                  const SizedBox(height: 4),
                  Text(_banReason!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final currentRole = auth.isBusinessOwner ? 'businessOwner' : 'customer';

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            if ((widget.subtitle ?? '').isNotEmpty)
              Text(widget.subtitle!, style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
          ],
        ),
        actions: auth.isBusinessOwner && _hasConversation
            ? [
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'ban') {
                      _setBan(true);
                    } else if (value == 'unban') {
                      _setBan(false);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem<String>(
                      value: _isBanned ? 'unban' : 'ban',
                      child: Row(
                        children: [
                          Icon(_isBanned ? Icons.lock_open_rounded : Icons.block_rounded, size: 18, color: _isBanned ? AppColors.success : AppColors.error),
                          const SizedBox(width: 10),
                          Text(_isBanned ? 'Restore chat access' : 'Block customer'),
                        ],
                      ),
                    ),
                  ],
                ),
              ]
            : null,
      ),
      body: Column(
        children: [
          _buildBanner(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.chat_bubble_outline_rounded, size: 38, color: AppColors.textHint),
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
                    : _messages.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _isBanned ? Icons.block_rounded : Icons.mark_chat_unread_outlined,
                                    size: 42,
                                    color: _isBanned ? AppColors.error : AppColors.textHint,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _isBanned ? 'This conversation is blocked' : 'Start the conversation',
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _isBanned
                                        ? 'No new messages can be sent until the business owner restores access.'
                                        : 'Ask a question, request details, or coordinate before you visit.',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 12, color: AppColors.textHint),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final message = _messages[index];
                              final senderRole = message['sender_role']?.toString() ?? '';
                              final isMine = senderRole == currentRole;
                              final sentAt = message['created_at'] != null
                                  ? DateTime.tryParse(message['created_at'].toString())
                                  : null;
                              return Align(
                                alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(12),
                                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                                  decoration: BoxDecoration(
                                    gradient: isMine ? AppColors.primaryGradient : null,
                                    color: isMine ? null : AppColors.surfaceLight,
                                    borderRadius: BorderRadius.circular(16),
                                    border: isMine ? null : Border.all(color: AppColors.glassBorder, width: 0.5),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (!isMine)
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 4),
                                          child: Text(
                                            message['sender_name']?.toString() ?? 'Store',
                                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.secondary),
                                          ),
                                        ),
                                      Text(
                                        message['message']?.toString() ?? '',
                                        style: TextStyle(fontSize: 13, color: isMine ? Colors.white : AppColors.textPrimary, height: 1.35),
                                      ),
                                      if (sentAt != null)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 6),
                                          child: Text(
                                            DateFormat('dd MMM, HH:mm').format(sentAt),
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: isMine ? Colors.white.withValues(alpha: 0.8) : AppColors.textHint,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 8,
              top: 8,
              bottom: MediaQuery.of(context).viewInsets.bottom + 8,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.divider.withValues(alpha: 0.5))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    enabled: !_sending && !_isBanned,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: _isBanned ? 'Messaging is disabled for this conversation' : 'Type a message...',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    minLines: 1,
                    maxLines: 4,
                  ),
                ),
                IconButton(
                  onPressed: _sending || _isBanned ? null : _send,
                  icon: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.send_rounded, color: _isBanned ? AppColors.textHint : AppColors.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}