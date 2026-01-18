import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/parking.dart';
import 'add_parking_screen.dart';
import 'edit_parking_screen.dart';

class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  List<Parking> _parkings = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadParkings();
  }

  Future<void> _loadParkings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await ApiService.getMyParkings();

      if (response['success'] && response['data']?['parkings'] != null) {
        setState(() {
          _parkings = (response['data']['parkings'] as List)
              .map((p) => Parking.fromJson(p))
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = response['message'] ?? 'Failed to load parkings';
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
        title: const Text('Owner Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final result = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AddParkingScreen(),
                ),
              );
              if (result == true) {
                _loadParkings();
              }
            },
          ),
        ],
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
                        onPressed: _loadParkings,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _parkings.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.local_parking_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No parking spaces yet',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () async {
                              final result = await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const AddParkingScreen(),
                                ),
                              );
                              if (result == true) {
                                _loadParkings();
                              }
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Add Parking Space'),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadParkings,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _parkings.length,
                        itemBuilder: (context, index) {
                          final parking = _parkings[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          parking.name,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                      ),
                                      if (parking.isVerified)
                                        Chip(
                                          label: const Text('Verified'),
                                          backgroundColor: Colors.green[100],
                                        )
                                      else
                                        Chip(
                                          label: const Text('Pending'),
                                          backgroundColor: Colors.orange[100],
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    parking.address.fullAddress,
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.local_parking,
                                        size: 16,
                                        color: Colors.grey[600],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${parking.availableSlots}/${parking.totalSlots} slots',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        '₹${parking.pricePerHour.toStringAsFixed(0)}/hr',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                            ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton.icon(
                                        onPressed: () async {
                                          final result =
                                              await Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => EditParkingScreen(
                                                parking: parking,
                                              ),
                                            ),
                                          );
                                          if (result == true) {
                                            _loadParkings();
                                          }
                                        },
                                        icon: const Icon(Icons.edit),
                                        label: const Text('Edit'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
