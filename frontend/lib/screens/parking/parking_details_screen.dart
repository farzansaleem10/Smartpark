import 'package:flutter/material.dart';
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
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadParking();
  }

  Future<void> _loadParking() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await ApiService.getParking(widget.parkingId);

      if (response['success'] && response['data']?['parking'] != null) {
        setState(() {
          _parking = Parking.fromJson(response['data']['parking']);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = response['message'] ?? 'Failed to load parking details';
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
                        onPressed: _loadParking,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _parking == null
                  ? const Center(child: Text('Parking not found'))
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Parking Image Placeholder
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
                                        backgroundColor:
                                            Colors.green[100],
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
                                  Icons.local_parking,
                                  '${_parking!.availableSlots}/${_parking!.totalSlots} slots available',
                                ),
                                const SizedBox(height: 8),
                                _buildInfoRow(
                                  Icons.attach_money,
                                  '₹${_parking!.pricePerHour.toStringAsFixed(0)} per hour',
                                ),
                                if (_parking!.rating.average > 0) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.star,
                                        color: Colors.amber,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${_parking!.rating.average.toStringAsFixed(1)} (${_parking!.rating.count} reviews)',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                if (_parking!.amenities.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  Text(
                                    'Amenities',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: _parking!.amenities
                                        .map((amenity) => Chip(
                                              label: Text(amenity),
                                            ))
                                        .toList(),
                                  ),
                                ],
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _parking!.availableSlots > 0
                                        ? () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) => BookingScreen(
                                                  parking: _parking!,
                                                ),
                                              ),
                                            );
                                          }
                                        : null,
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                    ),
                                    child: const Text('Book Now'),
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
