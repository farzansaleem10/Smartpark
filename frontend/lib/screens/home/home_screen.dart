import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../models/parking.dart';
import '../auth/login_screen.dart';
import '../parking/parking_details_screen.dart';
import '../owner/owner_dashboard_screen.dart';
import '../admin/admin_dashboard_screen.dart';
import '../bookings/booking_history_screen.dart';

const LatLng _defaultCenter = LatLng(20.5937, 78.9629); // India center

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  Position? _currentPosition;
  LatLng? _centerLocation;

  List<Parking> _parkings = [];
  bool _isLoading = false;
  bool _isSearching = false;
  String? _error;
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /* ---------------- LOCATION ---------------- */

  Future<void> _getCurrentLocation() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        setState(() => _error = 'Location services are disabled');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() => _error = 'Location permission denied');
        return;
      }

      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );

      _centerLocation = LatLng(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );

      if (_mapReady) {
        _mapController.move(_centerLocation!, 15);
      }

      _loadParkings();
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  /* ---------------- PARKINGS ---------------- */

  Future<void> _loadParkings() async {
    if (_centerLocation == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final res = await ApiService.getParkings(
        latitude: _centerLocation!.latitude,
        longitude: _centerLocation!.longitude,
        radius: 5000,
      );

      if (res['success']) {
        _parkings = (res['data']['parkings'] as List)
            .map((e) => Parking.fromJson(e))
            .toList();
      } else {
        _error = res['message'];
      }
    } catch (e) {
      _error = e.toString();
    }

    setState(() => _isLoading = false);
  }

  /* ---------------- SEARCH ---------------- */

  Future<void> _searchLocation() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() => _isSearching = true);

    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=1',
      );

      final res = await http.get(
        uri,
        headers: {'User-Agent': 'smart-parking-app'},
      );

      final data = jsonDecode(res.body);
      if (data.isNotEmpty) {
        final lat = double.parse(data[0]['lat']);
        final lon = double.parse(data[0]['lon']);

        _centerLocation = LatLng(lat, lon);

        if (_mapReady) {
          _mapController.move(_centerLocation!, 15);
        }

        _loadParkings();
      }
    } catch (_) {}

    setState(() => _isSearching = false);
  }

  /* ---------------- UI HELPERS ---------------- */

  void _showParkingBottomSheet(Parking parking) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(parking.name,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(parking.address.fullAddress),
            const SizedBox(height: 12),
            Text(
              '₹${parking.pricePerHour}/hr • '
              '${parking.availableSlots}/${parking.totalSlots} slots',
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ParkingDetailsScreen(parkingId: parking.id),
                    ),
                  );
                },
                child: const Text('View Details'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /* ---------------- BUILD ---------------- */

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Parking'),
        actions: [
          PopupMenuButton(
            onSelected: (v) async {
              if (v == 'logout') {
                await auth.logout();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
              if (v == 'owner') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const OwnerDashboardScreen()),
                );
              }
              if (v == 'admin') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AdminDashboardScreen()),
                );
              }
              if (v == 'history') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const BookingHistoryScreen()),
                );
              }
            },
            itemBuilder: (_) => [
              if (user?.role == 'owner')
                const PopupMenuItem(value: 'owner', child: Text('Owner')),
              if (user?.role == 'admin')
                const PopupMenuItem(value: 'admin', child: Text('Admin')),
              const PopupMenuItem(value: 'history', child: Text('History')),
              const PopupMenuItem(value: 'logout', child: Text('Logout')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              onSubmitted: (_) => _searchLocation(),
              decoration: InputDecoration(
                hintText: 'Search location',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          if (_currentPosition != null) {
                            _centerLocation = LatLng(
                              _currentPosition!.latitude,
                              _currentPosition!.longitude,
                            );
                            _mapController.move(_centerLocation!, 15);
                            _loadParkings();
                          }
                        },
                      ),
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _defaultCenter,
                    initialZoom: 14,
                    onMapReady: () {
                      _mapReady = true;
                      if (_centerLocation != null) {
                        _mapController.move(_centerLocation!, 15);
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.smartparking.app',
                    ),
                    MarkerLayer(
                      markers: _parkings
                          .map(
                            (p) => Marker(
                              point: LatLng(
                                p.location.latitude,
                                p.location.longitude,
                              ),
                              width: 40,
                              height: 40,
                              child: GestureDetector(
                                onTap: () =>
                                    _showParkingBottomSheet(p),
                                child: const Icon(
                                  Icons.local_parking,
                                  color: Colors.red,
                                  size: 36,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator()),
                if (_error != null)
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: Material(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
