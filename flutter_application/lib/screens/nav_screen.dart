import 'package:flutter/material.dart';
import 'package:flutter_application/screens/admin_volunteer_map.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/custom_bottom_nav_bar.dart';

// Regular user screens
import '../screens/recommendations_page.dart';
import '../screens/map_page.dart';
import '../screens/profile_screen.dart';

// Admin-only screens
import '../screens/admin_dashboard_page.dart';
import '../screens/org_request_page.dart';

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

    // 🧭 Define separate nav items for volunteer vs admin
    final List<Widget> volunteerPages = [
      const RecommendationsPage(),
      const MapPage(),
      const ProfileScreen(),
    ];

    final List<Widget> adminPages = [
      const AdminDashboardPage(),
      const OrgRequestPage(),
      const AdminVolunteerMap(),
      const ProfileScreen(),
    ];

    final pages = isAbAdmin ? adminPages : volunteerPages;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (int tapped) => setState(() => _currentIndex = tapped),
        isAbAdmin: isAbAdmin,
      ),
    );
  }
}
