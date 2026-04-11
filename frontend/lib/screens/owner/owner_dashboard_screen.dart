import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/parking.dart';
import 'add_parking_screen.dart';
import 'edit_parking_screen.dart';
import 'owner_park.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';

class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  late Future<Map<String, dynamic>> _parkingsFuture;
  late Future<Map<String, dynamic>> _earningsFuture;
  late Future<Map<String, dynamic>> _analyticsFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      // Use owner/my-parkings to get live available slot counts.
      _parkingsFuture = ApiService.getMyParkings();
      _earningsFuture = ApiService.getOwnerEarnings();
      _analyticsFuture = ApiService.getOwnerAnalytics();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh data when screen comes into focus
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Owner Dashboard'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'add') {
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AddParkingScreen(),
                  ),
                );
                if (result == true && mounted) {
                  _loadData();
                }
              } else if (value == 'logout') {
                final auth = Provider.of<AuthService>(context, listen: false);
                await auth.logout();

                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'add',
                child: Text('Add Parking Space'),
              ),
              PopupMenuItem(
                value: 'logout',
                child: Text('Logout'),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _loadData();
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- PARKINGS SECTION ---
              FutureBuilder<Map<String, dynamic>>(
                future: _parkingsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return _ErrorWidget(
                      message: snapshot.error.toString().replaceAll('Exception: ', ''),
                      onRetry: _loadData,
                    );
                  }

                  final data = snapshot.data;
                  if (data == null || data['success'] == false) {
                    return _ErrorWidget(
                      message: data?['message'] ?? 'Failed to load parkings',
                      onRetry: _loadData,
                    );
                  }

                  // Handle both response structures: data.parkings or data.data.parkings
                  final parkingsList = (data['data']?['parkings'] ?? data['parkings'] ?? []) as List;
                  final parkings = parkingsList
                      .map((p) {
                        try {
                          return Parking.fromJson(p);
                        } catch (e) {
                          return null;
                        }
                      })
                      .whereType<Parking>()
                      .toList();

                  if (parkings.isEmpty) {
                    return _EmptyParkingsWidget();
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'My Parkings',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 16),
                      ...parkings.map((parking) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _ParkingCard(
                              parking: parking,
                              onViewDetails: () {
                                if (parking.id.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Invalid parking ID'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  return;
                                }
                                Navigator.of(context)
                                    .push(
                                  MaterialPageRoute(
                                    builder: (_) => ParkingDetailsScreen(
                                      parkingId: parking.id,
                                    ),
                                  ),
                                )
                                    .then((_) {
                                  // Refresh data when returning from details screen
                                  _loadData();
                                });
                              },
                              onEditDetails: () {
                                if (parking.id.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Invalid parking ID'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  return;
                                }
                                Navigator.of(context)
                                    .push(
                                  MaterialPageRoute(
                                    builder: (_) => EditParkingScreen(
                                      parking: parking,
                                    ),
                                  ),
                                )
                                    .then((_) {
                                  // Refresh data when returning from edit screen
                                  _loadData();
                                });
                              },
                            ),
                          )),
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),
              
              // --- EARNINGS SECTION ---
              FutureBuilder<Map<String, dynamic>>(
                future: _earningsFuture,
                builder: (context, snapshot) {
                  double todayEarnings = 0;
                  double monthlyEarnings = 0;
                  double yearlyEarnings = 0;
                  List<dynamic> dailyEarnings = [];

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Earnings',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 16),
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      ],
                    );
                  }

                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Text(
                        'Error loading earnings: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  }

                  if (snapshot.hasData && snapshot.data != null) {
                    final data = snapshot.data!;
                    
                    // Dig down safely whether response is { data: {...} } or just { ... }
                    final earningsMap = (data['data'] is Map) ? data['data'] : data;
                    
                    todayEarnings = double.tryParse(earningsMap['today']?.toString() ?? '0') ?? 0.0;
                    monthlyEarnings = double.tryParse(earningsMap['monthly']?.toString() ?? '0') ?? 0.0;
                    yearlyEarnings = double.tryParse(earningsMap['yearly']?.toString() ?? '0') ?? 0.0;
                    dailyEarnings = (earningsMap['dailyEarnings'] as List?) ?? [];
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Earnings',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _SummaryCard(
                              title: 'Today',
                              value: '₹${todayEarnings.toStringAsFixed(0)}',
                              icon: Icons.today,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _SummaryCard(
                              title: 'This Month',
                              value: '₹${monthlyEarnings.toStringAsFixed(0)}',
                              icon: Icons.calendar_month,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _SummaryCard(
                        title: 'This Year',
                        value: '₹${yearlyEarnings.toStringAsFixed(0)}',
                        icon: Icons.calendar_today,
                        color: Colors.orange,
                      ),
                      if (dailyEarnings.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Text(
                          'Daily Earnings (Last 7 Days)',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 12),
                        _DailyEarningsChart(data: dailyEarnings),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),
              
              // --- BOOKINGS SECTION ---
              FutureBuilder<Map<String, dynamic>>(
                future: _analyticsFuture,
                builder: (context, snapshot) {
                  int todayBookings = 0;
                  int monthlyBookings = 0;
                  int yearlyBookings = 0;
                  List<dynamic> dailyBookings = [];

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bookings',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 16),
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      ],
                    );
                  }

                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Text(
                        'Error loading bookings: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  }

                  if (snapshot.hasData && snapshot.data != null) {
                    final data = snapshot.data!;
                    
                    // Dig down safely whether response is { data: {...} } or just { ... }
                    final bookingsMap = (data['data'] is Map) ? data['data'] : data;
                    
                    todayBookings = int.tryParse(bookingsMap['today']?.toString() ?? '0') ?? 0;
                    monthlyBookings = int.tryParse(bookingsMap['monthly']?.toString() ?? '0') ?? 0;
                    yearlyBookings = int.tryParse(bookingsMap['yearly']?.toString() ?? '0') ?? 0;
                    // Fallbacks for the chart list data keys
                    dailyBookings = (bookingsMap['dailyBookings'] as List?) ?? 
                                    (bookingsMap['bookingsPerDay'] as List?) ?? [];
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bookings',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _SummaryCard(
                              title: 'Today Booked',
                              value: todayBookings.toString(),
                              icon: Icons.book_online,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _SummaryCard(
                              title: 'Monthly Booked',
                              value: monthlyBookings.toString(),
                              icon: Icons.calendar_month,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _SummaryCard(
                        title: 'Yearly Booked',
                        value: yearlyBookings.toString(),
                        icon: Icons.calendar_today,
                        color: Colors.orange,
                      ),
                      if (dailyBookings.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Text(
                          'Daily Bookings (Last 7 Days)',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 12),
                        _BookingsChart(data: dailyBookings),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParkingCard extends StatelessWidget {
  final Parking parking;
  final VoidCallback onViewDetails;
  final VoidCallback onEditDetails;

  const _ParkingCard({
    required this.parking,
    required this.onViewDetails,
    required this.onEditDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onViewDetails,
        borderRadius: BorderRadius.circular(12),
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
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  if (parking.isVerified)
                    Chip(
                      label: const Text('Verified'),
                      backgroundColor: Colors.green[100],
                      labelStyle: const TextStyle(fontSize: 12),
                    )
                  else
                    Chip(
                      label: const Text('Pending'),
                      backgroundColor: Colors.orange[100],
                      labelStyle: const TextStyle(fontSize: 12),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                parking.address.fullAddress,
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _InfoChip(
                    icon: Icons.local_parking,
                    label: 'Total: ${parking.totalSlots}',
                  ),
                  const SizedBox(width: 12),
                  _InfoChip(
                    icon: Icons.check_circle,
                    label: 'Available: ${parking.availableSlots}',
                    color: parking.availableSlots > 0 ? Colors.green : Colors.red,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onViewDetails,
                      child: const Text('View Details'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onEditDetails,
                      child: const Text('Edit Parking details'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _InfoChip({
    required this.icon,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color ?? Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color ?? Colors.grey[700],
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
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

class _DailyEarningsChart extends StatelessWidget {
  final List<dynamic> data;

  const _DailyEarningsChart({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    final maxValue = data
        .map((e) => double.tryParse(e['earnings']?.toString() ?? '0') ?? 0.0)
        .reduce((a, b) => a > b ? a : b);

    if (maxValue == 0) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No earnings data available'),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ...data.map((item) {
              final date = item['date'] ?? '';
              final earnings = double.tryParse(item['earnings']?.toString() ?? '0') ?? 0.0;
              final height = maxValue > 0 ? (earnings / maxValue) * 100 : 0.0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 60,
                      child: Text(
                        date,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: height,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '₹${earnings.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _BookingsChart extends StatelessWidget {
  final List<dynamic> data;

  const _BookingsChart({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    final maxValue = data
        .map((e) => int.tryParse(e['count']?.toString() ?? '0') ?? 0)
        .reduce((a, b) => a > b ? a : b);

    if (maxValue == 0) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No bookings data available'),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ...data.map((item) {
              final date = item['date'] ?? '';
              final count = int.tryParse(item['count']?.toString() ?? '0') ?? 0;
              final height = maxValue > 0 ? (count / maxValue) * 100 : 0.0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 60,
                      child: Text(
                        date,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: height,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$count bookings',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _ErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorWidget({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
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
              message,
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyParkingsWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
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
                if (result == true && context.mounted) {
                  // Refresh will be handled by parent
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Parking Space'),
            ),
          ],
        ),
      ),
    );
  }
}