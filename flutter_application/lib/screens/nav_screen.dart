import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/custom_bottom_nav_bar.dart';

import '../screens/home_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/communityboard_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/org_request_page.dart';
import '../screens/recommendations_page.dart';
import '../screens/map_page.dart';

class NavScreen extends StatefulWidget {
  const NavScreen({super.key});

  @override
  State<NavScreen> createState() => _NavScreenState();
}

class _NavScreenState extends State<NavScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final bool isAbAdmin = auth.isAbAdmin;

    final List<Widget> _pages = [
      const HomeScreen(),
      const DashboardScreen(),
      const CommunityBoardScreen(),
      const ProfileScreen(),
      if (isAbAdmin) const OrgRequestPage(),
      const RecommendationsPage(),
      const MapPage(),
    ];

   
    int displayedIndex = _currentIndex;
    if (!isAbAdmin && _currentIndex >= 4) {
      displayedIndex = _currentIndex + 1; 
    }

    return Scaffold(
      body: IndexedStack(
        index: displayedIndex,
        children: _pages,
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (int tapped) => setState(() => _currentIndex = tapped),
        isAbAdmin: isAbAdmin,
      ),
    );
  }
}