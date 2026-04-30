import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/socket_service.dart';

const List<Map<String, String>> _ticketCategoryOptions = [
  {'value': 'bug', 'label': 'Bug Report'},
  {'value': 'complaint', 'label': 'Complaint'},
  {'value': 'suggestion', 'label': 'Suggestion'},
  {'value': 'account', 'label': 'Account Issue'},
  {'value': 'other', 'label': 'Other'},
];

String _formatTicketCategoryLabel(String value) {
  switch (value) {
    case 'bug':
      return 'Bug Report';
    case 'complaint':
      return 'Complaint';
    case 'suggestion':
      return 'Suggestion';
    case 'account':
      return 'Account Issue';
    default:
      return 'Other';
  }
}

class TicketListScreen extends StatefulWidget {
  const TicketListScreen({super.key});

  @override
  State<TicketListScreen> createState() => _TicketListScreenState();
}

class _TicketListScreenState extends State<TicketListScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _tickets = [];
  bool _loading = true;
  final SocketService _socketService = SocketService();
  late final TabController _tabController;

  List<Map<String, dynamic>> get _activeTickets => _tickets.where((ticket) => ticket['status']?.toString() != 'closed').toList();
  List<Map<String, dynamic>> get _closedTickets => _tickets.where((ticket) => ticket['status']?.toString() == 'closed').toList();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _socketService.connect();
    final userId = context.read<AuthProvider>().currentUser?.id ?? '';
    if (userId.isNotEmpty) {
      _socketService.joinUser(userId);
    }
    _socketService.onTicketUpdate(_handleTicketUpdate);
    _load();
  }

  @override
  void dispose() {
    _socketService.offTicketUpdate(_handleTicketUpdate);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTicketUpdate(Map<String, dynamic> data) {
    if (!mounted) return;
    _load(showLoader: false);
  }

  Future<void> _load({bool showLoader = true}) async {
    if (showLoader) {
      setState(() => _loading = true);
    }
    try {
      final result = await ApiService.get('/tickets/mine');
      final rawTickets = result is List ? result : (result['tickets'] ?? const []);
      if (mounted) {
        setState(() {
          _tickets = List<Map<String, dynamic>>.from(rawTickets);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted && showLoader) setState(() => _loading = false);
    }
  }

  void _openDetail(Map<String, dynamic> ticket) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _TicketDetailScreen(ticketId: ticket['id']?.toString() ?? '', subject: ticket['subject']?.toString() ?? '')),
    ).then((_) => _load());
  }

  void _createTicket() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const _CreateTicketScreen()),
    );
    if (result == true) _load();
  }

  Widget _buildTicketList(List<Map<String, dynamic>> tickets, {required bool closedList}) {
    if (tickets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              closedList ? Icons.archive_outlined : Icons.support_agent_rounded,
              size: 48,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 12),
            Text(
              closedList ? 'No closed tickets' : 'No active tickets',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              closedList ? 'Tickets you close will appear here.' : 'Create a new ticket when you need help.',
              style: const TextStyle(color: AppColors.textHint),
            ),
            if (!closedList) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _createTicket,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Create Ticket'),
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: tickets.length,
        itemBuilder: (context, i) {
          final t = tickets[i];
          final status = t['status']?.toString() ?? 'open';
          final date = t['updated_at'] != null
              ? DateTime.tryParse(t['updated_at'].toString())
              : (t['created_at'] != null ? DateTime.tryParse(t['created_at'].toString()) : null);
          Color statusColor;
          switch (status) {
            case 'closed': statusColor = AppColors.success; break;
            case 'in_progress': statusColor = AppColors.primary; break;
            default: statusColor = AppColors.warning;
          }
          return GestureDetector(
            onTap: () => _openDetail(t),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
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
                        Text(t['subject']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(
                          _formatTicketCategoryLabel(t['category']?.toString() ?? 'other'),
                          style: const TextStyle(fontSize: 11, color: AppColors.textHint),
                        ),
                        if (date != null)
                          Text(DateFormat('dd MMM yyyy, HH:mm').format(date), style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status.replaceAll('_', ' ').toUpperCase(),
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor),
                    ),
                  ),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Support Tickets'),
        actions: [
          IconButton(onPressed: _createTicket, icon: const Icon(Icons.add_rounded)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  color: AppColors.background,
                  child: TabBar(
                    controller: _tabController,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: AppColors.textHint,
                    indicatorColor: AppColors.primary,
                    tabs: [
                      Tab(text: 'Active (${_activeTickets.length})'),
                      Tab(text: 'Closed (${_closedTickets.length})'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTicketList(_activeTickets, closedList: false),
                      _buildTicketList(_closedTickets, closedList: true),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

// ─── Ticket Detail ──────────────────────────
class _TicketDetailScreen extends StatefulWidget {
  final String ticketId;
  final String subject;
  const _TicketDetailScreen({required this.ticketId, required this.subject});

  @override
  State<_TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<_TicketDetailScreen> {
  List<Map<String, dynamic>> _messages = [];
  Map<String, dynamic>? _ticket;
  bool _loading = true;
  bool _sending = false;
  final _msgCtrl = TextEditingController();
  final SocketService _socketService = SocketService();

  bool get _isClosed => _ticket?['status']?.toString() == 'closed';

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
    _msgCtrl.dispose();
    super.dispose();
  }

  void _handleTicketUpdate(Map<String, dynamic> data) {
    if (data['ticketId']?.toString() != widget.ticketId || !mounted) return;
    _load(showLoader: false);
  }

  Future<void> _load({bool showLoader = true}) async {
    if (showLoader) {
      setState(() => _loading = true);
    }
    try {
      final result = await ApiService.get('/tickets/${widget.ticketId}');
      if (mounted) {
        setState(() {
          _ticket = Map<String, dynamic>.from(result['ticket'] ?? const {});
          _messages = List<Map<String, dynamic>>.from(result['messages'] ?? []);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted && showLoader) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    if (_msgCtrl.text.trim().isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ApiService.post('/tickets/${widget.ticketId}/message', {
        'message': _msgCtrl.text.trim(),
      });
      _msgCtrl.clear();
      await _load(showLoader: false);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Widget _buildStatusChip() {
    final status = _ticket?['status']?.toString() ?? 'open';
    Color statusColor;
    switch (status) {
      case 'closed':
        statusColor = AppColors.success;
        break;
      case 'in_progress':
        statusColor = AppColors.primary;
        break;
      default:
        statusColor = AppColors.warning;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.subject, style: const TextStyle(fontSize: 16)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(child: _buildStatusChip()),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isClosed)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: AppColors.success.withValues(alpha: 0.12),
              child: const Row(
                children: [
                  Icon(Icons.refresh_rounded, size: 18, color: AppColors.success),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This ticket is closed. Sending a new message will reopen it automatically.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, i) {
                      final msg = _messages[i];
                      final isAdmin = msg['sender_role']?.toString() == 'admin' || msg['is_admin'] == 1 || msg['is_admin'] == true;
                      final date = msg['created_at'] != null ? DateTime.tryParse(msg['created_at'].toString()) : null;
                      return Align(
                        alignment: isAdmin ? Alignment.centerLeft : Alignment.centerRight,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                          decoration: BoxDecoration(
                            color: isAdmin ? AppColors.surfaceLight : AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (isAdmin)
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 4),
                                  child: Text('Admin', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary)),
                                ),
                              Text(msg['message']?.toString() ?? '', style: const TextStyle(fontSize: 13)),
                              if (date != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(DateFormat('dd MMM, HH:mm').format(date), style: const TextStyle(fontSize: 9, color: AppColors.textHint)),
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
              left: 16, right: 8, top: 8,
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
                    controller: _msgCtrl,
                    enabled: !_sending,
                    decoration: InputDecoration(
                      hintText: _isClosed ? 'Send a message to reopen this ticket...' : 'Type a message...',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    maxLines: 3,
                    minLines: 1,
                  ),
                ),
                IconButton(
                  onPressed: _sending ? null : _send,
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
          ),
        ],
      ),
    );
  }
}

// ─── Create Ticket ──────────────────────────
class _CreateTicketScreen extends StatefulWidget {
  const _CreateTicketScreen();

  @override
  State<_CreateTicketScreen> createState() => _CreateTicketScreenState();
}

class _CreateTicketScreenState extends State<_CreateTicketScreen> {
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  String _category = _ticketCategoryOptions.first['value']!;
  bool _submitting = false;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_subjectCtrl.text.trim().isEmpty || _messageCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await ApiService.post('/tickets', {
        'subject': _subjectCtrl.text.trim(),
        'category': _category,
        'message': _messageCtrl.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Ticket')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Subject', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _subjectCtrl,
              decoration: InputDecoration(
                hintText: 'Brief description of the issue',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Category', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _ticketCategoryOptions.map((option) {
                final value = option['value']!;
                final label = option['label']!;
                final isSelected = value == _category;
                return GestureDetector(
                  onTap: () => setState(() => _category = value),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isSelected ? AppColors.primary : AppColors.glassBorder),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                        color: isSelected ? AppColors.primary : AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Text('Message', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _messageCtrl,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Describe your issue in detail...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                child: _submitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Submit Ticket'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
