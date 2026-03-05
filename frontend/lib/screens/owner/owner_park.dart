import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../models/parking.dart';

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
      final parkingResponse = await ApiService.getParking(widget.parkingId);

      if (parkingResponse['success'] &&
          parkingResponse['data']?['parking'] != null) {
        setState(() {
          _parking = Parking.fromJson(parkingResponse['data']['parking']);
          _totalSlots = _parking!.totalSlots;
          _availableSlots = _parking!.availableSlots;
          _isLoading = false;
        });
      }

      final response = await ApiService.getParkingDetails(widget.parkingId);

      if (response['success'] && response['data'] != null) {
        final data = response['data'];

        setState(() {
          _totalSlots = data['totalSlots'] ?? _totalSlots;
          _availableSlots = data['availableSlots'] ?? _availableSlots;
        });
      }

      final bookingsResponse = await ApiService.getOwnerBookings(widget.parkingId);
      if (bookingsResponse['success'] && bookingsResponse['data'] != null) {
        final List bookingsData = bookingsResponse['data']['bookings'] ?? [];
        setState(() {
          _bookedSlots = bookingsData
              .map((slot) => BookedSlot.fromJson(slot))
              .toList();
        });
        // Clean up inactive bookings after 24 hours
        await _cleanupExpiredBookings();
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _cleanupExpiredBookings() async {
    final now = DateTime.now();
    final expiredSlots = <BookedSlot>[];

    for (final slot in _bookedSlots) {
      if (!slot.isActive && _isExpiredFor24Hours(slot.endTime)) {
        expiredSlots.add(slot);
      }
    }

    if (expiredSlots.isEmpty) return;

    // Delete expired bookings and reload data
    try {
      for (final slot in expiredSlots) {
        // Try to delete from backend if booking has an ID
        // Note: You may need to pass booking ID in the BookedSlot model
        // For now, we'll just remove from the local list
      }

      // Reload to get updated slot availability
      if (mounted) {
        setState(() {
          _bookedSlots = _bookedSlots
              .where((slot) => !expiredSlots.contains(slot))
              .toList();
        });
      }
    } catch (e) {
      print('Error cleaning up expired bookings: $e');
    }
  }

  bool _isExpiredFor24Hours(String endTimeStr) {
    try {
      final endTime = DateTime.parse(endTimeStr);
      final now = DateTime.now();
      final difference = now.difference(endTime);
      // Check if more than 24 hours have passed since booking ended
      return difference.inHours >= 24;
    } catch (_) {
      return false;
    }
  }

  Future<void> _showManualBookingDialog() async {
    final slotNumberController = TextEditingController();
    final customerNameController = TextEditingController();
    final vehicleNumberController = TextEditingController();

    late DateTime selectedStartTime;
    late DateTime selectedEndTime;

    // Initialize with current time in IST
    selectedStartTime = DateTime.now();
    selectedEndTime = selectedStartTime.add(const Duration(hours: 1));

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Book Slot Manually'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: slotNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Slot Number',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: customerNameController,
                  decoration: const InputDecoration(
                    labelText: 'Customer Name',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: vehicleNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Vehicle Number',
                  ),
                ),
                const SizedBox(height: 20),
                // Start Time Selection
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Booking Start Time (IST)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _formatTimeIST(selectedStartTime),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () async {
                                final pickedDate = await showDatePicker(
                                  context: context,
                                  initialDate: selectedStartTime,
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 30),
                                  ),
                                );
                                if (pickedDate != null) {
                                  final pickedTime = await showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay.fromDateTime(
                                      selectedStartTime,
                                    ),
                                  );
                                  if (pickedTime != null) {
                                    setDialogState(() {
                                      selectedStartTime = DateTime(
                                        pickedDate.year,
                                        pickedDate.month,
                                        pickedDate.day,
                                        pickedTime.hour,
                                        pickedTime.minute,
                                      );
                                      // Auto-adjust end time if it's before start time
                                      if (selectedEndTime
                                          .isBefore(selectedStartTime)) {
                                        selectedEndTime = selectedStartTime
                                            .add(const Duration(hours: 1));
                                      }
                                    });
                                  }
                                }
                              },
                              icon: const Icon(Icons.access_time),
                              label: const Text('Select'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // End Time Selection
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Booking End Time (IST)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _formatTimeIST(selectedEndTime),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () async {
                                final pickedDate = await showDatePicker(
                                  context: context,
                                  initialDate: selectedEndTime,
                                  firstDate: selectedStartTime,
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 30),
                                  ),
                                );
                                if (pickedDate != null) {
                                  final pickedTime = await showTimePicker(
                                    context: context,
                                    initialTime:
                                        TimeOfDay.fromDateTime(selectedEndTime),
                                  );
                                  if (pickedTime != null) {
                                    final newEndTime = DateTime(
                                      pickedDate.year,
                                      pickedDate.month,
                                      pickedDate.day,
                                      pickedTime.hour,
                                      pickedTime.minute,
                                    );
                                    if (newEndTime.isAfter(selectedStartTime)) {
                                      setDialogState(() {
                                        selectedEndTime = newEndTime;
                                      });
                                    } else {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'End time must be after start time',
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                }
                              },
                              icon: const Icon(Icons.access_time),
                              label: const Text('Select'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Duration Display
                Card(
                  color: Colors.blue[50],
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.schedule, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          'Duration: ${_calculateDuration(selectedStartTime, selectedEndTime)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
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
                final slotNum = int.tryParse(slotNumberController.text);

                if (slotNum == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid slot number'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                if (customerNameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter customer name'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                if (vehicleNumberController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter vehicle number'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                final response = await ApiService.createManualBooking(
                  parkingId: widget.parkingId,
                  slotNumber: slotNum,
                  customerName: customerNameController.text.trim(),
                  vehicleNumber: vehicleNumberController.text.trim(),
                  startTime: selectedStartTime.toUtc().toIso8601String(),
                  endTime: selectedEndTime.toUtc().toIso8601String(),
                );

                if (response['success']) {
                  if (context.mounted) {
                    Navigator.pop(context, true);
                    _loadParkingDetails();
                  }
                }
              },
              child: const Text('Book'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      _loadParkingDetails();
    }
  }

  String _formatTimeIST(DateTime dateTime) {
    // Format datetime in IST - just display the local time as-is
    // because DateTime.now() is already in the device's local timezone (IST)
    return DateFormat('dd MMM, yyyy • hh:mm a').format(dateTime);
  }

  String _calculateDuration(DateTime start, DateTime end) {
    final difference = end.difference(start);
    final hours = difference.inHours;
    final minutes = difference.inMinutes % 60;
    if (hours == 0) {
      return '${minutes}m';
    } else if (minutes == 0) {
      return '${hours}h';
    } else {
      return '${hours}h ${minutes}m';
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(title: const Text("Parking Details")),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : SingleChildScrollView(
                  child: Column(
                    children: [

                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [

                            Row(
                              children: [
                                Expanded(
                                  child: _SlotSummaryCard(
                                    title: 'Total',
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

                            const SizedBox(height: 16),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [

                                const Text(
                                  "Booked Slots",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18),
                                ),

                                ElevatedButton.icon(
                                  onPressed: _showManualBookingDialog,
                                  icon: const Icon(Icons.add),
                                  label: const Text("Book Slot"),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            Card(
                              child: Column(
                                children: _bookedSlots.map((slot) {
                                  return _BookedSlotRow(slot: slot);
                                }).toList(),
                              ),
                            )
                          ],
                        ),
                      )
                    ],
                  ),
                ),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            Icon(icon, color: color, size: 30),

            const SizedBox(height: 10),

            Text(title),

            const SizedBox(height: 5),

            Text(
              value,
              style: TextStyle(
                fontSize: 22,
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

  const _BookedSlotRow({
    required this.slot,
  });

  @override
  Widget build(BuildContext context) {

    final statusColor = slot.isActive ? Colors.green : Colors.red;
    final statusText = slot.isActive ? "ACTIVE" : "NOT ACTIVE";
    final expireTime = _getExpiryTime();

    return ListTile(

      leading: CircleAvatar(
        backgroundColor: statusColor.withOpacity(.2),
        child: Text(
          slot.slotNumber.toString(),
          style: TextStyle(color: statusColor),
        ),
      ),

      title: Text(slot.customerName),

      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(slot.vehicleNumber),
          const SizedBox(height: 4),
          Text(
            "Start: ${_format(slot.startTime)}",
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(
            "End: ${_format(slot.endTime)}",
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              "Duration: ${_calculateDurationString(slot.startTime, slot.endTime)}",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue,
                fontSize: 12,
              ),
            ),
          ),
          if (!slot.isActive && expireTime != null)
            Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.orange),
                ),
                child: Text(
                  "Will auto-remove in: $expireTime",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
        ],
      ),

      trailing: Chip(
        backgroundColor: statusColor,
        label: Text(
          statusText,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  String? _getExpiryTime() {
    try {
      final endTime = DateTime.parse(slot.endTime);
      final now = DateTime.now();
      final difference = now.difference(endTime);
      
      if (difference.isNegative) return null; // Booking is still active
      
      // Calculate remaining time until 24 hours have passed
      const int totalMinutesIn24Hours = 24 * 60;
      final int remainingMinutes = totalMinutesIn24Hours - difference.inMinutes;
      
      if (remainingMinutes > 0) {
        final int hours = remainingMinutes ~/ 60;
        final int minutes = remainingMinutes % 60;
        return "${hours}h ${minutes}m";
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  String _format(String time) {
    try {
      final dt = DateTime.parse(time);
      // Convert to IST by adding 5:30 hours if the time is in UTC
      // If the datetime already has timezone info, parse will handle it
      final istDateTime = dt.add(const Duration(hours: 5, minutes: 30));
      return DateFormat('MMM dd • hh:mm a').format(istDateTime);
    } catch (_) {
      return time;
    }
  }

  String _calculateDurationString(String startTimeStr, String endTimeStr) {
    try {
      final start = DateTime.parse(startTimeStr);
      final end = DateTime.parse(endTimeStr);
      final difference = end.difference(start);
      final hours = difference.inHours;
      final minutes = difference.inMinutes % 60;
      if (hours == 0) {
        return '${minutes}m';
      } else if (minutes == 0) {
        return '${hours}h';
      } else {
        return '${hours}h ${minutes}m';
      }
    } catch (_) {
      return 'N/A';
    }
  }
}

class BookedSlot {

  final int slotNumber;
  final String customerName;
  final String vehicleNumber;
  final String startTime;
  final String endTime;
  final String? id;

  BookedSlot({
    required this.slotNumber,
    required this.customerName,
    required this.vehicleNumber,
    required this.startTime,
    required this.endTime,
    this.id,
  });

  bool get isActive {
    try {
      final end = DateTime.parse(endTime);
      return DateTime.now().isBefore(end);
    } catch (_) {
      return false;
    }
  }

  factory BookedSlot.fromJson(Map<String, dynamic> json) {

    final start = json['startTime'] ?? json['bookingTime'];

    final end = json['endTime'] ??
        DateTime.parse(start).add(const Duration(hours: 1)).toIso8601String();

    return BookedSlot(
      slotNumber: json['slotNumber'] ?? 0,
      customerName: json['customerName'] ?? '',
      vehicleNumber: json['vehicleNumber'] ?? '',
      startTime: start,
      endTime: end,
      id: json['_id'] ?? json['id'],
    );
  }
}