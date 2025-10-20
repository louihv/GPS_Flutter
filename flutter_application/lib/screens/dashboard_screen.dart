import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart' as myAuth;
import '../constants/theme.dart';
import '../styles/dashboard_styles.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with TickerProviderStateMixin {
  List<Map<String, dynamic>> _metrics = [
    {'label': 'No. of Food Packs', 'value': '0', 'icon': MdiIcons.foodVariant},
    {'label': 'No. of Hot Meals', 'value': '0', 'icon': MdiIcons.silverwareForkKnife},
    {'label': 'Liters of Water', 'value': '0', 'icon': MdiIcons.water},
    {'label': 'Volunteers Mobilized', 'value': '0', 'icon': MdiIcons.accountGroup},
    {'label': 'Monetary Donations', 'value': '₱0.00', 'icon': MdiIcons.cash},
    {'label': 'In-Kind Donations', 'value': '₱0.00', 'icon': MdiIcons.gift},
  ];
  String _headerTitle = 'Dashboard';
  String _organizationName = '';
  bool _modalVisible = false;
  bool _hasShownModal = false;
  LocationPermission? _permissionStatus;
  Position? _location;
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _scaleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));
    _scaleAnim = Tween<double>(begin: 0.85, end: 1).animate(CurvedAnimation(parent: _scaleController, curve: Curves.easeOut));
    _checkModalStatus();
    _startAnimation();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  void _startAnimation() {
    _fadeController.forward();
    _scaleController.forward();
  }

  // NEW: Safe parsing helper for Firebase string/num values
  double parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;  // Fallback for unexpected types
  }

  Future<void> _checkModalStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final hasShown = prefs.getBool('hasShownLocationModal') ?? false;
    if (!hasShown && !_hasShownModal && _permissionStatus == null) {
      if (mounted) {
        setState(() {
          _modalVisible = true;
          _hasShownModal = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<myAuth.AuthProvider>(context);
    final user = authProvider.user;

    if (user == null) {
      Fluttertoast.showToast(msg: 'Please sign in to access the dashboard.');
      WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.pushReplacementNamed(context, '/login'));
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final userId = user.uid;  // Ensure string for comparison
    final role = authProvider.userData?['role'] ?? '';
    final orgName = authProvider.userData?['organization'] ?? '';

    if (role != 'AB ADMIN') {
      _organizationName = orgName;
    }
    _headerTitle = role == 'AB ADMIN' ? 'Admin Dashboard' : 'Volunteer Dashboard';

    return Container(
      decoration: DashboardStyles.gradientContainer(),
      child: SafeArea(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Column(
            children: [
              // Header
              Container(
                padding: DashboardStyles.headerPadding(),
                height: DashboardStyles.headerHeight,
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.menu, size: 32, color: ThemeConstants.primary),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                    const Spacer(),
                    Text(
                      _headerTitle,
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: ThemeConstants.primary,
                      ),
                    ),
                  ],
                ),
              ),
              // Scrollable Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_organizationName.isNotEmpty && role != 'AB ADMIN')
                        Padding(
                          padding: EdgeInsets.only(left: DashboardStyles.large),
                          child: Text(_organizationName, style: DashboardStyles.sectionTitleStyle),
                        )
                      else
                        SizedBox(height: DashboardStyles.large),
                      // Metrics (StreamBuilder for real-time)
                      StreamBuilder<DatabaseEvent>(
                        stream: FirebaseDatabase.instance.ref().child('reports/approved').onValue,
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            Fluttertoast.showToast(msg: 'Failed to load dashboard data. Please try again later.');
                            return _buildErrorMetrics();
                          }
                          final data = snapshot.data?.snapshot.value as Map<dynamic, dynamic>? ?? {};
                          double totalFoodPacks = 0;
                          double totalHotMeals = 0;
                          double totalWaterLiters = 0;
                          double totalVolunteers = 0;
                          double totalMonetaryDonations = 0;
                          double totalInKindDonations = 0;

                          for (var report in data.values) {
                            final r = report as Map<dynamic, dynamic>;
                            if (role == 'ABVN' && r['userUid'] != userId) continue;
                            // FIXED: Use parseDouble to safely handle String/num/null
                            totalFoodPacks += parseDouble(r['NoOfFoodPacks']);
                            totalHotMeals += parseDouble(r['NoOfHotMeals']);
                            totalWaterLiters += parseDouble(r['LitersOfWater']);
                            totalVolunteers += parseDouble(r['NoOfVolunteersMobilized']);
                            totalMonetaryDonations += parseDouble(r['TotalMonetaryDonations']);
                            totalInKindDonations += parseDouble(r['TotalValueOfInKindDonations']);
                          }

                          _metrics = [
                            {'label': 'No. of Food Packs', 'value': totalFoodPacks.toStringAsFixed(0), 'icon': MdiIcons.foodVariant},
                            {'label': 'No. of Hot Meals', 'value': totalHotMeals.toStringAsFixed(0), 'icon': MdiIcons.silverwareForkKnife},
                            {'label': 'Liters of Water', 'value': totalWaterLiters.toStringAsFixed(0), 'icon': MdiIcons.water},
                            {'label': 'Volunteers Mobilized', 'value': totalVolunteers.toStringAsFixed(0), 'icon': MdiIcons.accountGroup},
                            {
                              'label': 'Monetary Donations',
                              'value': '₱${totalMonetaryDonations.toStringAsFixed(2)}',
                              'icon': MdiIcons.cash,
                            },
                            {
                              'label': 'In-Kind Donations',
                              'value': '₱${totalInKindDonations.toStringAsFixed(2)}',
                              'icon': MdiIcons.gift,
                            },
                          ];

                          return Column(
                            children: _metrics.map((metric) => TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: 1),
                              duration: const Duration(milliseconds: 700),
                              builder: (context, value, child) {
                                return Transform.scale(
                                  scale: value,
                                  child: Opacity(
                                    opacity: value,
                                    child: _buildMetricCard(metric),
                                  ),
                                );
                              },
                            )).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(Map<String, dynamic> metric) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: DashboardStyles.medium),
      child: Container(
        decoration: DashboardStyles.formCard(context),
        child: Container(
          padding: DashboardStyles.metricCardPadding(),
          decoration: DashboardStyles.metricGradientCard(),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: DashboardStyles.iconContainer(),
                child: Icon(
                  metric['icon'] as IconData? ?? Icons.info,
                  size: 28,
                  color: ThemeConstants.accentBlue,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: DashboardStyles.medium),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(metric['label'], style: DashboardStyles.metricLabelStyle),
                      const SizedBox(height: 4),
                      Text(metric['value'], style: DashboardStyles.metricValueStyle),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorMetrics() {
    return Column(
      children: _metrics.map((metric) => _buildMetricCard({
        ...metric,
        'value': metric['label'].contains('₱') ? '₱0.00 (Error)' : '0 (Error)',
      })).toList(),
    );
  }

  Future<void> _handleRequestPermission() async {
    try {
      final permission = await Geolocator.requestPermission();
      if (mounted) setState(() => _permissionStatus = permission);
      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        if (position.accuracy > 50) {
          Fluttertoast.showToast(msg: 'Your location accuracy is low. The pin may not be precise.');
        }
        if (mounted) setState(() => _location = position);
        if (mounted) setState(() => _modalVisible = false);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('hasShownLocationModal', true);
      } else {
        if (mounted) setState(() => _permissionStatus = LocationPermission.denied);
        if (mounted) setState(() => _modalVisible = false);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('hasShownLocationModal', true);
      }
    } catch (e) {
      debugPrint('Permission error: $e');
      Fluttertoast.showToast(msg: 'Failed to request location permission. Please try again.');
    }
  }

  void _closeModal() {
    if (mounted) setState(() => _permissionStatus = LocationPermission.denied);
    if (mounted) setState(() => _modalVisible = false);
    SharedPreferences.getInstance().then((prefs) => prefs.setBool('hasShownLocationModal', true));
  }

  // Location Modal (bottom sheet)
  void _showLocationModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 300,
        decoration: DashboardStyles.modalContainer(),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.location_on, size: 84, color: ThemeConstants.red),
            Text('Where Are You?', style: DashboardStyles.permissionDeniedHeaderStyle),
            const SizedBox(height: 10),
            Text(
              'Let Bayanihan access your location to show position on the map.',
              style: DashboardStyles.permissionDeniedTextStyle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _handleRequestPermission,
                    style: DashboardStyles.retryButtonStyle(),
                    child: Text('Allow Location Access', style: DashboardStyles.buttonTextStyle),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _closeModal,
                    style: DashboardStyles.closeButtonStyle(),
                    child: Text(
                      'Not Now',
                      style: DashboardStyles.buttonTextStyle.copyWith(color: ThemeConstants.primary),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}