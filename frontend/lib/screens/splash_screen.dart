import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'auth/login_screen.dart';
import 'home/home_screen.dart';
import 'admin/admin_dashboard_screen.dart';
import 'owner/owner_dashboard_screen.dart';


class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    await authService.initialize();

    if (mounted) {
     if (authService.isAuthenticated) {
  final role = authService.user?.role;

  if (role == 'admin') {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
    );
  } else if (role == 'owner') {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const OwnerDashboardScreen()),
    );
  } else {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }
} else {
  Navigator.of(context).pushReplacement(
    MaterialPageRoute(builder: (_) => const LoginScreen()),
  );
}

    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_parking,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Smart Parking',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
