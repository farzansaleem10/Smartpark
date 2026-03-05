import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../models/parking.dart';
import '../bookings/booking_screen.dart';

class ParkingDetailsScreen extends StatefulWidget {
  final String parkingId;

  const ParkingDetailsScreen({
    super.key,
    required this.parkingId,
  });

  @override
  State<ParkingDetailsScreen> createState() => _ParkingDetailsScreenState();
}

class _ParkingDetailsScreenState extends State<ParkingDetailsScreen> {
  Parking? _parking;
  int _totalSlots = 0;
  int _availableSlots = 0;
  List<BookedSlot> _bookedSlots = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadParkingDetails();
  }

  Future<void> _loadParkingDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // First, load the basic parking info
      final parkingResponse = await ApiService.getParking(widget.parkingId);
      if (parkingResponse['success'] &&
          parkingResponse['data']?['parking'] != null) {
        setState(() {
          _parking = Parking.fromJson(parkingResponse['data']['parking']);
          // Use parking data as fallback for slots info
          _totalSlots = _parking!.totalSlots;
          _availableSlots = _parking!.availableSlots;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = parkingResponse['message'] ?? 'Failed to load parking information';
          _isLoading = false;
        });
        return;
      }

      // Try to load detailed slot information (optional)
      try {
        final response = await ApiService.getParkingDetails(widget.parkingId);
        if (response['success'] && response['data'] != null) {
          final data = response['data'];
          setState(() {
            _totalSlots = data['totalSlots'] ?? _parking?.totalSlots ?? 0;
            _availableSlots = data['availableSlots'] ?? _parking?.availableSlots ?? 0;
            _bookedSlots = (data['bookedSlots'] as List? ?? [])
                .map((slot) {
                  try {
                    return BookedSlot.fromJson(slot);
                  } catch (e) {
                    return null;
                  }
                })
                .whereType<BookedSlot>()
                .toList();
          });
        }
      } catch (detailsError) {
        // If details endpoint doesn't exist, continue with basic info
        // This is fine - we already have the parking info loaded
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _showManualBookingDialog() async {
    final slotNumberController = TextEditingController();
    final customerNameController = TextEditingController();
    final vehicleNumberController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Book Slot Manually'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: slotNumberController,
                decoration: const InputDecoration(
                  labelText: 'Slot Number',
                  hintText: 'Enter slot number',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: customerNameController,
                decoration: const InputDecoration(
                  labelText: 'Customer Name',
                  hintText: 'Enter customer name',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: vehicleNumberController,
                decoration: const InputDecoration(
                  labelText: 'Vehicle Number',
                  hintText: 'Enter vehicle number',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (slotNumberController.text.isEmpty ||
                  customerNameController.text.isEmpty ||
                  vehicleNumberController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill all fields'),
                  ),
                );
                return;
              }

              try {
                final slotNum = int.tryParse(slotNumberController.text);
                if (slotNum == null) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter a valid slot number'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                  return;
                }

                final response = await ApiService.createManualBooking(
                  parkingId: widget.parkingId,
                  slotNumber: slotNum,
                  customerName: customerNameController.text.trim(),
                  vehicleNumber: vehicleNumberController.text.trim(),
                );

                if (response['success'] == true) {
                  if (context.mounted) {
                    Navigator.pop(context, true);
                    final message = response['message'] ?? 'Slot booked successfully';
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(message),
                        backgroundColor: Colors.green,
                      ),
                    );
                    _loadParkingDetails();
                  }
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          response['message'] ?? 'Failed to book slot',
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Book'),
          ),
        ],
      ),
    );

    if (result == true) {
      _loadParkingDetails();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Parking Details'),
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
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadParkingDetails,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_parking != null) ...[
                        Container(
                          height: 200,
                          color: Colors.grey[300],
                          child: _parking!.images.isNotEmpty
                              ? Image.network(
                                  _parking!.images.first,
                                  fit: BoxFit.cover,
                                )
                              : Icon(
                                  Icons.local_parking,
                                  size: 80,
                                  color: Colors.grey[600],
                                ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _parking!.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ),
                                  if (_parking!.isVerified)
                                    Chip(
                                      label: const Text('Verified'),
                                      avatar: const Icon(
                                        Icons.verified,
                                        size: 18,
                                      ),
                                      backgroundColor: Colors.green[100],
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (_parking!.description != null)
                                Text(
                                  _parking!.description!,
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              const SizedBox(height: 16),
                              _buildInfoRow(
                                Icons.location_on,
                                _parking!.address.fullAddress,
                              ),
                              const SizedBox(height: 8),
                              _buildInfoRow(
                                Icons.attach_money,
                                '₹${_parking!.pricePerHour.toStringAsFixed(0)} per hour',
                              ),
                            ],
                          ),
                        ),
                      ],
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Slot Summary',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _SlotSummaryCard(
                                    title: 'Total Slots',
                                    value: _totalSlots.toString(),
                                    icon: Icons.local_parking,
                                    color: Colors.blue,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _SlotSummaryCard(
                                    title: 'Available',
                                    value: _availableSlots.toString(),
                                    icon: Icons.check_circle,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _SlotSummaryCard(
                              title: 'Booked Slots',
                              value: _bookedSlots.length.toString(),
                              icon: Icons.event_busy,
                              color: Colors.orange,
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Booked Slots',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: _showManualBookingDialog,
                                  icon: const Icon(Icons.add),
                                  label: const Text('Book Slot Manually'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (_bookedSlots.isEmpty)
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Center(
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.event_available,
                                          size: 48,
                                          color: Colors.grey[400],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'No slots booked',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                            else
                              Card(
                                child: Column(
                                  children: [
                                    ..._bookedSlots.asMap().entries.map((entry) {
                                      final slot = entry.value;
                                      final isLast = entry.key == _bookedSlots.length - 1;
                                      return _BookedSlotRow(
                                        slot: slot,
                                        showDivider: !isLast,
                                      );
                                    }),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: Colors.grey[700]),
          ),
        ),
      ],
    );
  }
}

class _SlotSummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SlotSummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookedSlotRow extends StatelessWidget {
  final BookedSlot slot;
  final bool showDivider;

  const _BookedSlotRow({
    required this.slot,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    slot.slotNumber.toString(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[700],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      slot.customerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      slot.vehicleNumber,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Booked: ${_formatDateTime(slot.bookingTime)}',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showDivider) const Divider(height: 1),
      ],
    );
  }

  String _formatDateTime(String dateTime) {
    try {
      final dt = DateTime.parse(dateTime);
      return DateFormat('MMM dd, yyyy • hh:mm a').format(dt);
    } catch (e) {
      return dateTime;
    }
  }
}

class BookedSlot {
  final int slotNumber;
  final String customerName;
  final String vehicleNumber;
  final String bookingTime;

  BookedSlot({
    required this.slotNumber,
    required this.customerName,
    required this.vehicleNumber,
    required this.bookingTime,
  });

  factory BookedSlot.fromJson(Map<String, dynamic> json) {
    return BookedSlot(
      slotNumber: json['slotNumber'] ?? 0,
      customerName: json['customerName'] ?? '',
      vehicleNumber: json['vehicleNumber'] ?? '',
      bookingTime: json['bookingTime'] ?? '',
    );
  }
}