import 'package:flutter/material.dart';
import '../widgets/custom_bottom_nav_bar.dart';
import '../screens/home_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/communityboard_screen.dart';

import '../screens/org_request_page.dart'; // ✅ Import your new page
import '../screens/recommendations_page.dart'; // ✅ New import
import '../screens/map_page.dart'; // ✅ Add this


class NavScreen extends StatefulWidget {
  const NavScreen({super.key});

  @override
  State<NavScreen> createState() => _NavScreenState();
}

class _NavScreenState extends State<NavScreen> {
  int _currentIndex = 0;

  // ✅ Added OrgRequestPage as the 5th tab
  final List<Widget> _pages = [
    const HomeScreen(),
    const DashboardScreen(),
    const CommunityBoardScreen(),
    const ProfileScreen(),
    const OrgRequestPage(), // ✅ New page
    const RecommendationsPage(),  // ✅ Added
    const MapPage(), // ✅ Added

  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
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
