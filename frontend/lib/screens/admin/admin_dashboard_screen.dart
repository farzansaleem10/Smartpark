import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart'; 
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
  List<dynamic> _allUsers = []; 
  
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

  Future<void> _deleteParking(String parkingId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Parking Space'),
        content: const Text('Are you sure you want to remove this parking space? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final response = await ApiService.deleteParking(parkingId);
      if (response['success']) {
        _showSnackBar('Parking space removed successfully', Colors.green);
        _loadUsers();
      } else {
        _showSnackBar(response['message'] ?? 'Failed to remove parking space', Colors.red);
      }
    } catch (e) {
      _showSnackBar(e.toString(), Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  // Helper to open documents safely
  Future<void> _openDocument(String? docPath) async {
    if (docPath == null || docPath.isEmpty) {
      _showSnackBar("No document available", Colors.orange);
      return;
    }

    String fullUrl;
    if (docPath.startsWith('data:')) {
      fullUrl = docPath;
    } else if (docPath.startsWith('http')) {
      fullUrl = docPath;
    } else {
      final cleanBase = ApiService.baseUrl.replaceAll('/api', '').replaceAll(RegExp(r'/$'), '');
      final cleanDoc = docPath.startsWith('/') ? docPath : '/$docPath';
      fullUrl = '$cleanBase$cleanDoc';
    }

    final Uri url = Uri.parse(fullUrl);
    debugPrint("🔗 ATTEMPTING TO OPEN: $fullUrl");

    try {
      await launchUrl(
        url,
        mode: fullUrl.contains('10.0.2.2') 
            ? LaunchMode.externalApplication 
            : LaunchMode.platformDefault,
      );
    } catch (e) {
      debugPrint("🚨 Launch Error: $e");
      _showSnackBar("Could not open document.", Colors.red);
    }
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
                      '₹${(double.tryParse(owner['totalIncome']?.toString() ?? '0') ?? 0.0).toStringAsFixed(2)}',
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

  Widget _buildUsersManagementTab() {
    final customers = _allUsers.where((u) {
      final role = (u['role'] ?? '').toString().toLowerCase().trim();
      return role == 'user' || role == 'customer';
    }).toList();

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
        final bool isActive = user['isActive'] ?? true; 

        return Card(
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: isActive ? Colors.blue : Colors.grey,
              child: Text(user['name']?[0] ?? 'U'),
            ),
            title: Row(
              children: [
                Expanded(child: Text(user['name'] ?? 'Unknown')),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.green.shade50 : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isActive ? Colors.green : Colors.red,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    isActive ? 'Active' : 'Deactivated',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isActive ? Colors.green.shade700 : Colors.red.shade700,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Text(user['email'] ?? ''),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildDetailRow('Phone', user['phone'] ?? 'N/A'),
                    _buildDetailRow('Account Status', isActive ? 'Active' : 'Deactivated'),
                    if ((user['role'] ?? '').toString().toLowerCase().trim() == 'owner') ...[
                      const SizedBox(height: 12),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Owner Parking Spaces', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 8),
                      if ((user['ownerParkings'] as List<dynamic>?)?.isEmpty ?? true)
                        const Text('No parking spaces found for this owner.'),
                      ...((user['ownerParkings'] as List<dynamic>?) ?? []).map((parking) {
                        final licenseDocPath = parking['licenseDocument']?.toString() ?? '';

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(parking['name'] ?? 'Unnamed Parking', style: const TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                Text(
                                  '${parking['address']?['street'] ?? ''}, ${parking['address']?['city'] ?? ''}',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                                const SizedBox(height: 8),
                                _buildDetailRow('Slots', '${parking['availableSlots'] ?? 0}/${parking['totalSlots'] ?? 0}'),
                                _buildDetailRow('Price/hr', '₹${parking['pricePerHour'] ?? 0}'),
                                _buildDetailRow('Status', '${parking['approvalStatus'] ?? 'unknown'}'),
                                _buildDetailRow('Verified', '${parking['isVerified'] == true ? 'Yes' : 'No'}'),
                                
                                const SizedBox(height: 12),
                                // --- OWNER SECTION DOCUMENT BUTTON ---
                                GestureDetector(
                                  onTap: () => _openDocument(licenseDocPath),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: licenseDocPath.isNotEmpty ? Colors.blue.shade50 : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: licenseDocPath.isNotEmpty ? Colors.blue.shade300 : Colors.grey.shade300,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          licenseDocPath.isNotEmpty ? Icons.insert_drive_file : Icons.description_outlined, 
                                          size: 20, 
                                          color: licenseDocPath.isNotEmpty ? Colors.blue : Colors.grey
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          licenseDocPath.isNotEmpty ? "View License Document" : "No Document",
                                          style: TextStyle(
                                            fontSize: 13, 
                                            fontWeight: FontWeight.bold,
                                            color: licenseDocPath.isNotEmpty ? Colors.blue.shade900 : Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: () => _deleteParking(parking['_id'].toString()),
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    label: const Text('Remove', style: TextStyle(color: Colors.red)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _toggleUserStatus(user['_id'], isActive),
                          icon: Icon(isActive ? Icons.block : Icons.check_circle),
                          label: Text(isActive ? 'Deactivate Credential' : 'Activate Account'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isActive ? Colors.red : Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
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

  Widget _buildSummaryGrid() {
    final totalIncome = double.tryParse(_analytics!['totalIncome']?.toString() ?? '0') ?? 0.0;
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

  Future<void> _approveParking(String id) async {
    try {
      final response = await ApiService.approveParkingRequest(id);
      if (response['success']) {
        _showSnackBar('Parking approved successfully', Colors.green);
        _loadParkingRequests(); 
      } else {
        _showSnackBar(response['message'] ?? 'Failed to approve', Colors.red);
      }
    } catch (e) {
      _showSnackBar(e.toString(), Colors.red);
    }
  }

  Future<void> _rejectParking(String id) async {
    final reasonController = TextEditingController();
    
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Parking Request'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Reason for rejection (Required)',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) {
                _showSnackBar('Please provide a reason', Colors.red);
                return;
              }
              Navigator.pop(context); 
              try {
                final response = await ApiService.rejectParkingRequest(id, reason: reasonController.text.trim());
                if (response['success']) {
                  _showSnackBar('Parking rejected', Colors.orange);
                  _loadParkingRequests(); 
                } else {
                  _showSnackBar(response['message'] ?? 'Failed to reject', Colors.red);
                }
              } catch (e) {
                _showSnackBar(e.toString(), Colors.red);
              }
            },
            child: const Text('Confirm Reject'),
          ),
        ],
      ),
    );
  }

  Widget _buildParkingRequestsTab() {
    if (_loadingRequests) return const Center(child: CircularProgressIndicator());
    if (_requestsError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_requestsError!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadParkingRequests, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_parkingRequests.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text("No parking requests found.", style: TextStyle(fontSize: 18, color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _parkingRequests.length,
      itemBuilder: (context, index) {
        final request = _parkingRequests[index];
        final id = request['_id'] ?? '';
        final name = request['name'] ?? 'Unknown Parking';
        final status = request['approvalStatus'] ?? 'pending';
        final type = request['type'] ?? 'Land';
        final licenseDocPath = request['licenseDocument']?.toString() ?? '';

        String ownerName = 'Unknown Owner';
        if (request['owner'] != null && request['owner'] is Map) {
          ownerName = request['owner']['name'] ?? 'Unknown Owner';
        }

        Color statusColor = status == 'approved' ? Colors.green : (status == 'rejected' ? Colors.red : Colors.orange);

        return Card(
          elevation: 3,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                    Chip(
                      label: Text(status.toString().toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12)),
                      backgroundColor: statusColor,
                    ),
                  ],
                ),
                const Divider(),
                _buildRequestInfoRow(Icons.person, "Owner: $ownerName"),
                _buildRequestInfoRow(Icons.category, "Type: $type"),
                const SizedBox(height: 12),
                
                // --- REQUEST TAB DOCUMENT BUTTON ---
                if (licenseDocPath.isNotEmpty)
                  GestureDetector(
                    onTap: () => _openDocument(licenseDocPath),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade300, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.insert_drive_file, color: Colors.blue.shade700, size: 28),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Verification Document", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
                                Text("Tap here to view file", style: TextStyle(fontSize: 12, color: Color(0xFF1976D2))),
                              ],
                            ),
                          ),
                          Icon(Icons.open_in_new, color: Colors.blue.shade700),
                        ],
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                    child: const Row(children: [Icon(Icons.warning_amber, color: Colors.grey), SizedBox(width: 8), Text("No document uploaded")]),
                  ),
                
                if (status == 'pending') ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: OutlinedButton.icon(onPressed: () => _rejectParking(id), icon: const Icon(Icons.close, color: Colors.red), label: const Text('Reject', style: TextStyle(color: Colors.red)))),
                      const SizedBox(width: 12),
                      Expanded(child: ElevatedButton.icon(onPressed: () => _approveParking(id), icon: const Icon(Icons.check), label: const Text('Approve'), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white))),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRequestInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(children: [Icon(icon, size: 16, color: Colors.grey), const SizedBox(width: 8), Text(text, style: const TextStyle(fontSize: 14))]),
    );
  }

  Future<void> _logout() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    await auth.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
  }

  Widget _buildSettingsTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Settings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Card(child: ListTile(leading: const Icon(Icons.logout, color: Colors.redAccent), title: const Text('Logout'), subtitle: const Text('Sign out from the admin dashboard'), trailing: const Icon(Icons.chevron_right), onTap: _logout)),
        ],
      ),
    );
  }
}