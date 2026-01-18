import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/booking.dart';
import 'qr_code_screen.dart';

class BookingConfirmationScreen extends StatefulWidget {
  final String bookingId;

  const BookingConfirmationScreen({
    super.key,
    required this.bookingId,
  });

  @override
  State<BookingConfirmationScreen> createState() =>
      _BookingConfirmationScreenState();
}

class _BookingConfirmationScreenState
    extends State<BookingConfirmationScreen> {
  Booking? _booking;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBooking();
  }

  Future<void> _loadBooking() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await ApiService.getBooking(widget.bookingId);

      if (response['success'] && response['data']?['booking'] != null) {
        setState(() {
          _booking = Booking.fromJson(response['data']['booking']);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = response['message'] ?? 'Failed to load booking';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking Confirmed'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : _booking == null
                  ? const Center(child: Text('Booking not found'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Card(
                            color: Colors.green[50],
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    size: 64,
                                    color: Colors.green,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Booking Confirmed!',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Booking Details',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildDetailRow(
                                    'Parking',
                                    _booking!.parking?.name ?? 'N/A',
                                  ),
                                  _buildDetailRow(
                                    'Slot Number',
                                    _booking!.slotNumber.toString(),
                                  ),
                                  _buildDetailRow(
                                    'Start Time',
                                    _formatDateTime(_booking!.startTime),
                                  ),
                                  _buildDetailRow(
                                    'End Time',
                                    _formatDateTime(_booking!.endTime),
                                  ),
                                  _buildDetailRow(
                                    'Duration',
                                    '${_booking!.duration.toStringAsFixed(1)} hours',
                                  ),
                                  _buildDetailRow(
                                    'Total Price',
                                    '₹${_booking!.totalPrice.toStringAsFixed(2)}',
                                  ),
                                  _buildDetailRow(
                                    'Payment Method',
                                    _booking!.paymentMethod.toUpperCase(),
                                  ),
                                  _buildDetailRow(
                                    'Status',
                                    _booking!.status.toUpperCase(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          if (_booking!.qrCode != null)
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => QRCodeScreen(
                                      booking: _booking!,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.qr_code),
                              label: const Text('View QR Code'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          const SizedBox(height: 16),
                          OutlinedButton(
                            onPressed: () {
                              Navigator.of(context).popUntil((route) => route.isFirst);
                            },
                            child: const Text('Back to Home'),
                          ),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
