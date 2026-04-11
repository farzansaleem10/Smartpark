import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../models/parking.dart';

/// A full-screen Google-Maps-style navigation experience.
///
/// Two modes:
///   1. **Route Overview** – shows the full route, distance, time, and a Start button.
///   2. **Turn-by-Turn Navigation** – live GPS tracking, current step banner, speed.
class NavigationScreen extends StatefulWidget {
  final Parking parking;
  final Position userPosition;

  const NavigationScreen({
    super.key,
    required this.parking,
    required this.userPosition,
  });

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();

  // Route data
  List<LatLng> _routePoints = [];
  List<_RouteStep> _steps = [];
  double _totalDistanceMeters = 0;
  double _totalDurationSeconds = 0;
  bool _isLoadingRoute = true;
  String? _routeError;

  // Navigation state
  bool _isNavigating = false;
  int _currentStepIndex = 0;
  StreamSubscription<Position>? _posStream;
  LatLng? _livePosition;
  double _currentSpeedKmh = 0;
  double _currentBearing = 0;



  @override
  void initState() {
    super.initState();
    _livePosition = LatLng(
      widget.userPosition.latitude,
      widget.userPosition.longitude,
    );
    _fetchRoute();
  }

  @override
  void dispose() {
    _posStream?.cancel();
    super.dispose();
  }

  // ─── OSRM Route Fetch ────────────────────────────────────────────────

  Future<void> _fetchRoute() async {
    final startLat = widget.userPosition.latitude;
    final startLon = widget.userPosition.longitude;
    final endLat = widget.parking.location.latitude;
    final endLon = widget.parking.location.longitude;

    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '$startLon,$startLat;$endLon,$endLat'
      '?overview=full&geometries=geojson&steps=true',
    );

    try {
      final res = await http.get(url);
      if (res.statusCode != 200) {
        throw Exception('OSRM error: ${res.statusCode}');
      }

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final routes = body['routes'] as List? ?? [];
      if (routes.isEmpty) throw Exception('No routes found');

      final route = routes.first as Map<String, dynamic>;

      // Parse polyline
      final coords = route['geometry']['coordinates'] as List;
      final points = coords
          .map<LatLng>(
              (c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList();

      // Parse distance and duration
      final dist = (route['distance'] as num).toDouble();
      final dur = (route['duration'] as num).toDouble();

      // Parse steps from the first leg
      final legs = route['legs'] as List? ?? [];
      final List<_RouteStep> steps = [];
      if (legs.isNotEmpty) {
        final leg = legs.first as Map<String, dynamic>;
        final rawSteps = leg['steps'] as List? ?? [];
        for (final s in rawSteps) {
          final maneuver = s['maneuver'] as Map<String, dynamic>? ?? {};
          final location = maneuver['location'] as List? ?? [0, 0];
          steps.add(_RouteStep(
            instruction: s['name']?.toString() ?? '',
            maneuverType: maneuver['type']?.toString() ?? '',
            maneuverModifier: maneuver['modifier']?.toString() ?? '',
            distanceMeters: (s['distance'] as num?)?.toDouble() ?? 0,
            durationSeconds: (s['duration'] as num?)?.toDouble() ?? 0,
            location: LatLng(
              (location[1] as num).toDouble(),
              (location[0] as num).toDouble(),
            ),
          ));
        }
      }

      if (!mounted) return;
      setState(() {
        _routePoints = points;
        _totalDistanceMeters = dist;
        _totalDurationSeconds = dur;
        _steps = steps;
        _isLoadingRoute = false;
      });

      // Fit the map to the route bounds
      _fitRouteBounds();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _routeError = 'Failed to fetch route: $e';
        _isLoadingRoute = false;
      });
    }
  }

  void _fitRouteBounds() {
    if (_routePoints.isEmpty) return;

    double minLat = 90, maxLat = -90, minLon = 180, maxLon = -180;
    for (final p in _routePoints) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLon) minLon = p.longitude;
      if (p.longitude > maxLon) maxLon = p.longitude;
    }

    final bounds = LatLngBounds(
      LatLng(minLat, minLon),
      LatLng(maxLat, maxLon),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapController.fitBounds(
        bounds,
        options: const FitBoundsOptions(
          padding: EdgeInsets.fromLTRB(50, 160, 50, 280),
        ),
      );
    });
  }

  // ─── Navigation Start / Stop ──────────────────────────────────────────

  void _startNavigation() {
    setState(() {
      _isNavigating = true;
      _currentStepIndex = 0;
    });

    // Center on user
    if (_livePosition != null) {
      _mapController.move(_livePosition!, 17);
    }

    // Start live GPS tracking
    _posStream?.cancel();
    _posStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
      ),
    ).listen(_onPositionUpdate);
  }

  void _stopNavigation() {
    _posStream?.cancel();
    setState(() {
      _isNavigating = false;
    });
    Navigator.of(context).pop();
  }

  void _onPositionUpdate(Position pos) {
    if (!mounted) return;

    final newPos = LatLng(pos.latitude, pos.longitude);
    final speedKmh =
        pos.speed >= 0 ? pos.speed * 3.6 : 0.0; // m/s -> km/h
    final bearing = pos.heading;

    setState(() {
      _livePosition = newPos;
      _currentSpeedKmh = speedKmh;
      _currentBearing = bearing;
    });

    // Auto-advance steps
    _advanceStepIfNeeded(newPos);

    // Follow the user
    _mapController.move(newPos, 17);
  }

  void _advanceStepIfNeeded(LatLng userPos) {
    if (_currentStepIndex >= _steps.length - 1) return;

    final nextStep = _steps[_currentStepIndex + 1];
    const dist = Distance();
    final metersToNext = dist(userPos, nextStep.location);

    // If within 30m of the next step's maneuver point, advance
    if (metersToNext < 30) {
      setState(() {
        _currentStepIndex++;
      });
    }
  }

  // ─── Formatting helpers ───────────────────────────────────────────────

  String _formatDuration(double seconds) {
    final totalMin = (seconds / 60).round();
    if (totalMin < 60) return '$totalMin min';
    final h = totalMin ~/ 60;
    final m = totalMin % 60;
    if (m == 0) return '$h hr';
    return '$h hr $m';
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    final km = meters / 1000;
    return '${km.toStringAsFixed(1)} km';
  }

  IconData _maneuverIcon(String type, String modifier) {
    switch (type) {
      case 'turn':
        if (modifier.contains('left')) return Icons.turn_left;
        if (modifier.contains('right')) return Icons.turn_right;
        return Icons.straight;
      case 'new name':
      case 'continue':
        return Icons.straight;
      case 'merge':
        return Icons.merge;
      case 'fork':
        if (modifier.contains('left')) return Icons.fork_left;
        if (modifier.contains('right')) return Icons.fork_right;
        return Icons.fork_right;
      case 'roundabout':
      case 'rotary':
        return Icons.roundabout_right;
      case 'depart':
        return Icons.navigation;
      case 'arrive':
        return Icons.flag;
      case 'end of road':
        if (modifier.contains('left')) return Icons.turn_left;
        if (modifier.contains('right')) return Icons.turn_right;
        return Icons.straight;
      default:
        return Icons.arrow_upward;
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoadingRoute) {
      return Scaffold(
        backgroundColor: Colors.grey[100],
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFF1A73E8)),
              SizedBox(height: 16),
              Text('Finding best route…',
                  style: TextStyle(fontSize: 16, color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    if (_routeError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Directions')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(_routeError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return _isNavigating ? _buildNavigationMode() : _buildOverviewMode();
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  MODE 1: Route Overview
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildOverviewMode() {
    final destLatLng = LatLng(
      widget.parking.location.latitude,
      widget.parking.location.longitude,
    );

    return Scaffold(
      body: Stack(
        children: [
          // ── Map ──
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _livePosition ?? destLatLng,
              initialZoom: 14,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.smartparking.app',
              ),
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 6,
                      color: const Color(0xFF4285F4),
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  // User location marker
                  if (_livePosition != null)
                    Marker(
                      point: _livePosition!,
                      width: 24,
                      height: 24,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF4285F4),
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Destination marker
                  Marker(
                    point: destLatLng,
                    width: 40,
                    height: 40,
                    child: const Icon(
                      Icons.location_on,
                      color: Color(0xFFEA4335),
                      size: 40,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // ── Top: Origin / Destination Card ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            right: 12,
            child: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(14),
              shadowColor: Colors.black.withOpacity(0.15),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    // Back button
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.arrow_back,
                          color: Colors.black87, size: 24),
                    ),
                    const SizedBox(width: 14),
                    // Origin / Destination dots and text
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF4285F4),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Your location',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Column(
                              children: List.generate(
                                3,
                                (_) => Container(
                                  width: 2,
                                  height: 4,
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 1),
                                  color: Colors.grey[400],
                                ),
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFEA4335),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  widget.parking.name,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Swap icon
                    Icon(Icons.swap_vert, color: Colors.grey[600]),
                  ],
                ),
              ),
            ),
          ),

          // ── Time badge on the route (mid-point) ──
          if (_routePoints.length > 2)
            _buildTimeBadgeOnMap(),

          // ── Bottom Panel: Drive info + Start button ──
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle bar
                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    // "Drive" header row
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                      child: Row(
                        children: [
                          const Text(
                            'Drive',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          const Spacer(),
                          // IconButton(
                          //   icon: const Icon(Icons.tune, size: 22),
                          //   onPressed: () {},
                          //   color: Colors.grey[700],
                          // ),
                          // IconButton(
                          //   icon: const Icon(Icons.share, size: 22),
                          //   onPressed: () {},
                          //   color: Colors.grey[700],
                          // ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 22),
                            onPressed: () => Navigator.pop(context),
                            color: Colors.grey[700],
                          ),
                        ],
                      ),
                    ),

                    // Car mode indicator
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                      child: Row(
                        children: [
                          const Icon(Icons.directions_car,
                              color: Color(0xFF1A73E8), size: 22),
                          const SizedBox(width: 8),
                          Text(
                            _formatDuration(_totalDurationSeconds),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A73E8),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            height: 3,
                            width: 50,
                            margin: const EdgeInsets.only(top: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A73E8),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Divider(height: 20),

                    // Duration and distance
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            _formatDuration(_totalDurationSeconds),
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A73E8),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '(${_formatDistance(_totalDistanceMeters)})',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF1A73E8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Fastest route now',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ),

                    // Start + Add stops + Share row
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Row(
                        children: [
                          // Start button
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: _startNavigation,
                              icon: const Icon(Icons.navigation,
                                  color: Colors.white, size: 20),
                              label: const Text(
                                'Start',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w700),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1A73E8),
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                elevation: 2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Add stops
                          // Expanded(
                          //   flex: 2,
                          //   child: OutlinedButton.icon(
                          //     onPressed: () {},
                          //     icon: Icon(Icons.add_location_alt,
                          //         size: 18, color: Colors.grey[700]),
                          //     label: Text(
                          //       'Add stops',
                          //       style: TextStyle(
                          //         fontSize: 14,
                          //         fontWeight: FontWeight.w600,
                          //         color: Colors.grey[700],
                          //       ),
                          //     ),
                          //     style: OutlinedButton.styleFrom(
                          //       padding:
                          //           const EdgeInsets.symmetric(vertical: 14),
                          //       shape: RoundedRectangleBorder(
                          //         borderRadius: BorderRadius.circular(24),
                          //       ),
                          //       side: BorderSide(color: Colors.grey[300]!),
                          //     ),
                          //   ),
                          // ),
                          const SizedBox(width: 10),
                          // Share button
                          // OutlinedButton.icon(
                          //   onPressed: () {},
                          //   icon: Icon(Icons.share,
                          //       size: 18, color: Colors.grey[700]),
                          //   label: Text(
                          //     'Share',
                          //     style: TextStyle(
                          //       fontSize: 14,
                          //       fontWeight: FontWeight.w600,
                          //       color: Colors.grey[700],
                          //     ),
                          //   ),
                          //   style: OutlinedButton.styleFrom(
                          //     padding: const EdgeInsets.symmetric(
                          //         vertical: 14, horizontal: 12),
                          //     shape: RoundedRectangleBorder(
                          //       borderRadius: BorderRadius.circular(24),
                          //     ),
                          //     side: BorderSide(color: Colors.grey[300]!),
                          //   ),
                          // ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildTimeBadgeOnMap() {
    // We don't position a badge on the map since flutter_map doesn't easily
    // support floating overlays tied to geo coordinates. Instead, we show
    // a floating chip near the route center on-screen.
    return const SizedBox.shrink();
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  MODE 2: Turn-by-Turn Navigation
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildNavigationMode() {
    final currentStep =
        _steps.isNotEmpty && _currentStepIndex < _steps.length
            ? _steps[_currentStepIndex]
            : null;

    final destLatLng = LatLng(
      widget.parking.location.latitude,
      widget.parking.location.longitude,
    );

    // Calculate remaining distance & time
    double remainingDist = 0;
    double remainingTime = 0;
    for (int i = _currentStepIndex; i < _steps.length; i++) {
      remainingDist += _steps[i].distanceMeters;
      remainingTime += _steps[i].durationSeconds;
    }

    return Scaffold(
      body: Stack(
        children: [
          // ── Map ──
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _livePosition ?? destLatLng,
              initialZoom: 17,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.smartparking.app',
              ),
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 7,
                      color: const Color(0xFF4285F4),
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  // User's live position – navigation arrow
                  if (_livePosition != null)
                    Marker(
                      point: _livePosition!,
                      width: 50,
                      height: 50,
                      child: Transform.rotate(
                        angle: _currentBearing * (pi / 180),
                        child: const Icon(
                          Icons.navigation,
                          color: Color(0xFF4285F4),
                          size: 36,
                        ),
                      ),
                    ),
                  // Destination
                  Marker(
                    point: destLatLng,
                    width: 40,
                    height: 40,
                    child: const Icon(
                      Icons.location_on,
                      color: Color(0xFFEA4335),
                      size: 40,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // ── Top: Direction Banner (green) ──
          if (currentStep != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                color: const Color(0xFF0F9D58),
                padding: EdgeInsets.fromLTRB(
                  20,
                  MediaQuery.of(context).padding.top + 12,
                  20,
                  16,
                ),
                child: Row(
                  children: [
                    Icon(
                      _maneuverIcon(
                          currentStep.maneuverType, currentStep.maneuverModifier),
                      color: Colors.white,
                      size: 40,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentStep.instruction.isNotEmpty
                                ? currentStep.instruction
                                : 'Continue on the road',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatDistance(currentStep.distanceMeters),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Microphone icon (decorative)
                    // Container(
                    //   width: 44,
                    //   height: 44,
                    //   decoration: BoxDecoration(
                    //     color: Colors.white.withOpacity(0.2),
                    //     shape: BoxShape.circle,
                    //   ),
                    //   // child: const Icon(
                    //   //   Icons.mic,
                    //   //   color: Colors.white,
                    //   //   size: 24,
                    //   // ),
                    // ),
                  ],
                ),
              ),
            ),

          // ── Speed indicator (bottom-left) ──
          Positioned(
            bottom: 100,
            left: 16,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _currentSpeedKmh > 0
                        ? _currentSpeedKmh.round().toString()
                        : '--',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                  const Text(
                    'km/h',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Right side action buttons ──
          // Positioned(
          //   bottom: 110,
          //   right: 16,
          //   child: Column(
          //     children: [
          //       _buildActionCircle(Icons.search, () {}),
          //       const SizedBox(height: 10),
          //       _buildActionCircle(Icons.volume_up, () {}),
          //     ],
          //   ),
          // ),

          // ── Bottom: Remaining info + Dismiss ──
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(18)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Remaining time and distance
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: Color(0xFFEA4335),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${_formatDuration(remainingTime)} · ${_formatDistance(remainingDist)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          // ETA
                          Text(
                            'ETA ${_calculateEta(remainingTime)}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // Dismiss button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _stopNavigation,
                          icon: const Icon(Icons.close,
                              color: Colors.white, size: 20),
                          label: const Text(
                            'Dismiss',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00897B),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            elevation: 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCircle(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.grey[700], size: 22),
      ),
    );
  }

  String _calculateEta(double remainingSeconds) {
    final now = DateTime.now();
    final eta = now.add(Duration(seconds: remainingSeconds.round()));
    final hour = eta.hour;
    final minute = eta.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final h12 = hour == 0
        ? 12
        : hour > 12
            ? hour - 12
            : hour;
    return '$h12:$minute $period';
  }
}

// ─── Route Step Model ────────────────────────────────────────────────────

class _RouteStep {
  final String instruction;
  final String maneuverType;
  final String maneuverModifier;
  final double distanceMeters;
  final double durationSeconds;
  final LatLng location;

  const _RouteStep({
    required this.instruction,
    required this.maneuverType,
    required this.maneuverModifier,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.location,
  });
}
