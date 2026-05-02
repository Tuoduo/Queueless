import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../services/api_service.dart';
import '../../services/socket_service.dart';

class AdminTicketsScreen extends StatefulWidget {
  const AdminTicketsScreen({super.key});

  @override
  State<AdminTicketsScreen> createState() => _AdminTicketsScreenState();
}

class _AdminTicketsScreenState extends State<AdminTicketsScreen> with SingleTickerProviderStateMixin {
  final SocketService _socketService = SocketService();
  List<Map<String, dynamic>> _tickets = [];
  bool _loading = true;
  int _page = 1;
  int _total = 0;
  late final TabController _tabController;

  List<Map<String, dynamic>> get _activeTickets => _tickets.where((ticket) => ticket['status']?.toString() != 'closed').toList();
  List<Map<String, dynamic>> get _closedTickets => _tickets.where((ticket) => ticket['status']?.toString() == 'closed').toList();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _socketService.connect();
    _socketService.joinAdminPanel();
    _socketService.onTicketUpdate(_handleTicketUpdate);
    _load();
  }

  @override
  void dispose() {
    _socketService.offTicketUpdate(_handleTicketUpdate);
    _socketService.leaveAdminPanel();
    _tabController.dispose();
    super.dispose();
  }

  void _handleTicketUpdate(Map<String, dynamic> data) {
    if (!mounted) return;
    _load(_page, false);
  }

  Future<void> _load([int page = 1, bool showLoader = true]) async {
    if (showLoader) {
      setState(() => _loading = true);
    }

    try {
      final result = await ApiService.get('/admin/tickets?page=$page&limit=50');
      if (!mounted) return;
      setState(() {
        _tickets = List<Map<String, dynamic>>.from(result['tickets'] ?? []);
        _total = (result['total'] as num?)?.toInt() ?? 0;
        _page = page;
        _loading = false;
      });
    } catch (e) {
      if (mounted && showLoader) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openTicket(Map<String, dynamic> ticket) async {
    final ticketId = ticket['id']?.toString() ?? '';
    if (ticketId.isEmpty) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return _AdminTicketSheet(
          ticketId: ticketId,
          initialSubject: ticket['subject']?.toString() ?? 'Ticket',
          onTicketChanged: () => _load(_page, false),
        );
      },
    );

    if (mounted) {
      _load(_page, false);
    }
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'closed':
        color = AppColors.success;
        break;
      case 'in_progress':
        color = AppColors.primary;
        break;
      default:
        color = AppColors.warning;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  Widget _buildTicketList(List<Map<String, dynamic>> tickets, {required bool closedList}) {
    if (tickets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              closedList ? Icons.archive_outlined : Icons.support_agent_rounded,
              size: 40,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 12),
            Text(
              closedList ? 'No closed requests' : 'No open requests',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              closedList ? 'Closed tickets will accumulate here.' : 'Customer conversations that still need attention appear here.',
              style: const TextStyle(fontSize: 12, color: AppColors.textHint),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(_page),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        itemCount: tickets.length,
        itemBuilder: (context, index) {
          final ticket = tickets[index];
          final date = ticket['updated_at'] != null
              ? DateTime.tryParse(ticket['updated_at'].toString())
              : (ticket['created_at'] != null ? DateTime.tryParse(ticket['created_at'].toString()) : null);
          return GestureDetector(
            onTap: () => _openTicket(ticket),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: AppColors.cardGradient,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.glassBorder, width: 0.5),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ticket['subject']?.toString() ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${ticket['user_name'] ?? ''} • ${ticket['category'] ?? ''}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textHint),
                        ),
                        if (date != null)
                          Text(
                            DateFormat('dd MMM yyyy, HH:mm').format(date),
                            style: const TextStyle(fontSize: 10, color: AppColors.textHint),
                          ),
                      ],
                    ),
                  ),
                  _buildStatusChip(ticket['status']?.toString() ?? 'open'),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('$_total tickets', style: const TextStyle(color: AppColors.textHint)),
          ),
        ),
        Container(
          color: AppColors.background,
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textHint,
            indicatorColor: AppColors.primary,
            tabs: [
              Tab(text: 'Open (${_activeTickets.length})'),
              Tab(text: 'Closed (${_closedTickets.length})'),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTicketList(_activeTickets, closedList: false),
                    _buildTicketList(_closedTickets, closedList: true),
                  ],
                ),
        ),
      ],
    );
  }
}

class _AdminTicketSheet extends StatefulWidget {
  final String ticketId;
  final String initialSubject;
  final VoidCallback onTicketChanged;

  const _AdminTicketSheet({
    required this.ticketId,
    required this.initialSubject,
    required this.onTicketChanged,
  });

  @override
  State<_AdminTicketSheet> createState() => _AdminTicketSheetState();
}

class _AdminTicketSheetState extends State<_AdminTicketSheet> {
  final SocketService _socketService = SocketService();
  final TextEditingController _replyController = TextEditingController();
  Map<String, dynamic>? _ticket;
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;

  String get _status => _ticket?['status']?.toString() ?? 'open';
  bool get _isClosed => _status == 'closed';

  @override
  void initState() {
    super.initState();
    _socketService.connect();
    _socketService.onTicketUpdate(_handleTicketUpdate);
    _load();
  }

  @override
  void dispose() {
    _socketService.offTicketUpdate(_handleTicketUpdate);
    _replyController.dispose();
    super.dispose();
  }

  void _handleTicketUpdate(Map<String, dynamic> data) {
    if (data['ticketId']?.toString() != widget.ticketId || !mounted) return;
    _load(showLoader: false);
    widget.onTicketChanged();
  }

  Future<void> _load({bool showLoader = true}) async {
    if (showLoader) {
      setState(() => _loading = true);
    }

    try {
      final result = await ApiService.get('/admin/tickets/${widget.ticketId}/messages');
      if (!mounted) return;
      setState(() {
        _ticket = Map<String, dynamic>.from(result['ticket'] ?? const {});
        _messages = List<Map<String, dynamic>>.from(result['messages'] ?? []);
        _loading = false;
      });
    } catch (e) {
      if (mounted && showLoader) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _sendReply() async {
    if (_replyController.text.trim().isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      await ApiService.post('/admin/tickets/${widget.ticketId}/reply', {
        'message': _replyController.text.trim(),
      });
      _replyController.clear();
      await _load(showLoader: false);
      widget.onTicketChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _updateStatus(String status) async {
    try {
      await ApiService.put('/admin/tickets/${widget.ticketId}/status', {'status': status});
      await _load(showLoader: false);
      widget.onTicketChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Widget _buildStatusChip() {
    Color color;
    switch (_status) {
      case 'closed':
        color = AppColors.success;
        break;
      case 'in_progress':
        color = AppColors.primary;
        break;
      default:
        color = AppColors.warning;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _status.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _ticket?['subject']?.toString() ?? widget.initialSubject,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ),
                  _buildStatusChip(),
                ],
              ),
              Text(
                'By: ${_ticket?['user_name'] ?? ''} • ${_ticket?['category'] ?? ''}',
                style: const TextStyle(fontSize: 11, color: AppColors.textHint),
              ),
              if (_isClosed) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.success.withValues(alpha: 0.18)),
                  ),
                  child: const Text(
                    'This ticket is closed. Your next reply will move it back to the open list.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
              ],
              const Divider(height: 24),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final isAdmin = message['sender_role']?.toString() == 'admin';
                          final date = message['created_at'] != null
                              ? DateTime.tryParse(message['created_at'].toString())
                              : null;
                          return Align(
                            alignment: isAdmin ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                              decoration: BoxDecoration(
                                color: isAdmin
                                    ? AppColors.primary.withValues(alpha: 0.12)
                                    : AppColors.surfaceLight,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(message['message']?.toString() ?? '', style: const TextStyle(fontSize: 13)),
                                  if (date != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        DateFormat('dd MMM, HH:mm').format(date),
                                        style: const TextStyle(fontSize: 9, color: AppColors.textHint),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _replyController,
                      enabled: !_sending,
                      decoration: InputDecoration(
                        hintText: _isClosed ? 'Reply to reopen this ticket...' : 'Reply as admin...',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      maxLines: 2,
                      minLines: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _sending ? null : _sendReply,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded, color: AppColors.primary),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (_status != 'closed')
                    TextButton.icon(
                      onPressed: () => _updateStatus('closed'),
                      icon: const Icon(Icons.check_circle_outline, size: 16, color: AppColors.success),
                      label: const Text('Close', style: TextStyle(color: AppColors.success)),
                    ),
                  if (_status == 'open')
                    TextButton.icon(
                      onPressed: () => _updateStatus('in_progress'),
                      icon: const Icon(Icons.play_arrow_rounded, size: 16, color: AppColors.primary),
                      label: const Text('In Progress', style: TextStyle(color: AppColors.primary)),
                    ),
                  if (_status == 'closed')
                    TextButton.icon(
                      onPressed: () => _updateStatus('open'),
                      icon: const Icon(Icons.refresh_rounded, size: 16, color: AppColors.warning),
                      label: const Text('Reopen', style: TextStyle(color: AppColors.warning)),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}