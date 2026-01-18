import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../models/parking.dart';
import '../auth/login_screen.dart';
import '../parking/parking_details_screen.dart';
import '../owner/owner_dashboard_screen.dart';
import '../admin/admin_dashboard_screen.dart';
import '../bookings/booking_history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Parking> _parkings = [];
  bool _isLoading = true;
  String? _error;
  Position? _currentPosition;
  final _searchController = TextEditingController();
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  LatLng? _centerLocation;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _error = 'Location services are disabled';
          _isLoading = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _error = 'Location permissions are denied';
            _isLoading = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _error = 'Location permissions are permanently denied';
          _isLoading = false;
        });
        return;
      }

      _currentPosition = await Geolocator.getCurrentPosition();
      if (_currentPosition != null) {
        setState(() {
          _centerLocation = LatLng(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          );
        });
        _loadParkings();
      }
    } catch (e) {
      setState(() {
        _error = 'Error getting location: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadParkings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await ApiService.getParkings(
        latitude: _centerLocation?.latitude ?? _currentPosition?.latitude,
        longitude: _centerLocation?.longitude ?? _currentPosition?.longitude,
        radius: 5000,
      );

      if (response['success'] && response['data']?['parkings'] != null) {
        setState(() {
          _parkings = (response['data']['parkings'] as List)
              .map((p) => Parking.fromJson(p))
              .toList();
          _isLoading = false;
        });
        _updateMarkers();
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

  void _updateMarkers() {
    final markers = <Marker>{};

    for (var parking in _parkings) {
      final markerId = MarkerId(parking.id);
      markers.add(
        Marker(
          markerId: markerId,
          position: LatLng(
            parking.location.latitude,
            parking.location.longitude,
          ),
          
          onTap: () => _showParkingBottomSheet(parking),
        ),
      );
    }

    setState(() {
      _markers = markers;
    });
  }

  void _showParkingBottomSheet(Parking parking) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          parking.name,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          parking.address.fullAddress,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.local_parking, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${parking.availableSlots}/${parking.totalSlots} slots available',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const Spacer(),
                  Text(
                    '₹${parking.pricePerHour.toStringAsFixed(0)}/hr',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ],
              ),
              if (parking.rating.average > 0) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.star, size: 16, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      '${parking.rating.average.toStringAsFixed(1)} (${parking.rating.count})',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
    Navigator.of(context).push(
      MaterialPageRoute(
                        builder: (_) => ParkingDetailsScreen(
                          parkingId: parking.id,
                        ),
                      ),
                    );
                  },
                  child: const Text('View Details'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSearch() async {
    final query = _searchController.text.trim();
    
    if (query.isEmpty) {
      if (_currentPosition != null) {
        setState(() {
          _centerLocation = LatLng(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          );
        });
        _moveCameraToLocation(_centerLocation!);
        _loadParkings();
      }
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      List<geo.Location> locations = await geo.locationFromAddress(query);
      if (locations.isNotEmpty) {
        final location = locations.first;
        final latLng = LatLng(location.latitude, location.longitude);
        
        setState(() {
          _centerLocation = latLng;
        });
        
        _moveCameraToLocation(latLng);
        _loadParkings();
      } else {
        setState(() {
          _error = 'Location not found';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error searching location: $e';
      });
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  void _moveCameraToLocation(LatLng location) {
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(location, 14.0),
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (_centerLocation != null) {
      _moveCameraToLocation(_centerLocation!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Parking'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadParkings,
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              if (user?.role == 'owner')
                const PopupMenuItem(
                  value: 'owner',
                  child: Row(
                    children: [
                      Icon(Icons.dashboard),
                      SizedBox(width: 8),
                      Text('Owner Dashboard'),
                    ],
                  ),
                ),
              if (user?.role == 'admin')
                const PopupMenuItem(
                  value: 'admin',
                  child: Row(
                    children: [
                      Icon(Icons.admin_panel_settings),
                      SizedBox(width: 8),
                      Text('Admin Dashboard'),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'history',
                child: Row(
                  children: [
                    Icon(Icons.history),
                    SizedBox(width: 8),
                    Text('Booking History'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
            onSelected: (value) async {
              if (value == 'owner') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const OwnerDashboardScreen()),
                );
              } else if (value == 'admin') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
                );
              } else if (value == 'history') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const BookingHistoryScreen()),
                );
              } else if (value == 'logout') {
                await authService.logout();
                if (mounted) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by location...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                if (_currentPosition != null) {
                                  setState(() {
                                    _centerLocation = LatLng(
                                      _currentPosition!.latitude,
                                      _currentPosition!.longitude,
                                    );
                                  });
                                  _moveCameraToLocation(_centerLocation!);
                                _loadParkings();
                                }
                              },
                            )
                          : null,
                    ),
                    onSubmitted: (_) => _handleSearch(),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: _isSearching
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                  onPressed: _isSearching ? null : _handleSearch,
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
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
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadParkings,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _centerLocation == null
                        ? const Center(
                            child: Text('Waiting for location...'),
                          )
                        : GoogleMap(
                            onMapCreated: _onMapCreated,
                            initialCameraPosition: CameraPosition(
                              target: _centerLocation!,
                              zoom: 14.0,
                            ),
                            markers: _markers,
                            myLocationEnabled: true,
                            myLocationButtonEnabled: true,
                            mapType: MapType.normal,
                          ),
          ),
        ],
      ),
    );
  }
}
