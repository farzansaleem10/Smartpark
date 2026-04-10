import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/booking.dart';
import '../../services/api_service.dart';

class QRCodeScreen extends StatelessWidget {
  final Booking booking;

  const QRCodeScreen({
    super.key,
    required this.booking,
  });

  String? _getQrImageUrl() {
    final qr = booking.qrCode;
    if (qr == null || qr.trim().isEmpty) return null;

    final trimmed = qr.trim();

    // Data URI can be rendered directly by Image.network.
    if (trimmed.startsWith('data:')) return trimmed;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }

    final cleanBase = ApiService.baseUrl
        .replaceAll('/api', '')
        .replaceAll(RegExp(r'/$'), '');
    final cleanPath = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    return '$cleanBase$cleanPath';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Code'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Builder(
                      builder: (context) {
                        final qrImageUrl = _getQrImageUrl();

                        if (qrImageUrl == null) {
                          return QrImageView(
                            data: booking.id,
                            version: QrVersions.auto,
                            size: 250,
                            backgroundColor: Colors.white,
                          );
                        }

                        return Image.network(
                          qrImageUrl,
                          width: 250,
                          height: 250,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const SizedBox(
                              width: 250,
                              height: 250,
                              child: Center(child: CircularProgressIndicator()),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            // If network image fails on mobile (URL/network issue), show generated QR.
                            return QrImageView(
                              data: booking.id,
                              version: QrVersions.auto,
                              size: 250,
                              backgroundColor: Colors.white,
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Booking ID: ${booking.id.substring(0, 8)}...',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (booking.parking != null)
                      Text(
                        booking.parking!.name,
                        style: TextStyle(color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                    const SizedBox(height: 8),
                    Text(
                      'Slot: ${booking.slotNumber}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Show this QR code at the parking location for check-in',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.done),
              label: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}
