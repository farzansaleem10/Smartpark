import 'dart:async';
import 'dart:convert';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';



class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  StreamSubscription<Position>? _positionSub;
  Position? _userPosition;
  bool _isLocating = true;
  String? _locationError;

  LatLng? _cameraCenter;
  bool _hasCenteredOnce = false;

  _ParkingSpot? _selectedParking;
  List<LatLng> _routeLine = const [];
  bool _isFetchingRoute = false;
  String? _routeError;

  late List<_ParkingSpot> _allParkings;
  List<_ParkingSpot> _visibleParkings = [];

  @override
void initState() {
  super.initState();
  
  _allParkings = _buildMockParkings();
  _initLocation();
}

  @override
  void dispose() {
    _positionSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initLocation() async {
    setState(() {
      _isLocating = true;
      _locationError = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationError = 'Location services are disabled';
          _isLocating = false;
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        setState(() {
          _locationError = 'Location permissions are denied';
          _isLocating = false;
        });
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationError = 'Location permissions are permanently denied';
          _isLocating = false;
        });
        return;
      }

      final initial = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
      _onNewUserPosition(initial);

      _positionSub?.cancel();
      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 10,
        ),
      ).listen(
        _onNewUserPosition,
        onError: (e) {
          if (!mounted) return;
          setState(() {
            _locationError = 'Live location error: $e';
          });
        },
      );

      if (mounted) {
        setState(() {
          _isLocating = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _locationError = 'Error getting location: $e';
        _isLocating = false;
      });
    }
  }

  void _onNewUserPosition(Position pos) {
    final ll = LatLng(pos.latitude, pos.longitude);
    if (!mounted) return;
    setState(() {
      _userPosition = pos;
      _cameraCenter ??= ll;
    });

    if (!_hasCenteredOnce) {
      _hasCenteredOnce = true;
      _setCamera(ll, zoom: 16.0);
      _filterParkingsAround(ll);
    }
  }

  void _setCamera(LatLng target, {double zoom = 16.0}) {
    _cameraCenter = target;
    _mapController.move(target, zoom);
  }

  List<_ParkingSpot> _buildMockParkings() {
  final LatLng base =
      _userLatLng ?? const LatLng(20.5937, 78.9629); // India center fallback

  return [
    _ParkingSpot(
      id: 'p1',
      name: 'Nearby Parking A',
      location: LatLng(base.latitude + 0.002, base.longitude + 0.001),
      available: true,
    ),
    _ParkingSpot(
      id: 'p2',
      name: 'Nearby Parking B',
      location: LatLng(base.latitude - 0.0015, base.longitude - 0.002),
      available: false,
    ),
    _ParkingSpot(
      id: 'p3',
      name: 'Nearby Parking C',
      location: LatLng(base.latitude + 0.003, base.longitude - 0.001),
      available: true,
    ),
  ];
}


  Future<LatLng?> searchIndiaLocation(String query) async {
  final url = Uri.parse(
    'https://nominatim.openstreetmap.org/search'
    '?q=$query'
    '&country=India'
    '&format=json'
    '&addressdetails=1'
    '&limit=1',
  );

  final response = await http.get(
    url,
    headers: {
      'User-Agent': 'smart-parking-app', // REQUIRED
    },
  );

  if (response.statusCode != 200) return null;

  final data = json.decode(response.body) as List;
  if (data.isEmpty) return null;

  final lat = double.parse(data[0]['lat']);
  final lon = double.parse(data[0]['lon']);
  return LatLng(lat, lon);
}


  void _filterParkingsAround(LatLng center) {
    const double radiusMeters = 2000;
    const distance = Distance();
    final visible = _allParkings.where((p) {
      final meters = distance(center, p.location);
      return meters <= radiusMeters;
    }).toList();

    if (!mounted) return;
    setState(() {
      _visibleParkings = visible;
    });
  }

  void _onTapParking(_ParkingSpot parking) {
    setState(() {
      _selectedParking = parking;
      _routeLine = const [];
      _routeError = null;
    });
    _setCamera(parking.location, zoom: 17.8);
    _showParkingSheet(parking);
  }

  void _showParkingSheet(_ParkingSpot parking) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        parking.name,
                        style: Theme.of(ctx)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    _AvailabilityPill(available: parking.available),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  parking.available ? 'Spaces available' : 'No spaces available',
                  style: TextStyle(color: Colors.grey[700]),
                ),
                if (_routeError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _routeError!,
                    style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: parking.available ? () {} : null,
                        child: const Text('Book Now'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isFetchingRoute ? null : () => _navigateTo(parking),
                        child: _isFetchingRoute
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Navigate'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _navigateTo(_ParkingSpot parking) async {
    final user = _userPosition;
    if (user == null) {
      setState(() {
        _routeError = 'User location not available yet';
      });
      return;
    }

    setState(() {
      _isFetchingRoute = true;
      _routeError = null;
    });

    try {
      final route = await _fetchOsrmRoute(
        user: LatLng(user.latitude, user.longitude),
        dest: parking.location,
      );
      if (!mounted) return;
      setState(() {
        _routeLine = route;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _routeError = 'Failed to fetch route: $e';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isFetchingRoute = false;
      });
    }
  }

  Future<List<LatLng>> _fetchOsrmRoute({
    required LatLng user,
    required LatLng dest,
  }) async {
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '${user.longitude},${user.latitude};${dest.longitude},${dest.latitude}'
      '?overview=full&geometries=geojson',
    );

    final resp = await http.get(url);
    if (resp.statusCode != 200) {
      throw Exception('OSRM error: ${resp.statusCode}');
    }

    final jsonBody = json.decode(resp.body) as Map<String, dynamic>;
    final routes = (jsonBody['routes'] as List?) ?? const [];
    if (routes.isEmpty) {
      return const [];
    }

    final geometry = routes.first['geometry'] as Map<String, dynamic>?;
    final coords = (geometry?['coordinates'] as List?) ?? const [];
    return coords
        .map((c) {
          final pair = c as List;
          final lng = (pair[0] as num).toDouble();
          final lat = (pair[1] as num).toDouble();
          return LatLng(lat, lng);
        })
        .toList(growable: false);
  }

 Future<void> _onSubmitSearch(String text) async {
  final query = text.trim();
  if (query.isEmpty) return;

  final result = await searchIndiaLocation(query);

  if (result == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Location not found in India')),
    );
    return;
  }

  _setCamera(result, zoom: 16.0);
  _filterParkingsAround(result);
}

  LatLng? get _userLatLng =>
      _userPosition == null ? null : LatLng(_userPosition!.latitude, _userPosition!.longitude);

  @override
  Widget build(BuildContext context) {

    final center = _cameraCenter ?? _userLatLng ?? const LatLng(28.6139, 77.2090);
    final showEmpty = !_isLocating && _locationError == null && _visibleParkings.isEmpty;

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 15.8,
              minZoom: 3,
              maxZoom: 19,
              onPositionChanged: (pos, _) {
                final c = pos.center;
                if (c != null) {
                  _cameraCenter = c;
                }
              },
            ),
            children: [
              TileLayer(
  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  userAgentPackageName: 'com.smartparking.app',
),
              if (_routeLine.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routeLine,
                      strokeWidth: 5,
                      color: const Color(0xFF2E7DFF),
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (_userLatLng != null)
                    Marker(
                      point: _userLatLng!,
                      width: 22,
                      height: 22,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E7DFF),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ..._visibleParkings.map(
                    (p) => Marker(
                      point: p.location,
                      width: 44,
                      height: 44,
                      child: GestureDetector(
                        onTap: () => _onTapParking(p),
                        child: _ParkingMarker(available: p.available, selected: _selectedParking?.id == p.id),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: Column(
              children: [
                _SearchBar(
                  controller: _searchController,
                  onSubmitted: _onSubmitSearch,
                  onClear: () {
                    _searchController.clear();
                    final user = _userLatLng;
                    if (user != null) {
                      _setCamera(user, zoom: 16.0);
                      _filterParkingsAround(user);
                    }
                  },
                ),
                
                if (_locationError != null) ...[
                  const SizedBox(height: 10),
                  _Banner(message: _locationError!, tone: _BannerTone.error),
                ],
                if (_isLocating) ...[
                  const SizedBox(height: 10),
                  const _Banner(message: 'Getting your location…', tone: _BannerTone.info),
                ],
              ],
            ),
          ),
          if (showEmpty)
            Positioned(
              bottom: 22,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Text(
                  'No parking available here',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: (_userLatLng == null)
          ? null
          : FloatingActionButton(
              onPressed: () {
                final user = _userLatLng!;
                _setCamera(user, zoom: 16.0);
                _filterParkingsAround(user);
              },
              child: const Icon(Icons.my_location),
            ),
    );
  }
}

class _ParkingSpot {
  final String id;
  final String name;
  final LatLng location;
  final bool available;

  const _ParkingSpot({
    required this.id,
    required this.name,
    required this.location,
    required this.available,
  });
}

class _ParkingMarker extends StatelessWidget {
  final bool available;
  final bool selected;

  const _ParkingMarker({
    required this.available,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final color = available ? const Color(0xFF19C37D) : const Color(0xFFE5484D);
    final border = selected ? const Color(0xFF111827) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: border, width: selected ? 3 : 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.22),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: const Icon(Icons.local_parking, color: Colors.white, size: 22),
    );
  }
}

class _AvailabilityPill extends StatelessWidget {
  final bool available;
  const _AvailabilityPill({required this.available});

  @override
  Widget build(BuildContext context) {
    final bg = available ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2);
    final fg = available ? const Color(0xFF166534) : const Color(0xFF991B1B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        available ? 'Available' : 'Full',
        style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  const _SearchBar({
    required this.controller,
    required this.onSubmitted,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      shadowColor: Colors.black.withOpacity(0.12),
      borderRadius: BorderRadius.circular(14),
      child: TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          hintText: 'Search a location',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  onPressed: onClear,
                  icon: const Icon(Icons.clear),
                ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(
            borderSide: BorderSide.none,
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onChanged: (_) {
          (context as Element).markNeedsBuild();
        },
      ),
    );
  }
}

enum _BannerTone { info, error }

class _Banner extends StatelessWidget {
  final String message;
  final _BannerTone tone;
  const _Banner({required this.message, required this.tone});

  @override
  Widget build(BuildContext context) {
    final bg = tone == _BannerTone.error ? const Color(0xFFFEF2F2) : const Color(0xFFEFF6FF);
    final fg = tone == _BannerTone.error ? const Color(0xFF991B1B) : const Color(0xFF1E40AF);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withOpacity(0.25)),
      ),
      child: Text(
        message,
        style: TextStyle(color: fg, fontWeight: FontWeight.w600),
        textAlign: TextAlign.center,
      ),
    );
  }
}
