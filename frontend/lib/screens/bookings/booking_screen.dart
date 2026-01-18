import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/parking.dart';
import '../../services/api_service.dart';
import 'booking_confirmation_screen.dart';

class BookingScreen extends StatefulWidget {
  final Parking parking;

  const BookingScreen({
    super.key,
    required this.parking,
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  DateTime? _startTime;
  DateTime? _endTime;
  String _paymentMethod = 'cash';
  bool _isLoading = false;
  int? _availableSlots;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now().add(const Duration(hours: 1));
    _endTime = _startTime!.add(const Duration(hours: 2));
    _checkAvailability();
  }

  Future<void> _checkAvailability() async {
    if (_startTime == null || _endTime == null) return;

    try {
      final response = await ApiService.checkAvailability(
        parkingId: widget.parking.id,
        startTime: _startTime!,
        endTime: _endTime!,
      );

      if (response['success'] && response['data'] != null) {
        setState(() {
          _availableSlots = response['data']['availableSlots'];
        });
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _selectStartTime() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startTime ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (picked != null) {
      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_startTime ?? DateTime.now()),
      );

      if (time != null) {
        setState(() {
          _startTime = DateTime(
            picked.year,
            picked.month,
            picked.day,
            time.hour,
            time.minute,
          );
          if (_endTime == null || _endTime!.isBefore(_startTime!)) {
            _endTime = _startTime!.add(const Duration(hours: 2));
          }
        });
        _checkAvailability();
      }
    }
  }

  Future<void> _selectEndTime() async {
    if (_startTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select start time first')),
      );
      return;
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endTime ?? _startTime!,
      firstDate: _startTime!,
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (picked != null) {
      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_endTime ?? _startTime!),
      );

      if (time != null) {
        final selectedEndTime = DateTime(
          picked.year,
          picked.month,
          picked.day,
          time.hour,
          time.minute,
        );

        if (selectedEndTime.isBefore(_startTime!) ||
            selectedEndTime.isAtSameMomentAs(_startTime!)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('End time must be after start time'),
            ),
          );
          return;
        }

        setState(() {
          _endTime = selectedEndTime;
        });
        _checkAvailability();
      }
    }
  }

  double _calculatePrice() {
    if (_startTime == null || _endTime == null) return 0.0;
    final duration = _endTime!.difference(_startTime!).inHours;
    return duration * widget.parking.pricePerHour;
  }

  Future<void> _createBooking() async {
    if (_startTime == null || _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select start and end time')),
      );
      return;
    }

    if (_availableSlots != null && _availableSlots! <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No slots available for selected time')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await ApiService.createBooking(
        parkingId: widget.parking.id,
        startTime: _startTime!,
        endTime: _endTime!,
        paymentMethod: _paymentMethod,
      );

      if (response['success'] && response['data']?['booking'] != null) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => BookingConfirmationScreen(
                bookingId: response['data']['booking']['_id'],
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Booking failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final price = _calculatePrice();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Parking'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.parking.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.parking.address.fullAddress,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Select Time',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.access_time),
                title: const Text('Start Time'),
                subtitle: Text(
                  _startTime != null
                      ? DateFormat('MMM dd, yyyy - HH:mm')
                          .format(_startTime!)
                      : 'Not selected',
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: _selectStartTime,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.access_time),
                title: const Text('End Time'),
                subtitle: Text(
                  _endTime != null
                      ? DateFormat('MMM dd, yyyy - HH:mm').format(_endTime!)
                      : 'Not selected',
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: _selectEndTime,
              ),
            ),
            if (_availableSlots != null) ...[
              const SizedBox(height: 16),
              Card(
                color: _availableSlots! > 0 ? Colors.green[50] : Colors.red[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        _availableSlots! > 0
                            ? Icons.check_circle
                            : Icons.cancel,
                        color: _availableSlots! > 0 ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _availableSlots! > 0
                            ? '$_availableSlots slots available'
                            : 'No slots available',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _availableSlots! > 0 ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Text(
              'Payment Method',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            ...['cash', 'card', 'upi', 'wallet'].map((method) {
              return RadioListTile<String>(
                title: Text(method.toUpperCase()),
                value: method,
                groupValue: _paymentMethod,
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _paymentMethod = value;
                    });
                  }
                },
              );
            }),
            const SizedBox(height: 24),
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Duration',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                        Text(
                          _startTime != null && _endTime != null
                              ? '${_endTime!.difference(_startTime!).inHours} hours'
                              : '0 hours',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Price',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        Text(
                          '₹${price.toStringAsFixed(2)}',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _createBooking,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Confirm Booking'),
            ),
          ],
        ),
      ),
    );
  }
}
