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

  // Data States
  List<dynamic> _parkingRequests = [];
  Map<String, dynamic>? _analytics;
  List<dynamic> _allUsers = []; // Combined list from API
  
  bool _loadingRequests = false;
  bool _loadingAnalytics = false;
  bool _loadingUsers = false;
  String? _requestsError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
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
      case 0: _loadAnalytics(); break;
      case 1: _loadParkingRequests(); break;
      case 2: _loadUsers(); break;
    }
  }

  // --- API Methods ---

  Future<void> _loadAnalytics() async {
    setState(() => _loadingAnalytics = true);
    try {
      final response = await ApiService.getAdminAnalytics();
      if (response['success']) {
        setState(() => _analytics = response['data']);
      }
    } catch (e) {
      debugPrint("Analytics Error: $e");
    } finally {
      setState(() => _loadingAnalytics = false);
    }
  }

  Future<void> _loadUsers() async {
    setState(() => _loadingUsers = true);
    try {
      final response = await ApiService.getAllUsers();
      if (response['success'] && response['data']?['users'] != null) {
        setState(() => _allUsers = response['data']['users']);
      }
    } catch (e) {
      debugPrint("Users Error: $e");
    } finally {
      setState(() => _loadingUsers = false);
    }
  }

  Future<void> _toggleUserStatus(String userId, bool isCurrentlyActive) async {
    final action = isCurrentlyActive ? 'Deactivate' : 'Activate';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$action Account'),
        content: Text('Are you sure you want to $action this user\'s credentials?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: isCurrentlyActive ? Colors.red : Colors.green),
            child: Text(action),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Assuming your ApiService has a toggle/update method
        final response = await ApiService.updateUserStatus(userId, !isCurrentlyActive);
        if (response['success']) {
          _loadUsers();
          _showSnackBar('User status updated successfully', Colors.green);
        }
      } catch (e) {
        _showSnackBar(e.toString(), Colors.red);
      }
    }
  }

  // --- UI Helpers ---

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
            Tab(icon: Icon(Icons.pending_actions), text: 'Requests'),
            Tab(icon: Icon(Icons.people), text: 'User Management'),
            Tab(icon: Icon(Icons.settings), text: 'Settings'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAnalyticsTab(),
          _buildParkingRequestsTab(),
          _buildUsersManagementTab(),
          _buildSettingsTab(),
        ],
      ),
    );
  }

  // --- 1. FIXED ANALYTICS TAB ---
  Widget _buildAnalyticsTab() {
    if (_loadingAnalytics) return const Center(child: CircularProgressIndicator());
    if (_analytics == null) return _buildRetryButton(_loadAnalytics);

    final incomeBreakdown = _analytics!['incomeBreakdown'] as List? ?? [];

    return RefreshIndicator(
      onRefresh: _loadAnalytics,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryGrid(),
            const SizedBox(height: 24),
            const Text('Income per Parking Owner', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            // Updated mapping to ensure all owners from the list are rendered
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: incomeBreakdown.length,
              itemBuilder: (context, index) {
                final owner = incomeBreakdown[index];
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person_pin)),
                    title: Text(owner['ownerName'] ?? 'Unknown Owner'),
                    subtitle: Text('${owner['bookingsCount'] ?? 0} bookings'),
                    trailing: Text(
                      '₹${(owner['totalIncome'] ?? 0.0).toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- 2. UPDATED USER TAB (SEGMENTED) ---
 Widget _buildUsersManagementTab() {
    // 1. Filter for Customers
    final customers = _allUsers.where((u) {
      final role = (u['role'] ?? '').toString().toLowerCase().trim();
      return role == 'user' || role == 'customer';
    }).toList();

    // 2. Filter for Owners 
    final owners = _allUsers.where((u) {
      final role = (u['role'] ?? '').toString().toLowerCase().trim();
      return role == 'owner';
    }).toList();

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue,
            tabs: [
              Tab(text: "Customers"),
              Tab(text: "Owners"),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildUserList(customers),
                _buildUserList(owners),
              ],
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildUserList(List<dynamic> users) {
    if (users.isEmpty) return const Center(child: Text("No accounts found in this category"));
    
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        final bool isActive = user['isActive'] ?? true; // Adjust key based on your backend

        return Card(
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: isActive ? Colors.blue : Colors.grey,
              child: Text(user['name']?[0] ?? 'U'),
            ),
            title: Text(user['name'] ?? 'Unknown'),
            subtitle: Text(user['email'] ?? ''),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildDetailRow('Phone', user['phone'] ?? 'N/A'),
                    _buildDetailRow('Account Status', isActive ? 'Active' : 'Deactivated'),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () => _toggleUserStatus(user['_id'], isActive),
                          icon: Icon(isActive ? Icons.block : Icons.check_circle, color: isActive ? Colors.red : Colors.green),
                          label: Text(isActive ? 'Deactivate Credential' : 'Activate Account', 
                            style: TextStyle(color: isActive ? Colors.red : Colors.green)),
                        ),
                      ],
                    )
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }

  // --- Existing Logic Retained ---

  Widget _buildSummaryGrid() {
    final totalIncome = _analytics!['totalIncome'] ?? 0.0;
    final totalBookings = _analytics!['totalBookings'] ?? 0;
    final totalParkingSpaces = _analytics!['totalParkingSpaces'] ?? 0;
    final totalUsers = _analytics!['totalUsers'] ?? 0;
    final totalOwners = _analytics!['totalOwners'] ?? 0;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard('Total Income', '₹${totalIncome.toStringAsFixed(2)}', Icons.payments, Colors.green),
        _buildStatCard('Bookings', '$totalBookings', Icons.confirmation_number, Colors.blue),
        _buildStatCard('Parking Spaces', '$totalParkingSpaces', Icons.local_parking, Colors.orange),
        _buildStatCard('Total Users', '$totalUsers', Icons.person, Colors.purple),
        _buildStatCard('Total Owners', '$totalOwners', Icons.person_outline, Colors.teal),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildRetryButton(VoidCallback onRetry) {
    return Center(
      child: ElevatedButton(onPressed: onRetry, child: const Text("Retry")),
    );
  }

  // Implementation of existing tabs (Parking Requests, Settings, Logout) remains similar to your original code...
  // [Truncated for brevity, but keep your existing _buildParkingRequestsTab and _logout logic here]
  
  Future<void> _loadParkingRequests() async {
    // Placeholder: existing parking request logic should remain here.
  }

  Future<void> _approveParking(String id) async {
    // Placeholder: existing approve logic should remain here.
  }

  Future<void> _rejectParking(String id) async {
    // Placeholder: existing reject logic should remain here.
  }

  Future<void> _logout() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    await auth.logout();

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }
  
  Widget _buildParkingRequestsTab() {
    return const Center(child: Text("Requests Implementation"));
  }

  Widget _buildSettingsTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Settings',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('Logout'),
              subtitle: const Text('Sign out from the admin dashboard'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _logout,
            ),
          ),
        ],
      ),
    );
  }
}