import 'dart:async';
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

const LatLng _defaultCenter = LatLng(20.5937, 78.9629); // India

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

  List<Parking> _parkings = [];
  Parking? _selectedParking;

  List<LatLng> _routePoints = [];
  bool _loadingRoute = false;

  LatLng _mapCenter = _defaultCenter;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  void dispose() {
    _posStream?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /* ================= LOCATION ================= */

  Future<void> _initLocation() async {
    final perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) return;

    final pos = await Geolocator.getCurrentPosition();
    _updateUserPosition(pos);

    _posStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5,
      ),
    ).listen(_updateUserPosition);
  }

  void _updateUserPosition(Position pos) {
    setState(() {
      _userPosition = pos;
      _mapCenter = LatLng(pos.latitude, pos.longitude);
    });

    _loadParkings();
  }

  /* ================= PARKINGS ================= */

  Future<void> _loadParkings() async {
    if (_userPosition == null) return;

    final res = await ApiService.getParkings(
      latitude: _mapCenter.latitude,
      longitude: _mapCenter.longitude,
      radius: 5000,
    );

    if (res['success']) {
      setState(() {
        _parkings = (res['data']['parkings'] as List)
            .map((e) => Parking.fromJson(e))
            .toList();
      });
    }
  }

  /* ================= SEARCH ================= */

  Future<void> _searchLocation(String query) async {
    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=1',
    );

    final res = await http.get(uri, headers: {
      'User-Agent': 'smart-parking-app',
    });

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

  /* ================= NAVIGATION ================= */

  Future<void> _getDirections(Parking parking) async {
    if (_userPosition == null) return;

    setState(() {
      _selectedParking = parking;
      _routePoints.clear();
      _loadingRoute = true;
    });

    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '${_userPosition!.longitude},${_userPosition!.latitude};'
      '${parking.location.longitude},${parking.location.latitude}'
      '?overview=full&geometries=geojson',
    );

    final res = await http.get(url);
    final data = jsonDecode(res.body);

    final coords = data['routes'][0]['geometry']['coordinates'];

    setState(() {
      _routePoints = coords
          .map<LatLng>((c) => LatLng(c[1].toDouble(), c[0].toDouble()))
          .toList();
      _loadingRoute = false;
    });
  }

  /* ================= BOTTOM SHEET ================= */

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
            Text(parking.name,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(parking.address.fullAddress),
            const SizedBox(height: 12),
            Text(
              '₹${parking.pricePerHour}/hr • '
              '${parking.availableSlots}/${parking.totalSlots} slots',
            ),
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
                          builder: (_) =>
                              ParkingDetailsScreen(parkingId: parking.id),
                        ),
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

  /* ================= BUILD ================= */

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

     body: Stack(
  children: [
    /* ================= MAP ================= */
    FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _mapCenter,
        initialZoom: 14,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.smartparking.app',
        ),

        if (_routePoints.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _routePoints,
                strokeWidth: 5,
                color: Colors.blue,
              ),
            ],
          ),

        MarkerLayer(
          markers: [
            if (_userPosition != null)
              Marker(
                point: LatLng(
                  _userPosition!.latitude,
                  _userPosition!.longitude,
                ),
                width: 20,
                height: 20,
                child: const Icon(
                  Icons.my_location,
                  color: Colors.blue,
                ),
              ),

            ..._parkings.map(
              (p) => Marker(
                point: LatLng(
                  p.location.latitude,
                  p.location.longitude,
                ),
                width: 50,
                height: 50,
                child: GestureDetector(
                  onTap: () => _showParkingSheet(p),
                  child: Image.asset('assets/icons/parking_pin.png'),
                ),
              ),
            ),
          ],
        ),
      ],
    ),

    /* ================= SEARCH BAR ================= */
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

    /* ================= BOTTOM DRAGGABLE PANEL ================= */
   Align(
  alignment: Alignment.bottomCenter,
  child: DraggableScrollableSheet(
    initialChildSize: 0.20,
    minChildSize: 0.12,
    maxChildSize: 0.70,
    expand: false,
    snap: true,
    snapSizes: const [0.20, 0.45, 0.70],
    builder: (context, scrollController) {
      return Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(blurRadius: 10, color: Colors.black26),
          ],
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),

            // ===== DRAG HANDLE (improved touch area) =====
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(
                  width: 45,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),

            const Text(
              'Available Parkings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),

            Expanded(
              child: ListView.builder(
                controller: scrollController,   // IMPORTANT
                itemCount: _parkings.length,
                itemBuilder: (_, i) {
                  final p = _parkings[i];
                  return ListTile(
                    leading: const Icon(Icons.local_parking),
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
)

  ],
),

    );
  }
}
