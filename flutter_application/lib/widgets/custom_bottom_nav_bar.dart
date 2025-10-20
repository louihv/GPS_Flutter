import 'package:flutter/material.dart';
import '../constants/theme.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  // FIXED: Removed 'const' from _items
  static final List<BottomNavigationBarItem> _items = [
    const BottomNavigationBarItem(
      icon: Icon(Icons.home_outlined),
      activeIcon: Icon(Icons.home_filled),
      label: 'Home',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.bar_chart_outlined), 
      activeIcon: Icon(Icons.bar_chart),
      label: 'Dashboard',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.person_outline),
      activeIcon: Icon(Icons.person),
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: ThemeConstants.primary,
      unselectedItemColor: Colors.grey[600],
      backgroundColor: Colors.white, // Or ThemeConstants.lightBg
      elevation: 8,
      selectedFontSize: 12,
      unselectedFontSize: 12,
      items: _items,
    );
  }
}