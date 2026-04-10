import 'dart:async';
import 'dart:convert';
import 'dart:ui';

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
import 'parking_details_screen.dart';
import '../owner/owner_dashboard_screen.dart';
import '../admin/admin_dashboard_screen.dart';
import '../bookings/booking_history_screen.dart';

// Your default start point
const LatLng _defaultCenter = LatLng(8.5459, 76.9063);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  Position? _userPosition;
  StreamSubscription<Position>? _posStream;

  List<Parking> _allParkings = [];
  Parking? _selectedParking;

  List<LatLng> _routePoints = [];
  bool _loadingRoute = false;

  LatLng _mapCenter = _defaultCenter;
  static const double _listRadiusMeters = 5000;

  List<Parking> get _nearbyParkings {
    const distance = Distance();
    return _allParkings.where((p) {
      final meters = distance(
        _mapCenter,
        LatLng(p.location.latitude, p.location.longitude),
      );
      return meters <= _listRadiusMeters;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _initLocation();
    _loadParkings();
  }

  @override
  void dispose() {
    _posStream?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initLocation() async {
    final perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) return;

    final pos = await Geolocator.getCurrentPosition();
    _updateUserPosition(pos);

    _posStream = Geolocator.getPositionStream(
      locationSettings:
          const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 5),
    ).listen(_updateUserPosition);
  }

  void _updateUserPosition(Position pos) {
    setState(() {
      _userPosition = pos;
    });
  }

  Future<void> _loadParkings() async {
    final res = await ApiService.getParkings();

    if (res['success']) {
      setState(() {
        _allParkings = (res['data']['parkings'] as List)
            .map((e) => Parking.fromJson(e))
            .toList();
      });
    }
  }

  Future<void> _searchLocation(String query) async {
    final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=1');

    final res = await http.get(uri, headers: {'User-Agent': 'smart-parking-app'});
    final data = jsonDecode(res.body);
    if (data.isEmpty) return;

    final lat = double.parse(data[0]['lat']);
    final lon = double.parse(data[0]['lon']);

    setState(() {
      _mapCenter = LatLng(lat, lon);
    });

    _mapController.move(_mapCenter, 15);
    _loadParkings();
  }

  Future<void> _getDirections(Parking parking) async {
    // FIXED: Strictly using live GPS coordinates if available
    // If GPS isn't ready, it uses the default point so it doesn't crash
    final startLon = _userPosition?.longitude ?? _defaultCenter.longitude;
    final startLat = _userPosition?.latitude ?? _defaultCenter.latitude;

    setState(() {
      _selectedParking = parking;
      _routePoints.clear();
      _loadingRoute = true;
    });

    final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/$startLon,$startLat;${parking.location.longitude},${parking.location.latitude}?overview=full&geometries=geojson');

    final res = await http.get(url);
    final data = jsonDecode(res.body);

    if (data['routes'] != null && data['routes'].isNotEmpty) {
      final coords = data['routes'][0]['geometry']['coordinates'];
      setState(() {
        _routePoints =
            coords.map<LatLng>((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList();
        _loadingRoute = false;
      });
    }
  }

  void _showParkingSheet(Parking parking) {
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
            Text(parking.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(parking.address.fullAddress),
            const SizedBox(height: 12),
            Text('₹${parking.pricePerHour}/hr • ${parking.availableSlots}/${parking.totalSlots} slots'),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ParkingDetailsScreen(parkingId: parking.id)),
                      );
                    },
                    child: const Text('View Details'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _getDirections(parking);
                    },
                    child: const Text('Get Directions'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Parking'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'history':
                  // Navigate to Booking History
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BookingHistoryScreen()),
                  );
                  break;
                case 'logout':
                  // Handle Logout logic
                  final authService = Provider.of<AuthService>(context, listen: false);
                  await authService.logout();
                  if (mounted) {
                    // Redirect to Login and remove all previous screens from stack
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                  break;
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'history',
                child: Row(
                  children: [
                    Icon(Icons.history, color: Colors.black54),
                    SizedBox(width: 10),
                    Text('Booking History'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.redAccent),
                    SizedBox(width: 10),
                    Text('Logout', style: TextStyle(color: Colors.redAccent)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),

      body: Stack(
        children: [

          /// MAP
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: _mapCenter, initialZoom: 14),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.smartparking.app',
              ),
              
              // Draws the direction line on the map
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 5,
                      color: Colors.blueAccent,
                    ),
                  ],
                ),

              MarkerLayer(
                markers: [
                  // BLUE ICON FOR YOUR GPS LOCATION
                  if (_userPosition != null)
                    Marker(
                      point: LatLng(_userPosition!.latitude, _userPosition!.longitude),
                      width: 20,
                      height: 20,
                      child: const Icon(Icons.circle, color: Colors.blue, size: 18),
                    ),

                  ..._allParkings.map((p) {
                    return Marker(
                      point: LatLng(p.location.latitude, p.location.longitude),
                      width: 50,
                      height: 50,
                      child: GestureDetector(
                        onTap: () => _showParkingSheet(p),
                        child: Image.asset('assets/icons/parking_pin.png'),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ],
          ),

          /// SEARCH BAR
          Positioned(
            top: 20,
            left: 16,
            right: 16,
            child: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(12),
              child: TextField(
                controller: _searchController,
                onSubmitted: _searchLocation,
                decoration: const InputDecoration(
                  hintText: 'Search location',
                  prefixIcon: Icon(Icons.search),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(14),
                ),
              ),
            ),
          ),

          /// DRAGGABLE PANEL
          Align(
            alignment: Alignment.bottomCenter,
            child: DraggableScrollableSheet(
              initialChildSize: 0.20,
              minChildSize: 0.12,
              maxChildSize: 0.70,
              expand: false,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      Container(
                        width: 45,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.grey,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Available Parkings',
                        style:
                            TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Divider(),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: _nearbyParkings.length,
                          itemBuilder: (_, i) {
                            final p = _nearbyParkings[i];
                            return ListTile(
                              title: Text(p.name),
                              subtitle: Text(
                                  '₹${p.pricePerHour}/hr • ${p.availableSlots} slots'),
                              onTap: () => _showParkingSheet(p),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}