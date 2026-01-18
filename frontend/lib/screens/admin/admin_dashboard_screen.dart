import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentTab = 0;

  // Parking requests data
  List<dynamic> _parkingRequests = [];
  bool _loadingRequests = false;
  String? _requestsError;

  // Analytics data
  Map<String, dynamic>? _analytics;
  bool _loadingAnalytics = false;

  // Users data
  List<dynamic> _users = [];
  bool _loadingUsers = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _currentTab = _tabController.index;
        });
        _loadDataForTab(_tabController.index);
      }
    });
    _loadDataForTab(0);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDataForTab(int tabIndex) async {
    switch (tabIndex) {
      case 0: // Analytics
        _loadAnalytics();
        break;
      case 1: // Parking Requests
        _loadParkingRequests();
        break;
      case 2: // Users
        _loadUsers();
        break;
    }
  }

  Future<void> _loadParkingRequests() async {
    setState(() {
      _loadingRequests = true;
      _requestsError = null;
    });

    try {
      final response = await ApiService.getParkingRequests();
      if (response['success'] && response['data']?['parkings'] != null) {
        setState(() {
          _parkingRequests = response['data']['parkings'];
          _loadingRequests = false;
        });
      } else {
        setState(() {
          _requestsError = response['message'] ?? 'Failed to load requests';
          _loadingRequests = false;
        });
      }
    } catch (e) {
      setState(() {
        _requestsError = e.toString().replaceAll('Exception: ', '');
        _loadingRequests = false;
      });
    }
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _loadingAnalytics = true;
    });

    try {
      final response = await ApiService.getAdminAnalytics();
      if (response['success'] && response['data'] != null) {
        setState(() {
          _analytics = response['data'];
          _loadingAnalytics = false;
        });
      } else {
        setState(() {
          _loadingAnalytics = false;
        });
      }
    } catch (e) {
      setState(() {
        _loadingAnalytics = false;
      });
    }
  }

  Future<void> _loadUsers() async {
    setState(() {
      _loadingUsers = true;
    });

    try {
      final response = await ApiService.getAllUsers();
      if (response['success'] && response['data']?['users'] != null) {
        setState(() {
          _users = response['data']['users'];
          _loadingUsers = false;
        });
      } else {
        setState(() {
          _loadingUsers = false;
        });
      }
    } catch (e) {
      setState(() {
        _loadingUsers = false;
      });
    }
  }

  Future<void> _approveParking(String parkingId) async {
    try {
      final response = await ApiService.approveParkingRequest(parkingId);
      if (response['success']) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Parking approved successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _loadParkingRequests();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Failed to approve'),
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
    }
  }

  Future<void> _rejectParking(String parkingId) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Parking Request'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Rejection Reason (optional)',
            hintText: 'Enter reason for rejection',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final response = await ApiService.rejectParkingRequest(
          parkingId,
          reason: reasonController.text.trim().isEmpty
              ? null
              : reasonController.text.trim(),
        );
        if (response['success']) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Parking rejected successfully'),
                backgroundColor: Colors.orange,
              ),
            );
            _loadParkingRequests();
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(response['message'] ?? 'Failed to reject'),
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
      }
    }
  }

  Future<void> _logout() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    await authService.logout();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Analytics'),
            Tab(
              icon: Icon(Icons.pending_actions),
              text: 'Parking Requests',
            ),
            Tab(icon: Icon(Icons.people), text: 'Users'),
            Tab(icon: Icon(Icons.settings), text: 'Settings'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAnalyticsTab(),
          _buildParkingRequestsTab(),
          _buildUsersTab(),
          _buildSettingsTab(),
        ],
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    if (_loadingAnalytics) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_analytics == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Failed to load analytics'),
            ElevatedButton(
              onPressed: _loadAnalytics,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final totalIncome = _analytics!['totalIncome'] ?? 0.0;
    final totalBookings = _analytics!['totalBookings'] ?? 0;
    final totalParkingSpaces = _analytics!['totalParkingSpaces'] ?? 0;
    final totalUsers = _analytics!['totalUsers'] ?? 0;
    final totalOwners = _analytics!['totalOwners'] ?? 0;
    final incomeBreakdown = _analytics!['incomeBreakdown'] ?? [];

    return RefreshIndicator(
      onRefresh: _loadAnalytics,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Cards
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.5,
              children: [
                _buildStatCard('Total Income', '₹${totalIncome.toStringAsFixed(2)}',
                    Icons.account_balance_wallet, Colors.green),
                _buildStatCard('Total Bookings', totalBookings.toString(),
                    Icons.book_online, Colors.blue),
                _buildStatCard('Parking Spaces', totalParkingSpaces.toString(),
                    Icons.local_parking, Colors.orange),
                _buildStatCard('Total Users', '${totalUsers + totalOwners}',
                    Icons.people, Colors.purple),
              ],
            ),
            const SizedBox(height: 24),
            // Income per Owner
            const Text(
              'Income per Parking Owner',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (incomeBreakdown.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No income data available'),
                ),
              )
            else
              ...incomeBreakdown.map<Widget>((owner) => Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Text(owner['ownerName'] ?? 'Unknown'),
                      subtitle: Text(
                          '${owner['bookingsCount'] ?? 0} bookings • ${owner['ownerEmail'] ?? ''}'),
                      trailing: Text(
                        '₹${(owner['totalIncome'] ?? 0.0).toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParkingRequestsTab() {
    if (_loadingRequests) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_requestsError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(_requestsError!),
            ElevatedButton(
              onPressed: _loadParkingRequests,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_parkingRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline,
                size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No pending parking requests'),
            ElevatedButton(
              onPressed: _loadParkingRequests,
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadParkingRequests,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _parkingRequests.length,
        itemBuilder: (context, index) {
          final parking = _parkingRequests[index];
          final owner = parking['owner'] ?? {};
          final documents = parking['documents'] ?? {};
          final address = parking['address'] ?? {};

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: ExpansionTile(
              title: Text(parking['name'] ?? 'Unknown'),
              subtitle: Text(
                '${address['street'] ?? ''}, ${address['city'] ?? ''}',
              ),
              leading: const Icon(Icons.local_parking),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow('Owner', owner['name'] ?? 'Unknown'),
                      _buildDetailRow('Email', owner['email'] ?? 'N/A'),
                      _buildDetailRow('Phone', owner['phone'] ?? 'N/A'),
                      _buildDetailRow('Total Slots',
                          parking['totalSlots']?.toString() ?? '0'),
                      _buildDetailRow('Price/Hour',
                          '₹${parking['pricePerHour']?.toStringAsFixed(0) ?? '0'}/hr'),
                      if (documents['license']?.isNotEmpty == true)
                        _buildDocumentRow('License', documents['license']),
                      if (documents['idProof']?.isNotEmpty == true)
                        _buildDocumentRow('ID Proof', documents['idProof']),
                      if (documents['ownershipProof']?.isNotEmpty == true)
                        _buildDocumentRow(
                            'Ownership Proof', documents['ownershipProof']),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  _rejectParking(parking['_id'] ?? parking['id']),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                              child: const Text('Reject'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () =>
                                  _approveParking(parking['_id'] ?? parking['id']),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                              ),
                              child: const Text('Approve'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildDocumentRow(String label, String url) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () {
                // Open document URL
                // You can use url_launcher package to open URLs
              },
              child: Text(
                url,
                style: const TextStyle(color: Colors.blue),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersTab() {
    if (_loadingUsers) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No users found'),
            ElevatedButton(
              onPressed: _loadUsers,
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadUsers,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _users.length,
        itemBuilder: (context, index) {
          final user = _users[index];
          final bookingHistory = user['bookingHistory'] ?? [];
          final totalBookings = user['totalBookings'] ?? 0;
          final totalSpent = user['totalSpent'] ?? 0.0;

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: ExpansionTile(
              title: Text(user['name'] ?? 'Unknown'),
              subtitle: Text(user['email'] ?? ''),
              leading: const Icon(Icons.person),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow('Email', user['email'] ?? 'N/A'),
                      _buildDetailRow('Phone', user['phone'] ?? 'N/A'),
                      _buildDetailRow('Total Bookings', totalBookings.toString()),
                      _buildDetailRow(
                          'Total Spent', '₹${totalSpent.toStringAsFixed(2)}'),
                      const Divider(),
                      const Text(
                        'Booking History',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (bookingHistory.isEmpty)
                        const Text('No bookings yet')
                      else
                        ...bookingHistory.map<Widget>((booking) {
                          final parking = booking['parking'] ?? {};
                          final parkingName = parking['name'] ?? 'Unknown';
                          final totalPrice = booking['totalPrice'] ?? 0.0;
                          final status = booking['status'] ?? 'unknown';
                          final startTime = booking['startTime'] != null
                              ? DateTime.parse(booking['startTime']).toString()
                              : 'N/A';

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        parkingName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        startTime,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '₹${totalPrice.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Chip(
                                      label: Text(
                                        status.toUpperCase(),
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                      padding: EdgeInsets.zero,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSettingsTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.settings, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('Settings'),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _logout,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
