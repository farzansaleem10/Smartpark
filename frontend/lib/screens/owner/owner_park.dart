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
  
  // Overall Analytics Variables
  double _totalEarnings = 0.0;
  int _totalBookingsCount = 0;

  // Detailed Analytics Maps
  String _selectedAnalyticsFilter = 'Daily'; // Daily, Monthly, Yearly
  final Map<String, double> _dailyEarnings = {};
  final Map<String, int> _dailyBookings = {};
  final Map<String, double> _monthlyEarnings = {};
  final Map<String, int> _monthlyBookings = {};
  final Map<String, double> _yearlyEarnings = {};
  final Map<String, int> _yearlyBookings = {};
  
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
        
        // Reset maps before calculating
        _dailyEarnings.clear();
        _dailyBookings.clear();
        _monthlyEarnings.clear();
        _monthlyBookings.clear();
        _yearlyEarnings.clear();
        _yearlyBookings.clear();

        double calcEarnings = 0.0;
        
        for (var b in bookingsData) {
          // Extract Price
          final priceStr = b['totalPrice'];
          double price = 0.0;
          if (priceStr != null) {
            price = double.tryParse(priceStr.toString()) ?? 0.0;
          }
          calcEarnings += price;

          // Categorize by Date
          final startStr = b['startTime'] ?? b['bookingTime'];
          if (startStr != null) {
            try {
              DateTime dt = DateTime.parse(startStr).toLocal();
              
              String dayKey = DateFormat('yyyy-MM-dd').format(dt);
              String monthKey = DateFormat('yyyy-MM').format(dt);
              String yearKey = DateFormat('yyyy').format(dt);

              _dailyEarnings[dayKey] = (_dailyEarnings[dayKey] ?? 0.0) + price;
              _dailyBookings[dayKey] = (_dailyBookings[dayKey] ?? 0) + 1;

              _monthlyEarnings[monthKey] = (_monthlyEarnings[monthKey] ?? 0.0) + price;
              _monthlyBookings[monthKey] = (_monthlyBookings[monthKey] ?? 0) + 1;

              _yearlyEarnings[yearKey] = (_yearlyEarnings[yearKey] ?? 0.0) + price;
              _yearlyBookings[yearKey] = (_yearlyBookings[yearKey] ?? 0) + 1;
            } catch (_) {
              // Ignore invalid dates
            }
          }
        }

        setState(() {
          _totalEarnings = calcEarnings;
          _totalBookingsCount = bookingsData.length;
          _bookedSlots = bookingsData
              .map((slot) => BookedSlot.fromJson(slot))
              .toList();
          _isLoading = false;
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
    final expiredSlots = <BookedSlot>[];

    for (final slot in _bookedSlots) {
      if (!slot.isActive && _isExpiredFor24Hours(slot.endTime)) {
        expiredSlots.add(slot);
      }
    }

    if (expiredSlots.isEmpty) return;

    try {
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

  Widget _buildDetailedAnalytics() {
    Map<String, double> earnMap;
    Map<String, int> bookMap;

    if (_selectedAnalyticsFilter == 'Daily') {
      earnMap = _dailyEarnings;
      bookMap = _dailyBookings;
    } else if (_selectedAnalyticsFilter == 'Monthly') {
      earnMap = _monthlyEarnings;
      bookMap = _monthlyBookings;
    } else {
      earnMap = _yearlyEarnings;
      bookMap = _yearlyBookings;
    }

    List<String> sortedKeys = earnMap.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // Newest first

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8.0,
              alignment: WrapAlignment.center,
              children: ['Daily', 'Monthly', 'Yearly'].map((String choice) {
                return ChoiceChip(
                  label: Text(choice),
                  selected: _selectedAnalyticsFilter == choice,
                  onSelected: (bool selected) {
                    if (selected) {
                      setState(() => _selectedAnalyticsFilter = choice);
                    }
                  },
                );
              }).toList(),
            ),
            const Divider(),
            if (sortedKeys.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24.0),
                child: Center(child: Text("No records available.")),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sortedKeys.length,
                itemBuilder: (context, index) {
                  final key = sortedKeys[index];
                  final earn = earnMap[key]!;
                  final book = bookMap[key]!;

                  // Format the display string based on selection
                  String displayKey = key;
                  if (_selectedAnalyticsFilter == 'Daily') {
                    displayKey = DateFormat('dd MMM yyyy')
                        .format(DateTime.parse(key));
                  } else if (_selectedAnalyticsFilter == 'Monthly') {
                    displayKey = DateFormat('MMMM yyyy')
                        .format(DateTime.parse('$key-01'));
                  }

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      displayKey,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('$book Bookings'),
                    trailing: Text(
                      '₹${earn.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  );
                },
              )
          ],
        ),
      ),
    );
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
                            // 1. Top Slot Availability Summary
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

                            const SizedBox(height: 24),

                            // 2. Booked Slots Section
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

                            const SizedBox(height: 12),

                            if (_bookedSlots.isEmpty)
                              const Card(
                                child: Padding(
                                  padding: EdgeInsets.all(24.0),
                                  child: Center(
                                    child: Text("No currently booked slots"),
                                  ),
                                ),
                              )
                            else
                              Card(
                                child: Column(
                                  children: _bookedSlots.map((slot) {
                                    return _BookedSlotRow(slot: slot);
                                  }).toList(),
                                ),
                              ),

                            const SizedBox(height: 24),

                            // 3. OVERALL Earnings Summary (Moved Below Booked Slots)
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "Overall Analytics",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _SlotSummaryCard(
                                    title: 'Earnings',
                                    value: '₹${_totalEarnings.toStringAsFixed(0)}',
                                    icon: Icons.account_balance_wallet,
                                    color: Colors.purple,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _SlotSummaryCard(
                                    title: 'Total Bookings',
                                    value: _totalBookingsCount.toString(),
                                    icon: Icons.analytics,
                                    color: Colors.orange,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 24),

                            // 4. DETAILED Daily/Monthly/Yearly Records
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "Detailed Analytics",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildDetailedAnalytics(),
                            
                            const SizedBox(height: 30), // Bottom padding
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
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontSize: 13)),
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
          style: const TextStyle(color: Colors.white, fontSize: 10),
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