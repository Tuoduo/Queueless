import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/business_provider.dart';
import '../../../models/business_model.dart';
import '../../../services/api_service.dart';

class QrCodeScreen extends StatelessWidget {
  const QrCodeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final bprov = Provider.of<BusinessProvider>(context, listen: false);
    final business = bprov.getBusinessByOwnerId(auth.currentUser?.id ?? '');

    if (business == null) {
      return const Center(child: Text('No business found'));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('QR Codes', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: FutureBuilder<String>(
        future: ApiService.resolveGuestBaseUrl(),
        builder: (context, snapshot) {
          final baseUrl = (snapshot.data ?? ApiService.configuredGuestBaseUrl).replaceFirst(RegExp(r'/$'), '');
          final serviceType = business.serviceType;
          final entries = <_QrEntry>[];

          if (serviceType == ServiceType.queue || serviceType == ServiceType.both) {
            entries.add(_QrEntry(
              url: '$baseUrl/q/${business.id}',
              label: 'Join Queue',
              sublabel: 'Browse menu  →  enter name  →  get queue number',
              icon: Icons.queue_rounded,
              color: AppColors.primary,
            ));
          }
          if (serviceType == ServiceType.appointment || serviceType == ServiceType.both) {
            entries.add(_QrEntry(
              url: '$baseUrl/a/${business.id}',
              label: 'Book Appointment',
              sublabel: 'Pick a service  →  choose time  →  enter name  →  confirm',
              icon: Icons.calendar_month_rounded,
              color: AppColors.secondary,
            ));
          }

          final isLocalOnlyUrl = baseUrl.contains('localhost') || baseUrl.contains('127.0.0.1') || baseUrl.contains('10.0.2.2');

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 20),
                    child: LinearProgressIndicator(minHeight: 3),
                  ),
                if (isLocalOnlyUrl)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.wifi_tethering_rounded, color: AppColors.warning, size: 18),
                            SizedBox(width: 8),
                            Text('QR link is local-only', style: TextStyle(fontWeight: FontWeight.w700)),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          'If customers scan this from another phone, set PUBLIC_BASE_URL to your reachable server URL or run the backend on a LAN/public address.',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                for (final e in entries) ...[
                  _QrCard(entry: e, businessName: business.name, address: business.address),
                  const SizedBox(height: 20),
                ],
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 18),
                          SizedBox(width: 8),
                          Text('How does it work?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _step('1', 'Print the QR code and display it at your entrance'),
                      _step('2', 'Customers scan it with any phone camera'),
                      _step('3', 'They join the queue or book — no app needed'),
                      _step('4', 'You see everything live on your dashboard'),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _step(String num, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22, height: 22,
            decoration: const BoxDecoration(gradient: AppColors.primaryGradient, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(num, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(color: AppColors.textHint, fontSize: 13))),
        ],
      ),
    );
  }
}

class _QrEntry {
  final String url;
  final String label;
  final String sublabel;
  final IconData icon;
  final Color color;
  const _QrEntry({required this.url, required this.label, required this.sublabel, required this.icon, required this.color});
}

class _QrCard extends StatelessWidget {
  final _QrEntry entry;
  final String businessName;
  final String? address;
  const _QrCard({required this.entry, required this.businessName, this.address});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.glassBorder, width: 0.5),
        boxShadow: [BoxShadow(color: entry.color.withValues(alpha: 0.12), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          // Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [entry.color, entry.color.withValues(alpha: 0.7)]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(entry.icon, color: Colors.white, size: 14),
                const SizedBox(width: 6),
                Text(entry.label.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          // QR Code
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 12)],
            ),
            padding: const EdgeInsets.all(12),
            child: QrImageView(
              data: entry.url,
              version: QrVersions.auto,
              size: 200,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF1A1A2E)),
              dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF1A1A2E)),
            ),
          ),
          const SizedBox(height: 16),
          Text(businessName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          if (address != null && address!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(address!, style: const TextStyle(color: AppColors.textHint, fontSize: 12), textAlign: TextAlign.center),
            ),
          const SizedBox(height: 6),
          Text(entry.sublabel, style: TextStyle(color: entry.color.withValues(alpha: 0.7), fontSize: 12), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          // Copy URL
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: entry.url));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${entry.label} link copied to clipboard')),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: entry.color.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Icon(Icons.link_rounded, color: entry.color, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(entry.url, style: const TextStyle(color: AppColors.textHint, fontSize: 11), overflow: TextOverflow.ellipsis),
                  ),
                  Icon(Icons.copy_rounded, color: entry.color, size: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
