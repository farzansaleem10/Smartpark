import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../models/booking.dart';
import 'qr_code_screen.dart';

class BookingHistoryScreen extends StatefulWidget {
  const BookingHistoryScreen({super.key});

  @override
  State<BookingHistoryScreen> createState() => _BookingHistoryScreenState();
}

class _BookingHistoryScreenState extends State<BookingHistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Booking> _bookings = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadBookings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBookings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await ApiService.getBookings();

      if (response['success'] && response['data']?['bookings'] != null) {
        setState(() {
          _bookings = (response['data']['bookings'] as List)
              .map((b) => Booking.fromJson(b))
              .toList();
          // Sort bookings: Newest first
          _bookings.sort((a, b) => b.startTime.compareTo(a.startTime));
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = response['message'] ?? 'Failed to load bookings';
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed': return Colors.blue;
      case 'active': return Colors.green;
      case 'completed': return Colors.grey;
      case 'cancelled': return Colors.red;
      default: return Colors.orange;
    }
  }

 Widget _buildBookingList(List<Booking> bookings) {
    if (bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('No bookings found', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadBookings,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: bookings.length,
        itemBuilder: (context, index) {
          final booking = bookings[index];

          // --- UPDATE START ---
          // 1. Manually add 5:30 to convert UTC from server to IST
          final displayStart = booking.startTime.add(const Duration(hours: 5, minutes: 30));
          final displayEnd = booking.endTime.add(const Duration(hours: 5, minutes: 30));
          // --- UPDATE END ---

          final now = DateTime.now();
          final isPast = booking.endTime.isBefore(now) ||
                         booking.status.toLowerCase() == 'completed' || 
                         booking.status.toLowerCase() == 'cancelled';

          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.only(bottom: 16),
            child: InkWell(
              onTap: () {
                if (booking.qrCode != null) {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => QRCodeScreen(booking: booking)),
                  );
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            booking.parking?.name ?? 'Parking Slot',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getStatusColor(booking.status).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            booking.status.toUpperCase(),
                            style: TextStyle(
                              color: _getStatusColor(booking.status),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 16, color: Colors.blueGrey),
                        const SizedBox(width: 8),
                        Text(
                          // --- UPDATE: Use displayStart here ---
                          DateFormat('EEE, MMM dd').format(displayStart),
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const Spacer(),
                        Text(
                          '₹${booking.totalPrice.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.access_time, size: 16, color: Colors.blueGrey),
                        const SizedBox(width: 8),
                        Text(
                          // --- UPDATE: Use displayStart and displayEnd here ---
                          '${DateFormat('HH:mm').format(displayStart)} - ${DateFormat('HH:mm').format(displayEnd)}',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      ],
                    ),
                    if (!isPast && booking.qrCode != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.qr_code, size: 16, color: Theme.of(context).primaryColor),
                          const SizedBox(width: 4),
                          Text(
                            'View Entry QR Code',
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ]
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    // Logic to separate bookings
    final activeBookings = _bookings.where((b) {
      final status = b.status.toLowerCase();
      final isFinished = b.endTime.isBefore(now) || status == 'completed' || status == 'cancelled';
      return !isFinished;
    }).toList();
    
    final pastBookings = _bookings.where((b) {
      final status = b.status.toLowerCase();
      return b.endTime.isBefore(now) || status == 'completed' || status == 'cancelled';
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Bookings'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!)) // Simple error display
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildBookingList(activeBookings),
                    _buildBookingList(pastBookings),
                  ],
                ),
    );
  }
}