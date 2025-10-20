import 'package:flutter/material.dart';
import '../widgets/custom_bottom_nav_bar.dart';
import 'home_screen.dart';  // Your converted HomeScreen (map)
import 'dashboard_screen.dart';  // Your Dashboard
import 'profile_screen.dart';  // Placeholder for Profile (create as needed)

class NavScreen extends StatefulWidget {
  const NavScreen({super.key});

  @override
  State<NavScreen> createState() => _NavScreenState();
}

class _NavScreenState extends State<NavScreen> {
  int _currentIndex = 0;  // Start on Home

  // Your tab pages (add more as needed)
  final List<Widget> _pages = [
    HomeScreen(),  // Tab 0: Map/Home
    DashboardScreen(),  // Tab 1: Metrics
    ProfileScreen(),  // Tab 2: Profile/Settings
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(  // Preserves state (e.g., map doesn't reload)
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}