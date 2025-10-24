import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' show cos, sqrt, asin;
import '../constants/theme.dart';
import '../styles/recommendations_styles.dart';

class RecommendationsPage extends StatefulWidget {
  const RecommendationsPage({super.key});

  @override
  State<RecommendationsPage> createState() => _RecommendationsPageState();
}

class _RecommendationsPageState extends State<RecommendationsPage> {
  final DatabaseReference _dbRef =
      FirebaseDatabase.instance.ref().child('volunteer_requests');

  List<Map<String, dynamic>> requests = [];
  List<Map<String, dynamic>> filteredRequests = [];
  final TextEditingController _searchController = TextEditingController();

  Position? _currentPosition;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  Future<void> _getUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please enable location services.', style: RecommendationsStyles.output),
            backgroundColor: ThemeConstants.accent,
          ),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location permission denied.', style: RecommendationsStyles.output),
            backgroundColor: ThemeConstants.accent,
          ),
        );
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() => _currentPosition = pos);

      _fetchRequests();
    } catch (e) {
      print("Error getting location: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error getting location: $e', style: RecommendationsStyles.output),
          backgroundColor: ThemeConstants.accent,
        ),
      );
    }
  }

  void _fetchRequests() {
    _dbRef.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        final fetched = data.entries.map((entry) {
          final req = Map<String, dynamic>.from(entry.value);
          req['id'] = entry.key;

          // Distance calculation
          if (_currentPosition != null &&
              req.containsKey('latitude') &&
              req.containsKey('longitude')) {
            req['distance'] = _calculateDistance(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              req['latitude'],
              req['longitude'],
            );
          } else {
            req['distance'] = double.infinity;
          }

          // Join state flags
          req['_joining'] = false;
          req['_hasJoined'] = false;

          return req;
        }).toList();

        fetched.sort((a, b) => a['distance'].compareTo(b['distance']));

        setState(() {
          requests = fetched;
          filteredRequests = fetched;
          _isLoading = false;
        });

        // Check if user has already joined any request
        _checkJoinedRequests();
      } else {
        setState(() => _isLoading = false);
      }
    });
  }

  Future<void> _checkJoinedRequests() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    for (var req in requests) {
      final snapshot = await FirebaseDatabase.instance
          .ref('volunteer_requests/${req['id']}/applicants/${user.uid}')
          .get();
      if (snapshot.exists) {
        setState(() {
          req['_hasJoined'] = true;
        });
      }
    }
  }

  double _calculateDistance(lat1, lon1, lat2, lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  void _filterRequests(String query) {
    if (query.isEmpty) {
      setState(() => filteredRequests = requests);
    } else {
      final lowerQuery = query.toLowerCase();
      setState(() {
        filteredRequests = requests.where((req) {
          final title = (req['eventName'] ?? '').toString().toLowerCase();
          final desc = (req['description'] ?? '').toString().toLowerCase();
          final skills = (req['skillsRequired'] ?? []).join(',').toLowerCase();
          return title.contains(lowerQuery) ||
              desc.contains(lowerQuery) ||
              skills.contains(lowerQuery);
        }).toList();
      });
    }
  }

  Future<void> _joinRequest(Map<String, dynamic> req) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You must be logged in to join.', style: RecommendationsStyles.output),
          backgroundColor: ThemeConstants.accent,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.volunteer_activism, color: ThemeConstants.primary),
            const SizedBox(width: RecommendationsStyles.spacingXSmall),
            Text("Confirm Join", style: RecommendationsStyles.header),
          ],
        ),
        content: Text("Do you want to join '${req['eventName']}'?", style: RecommendationsStyles.output),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("Cancel", style: RecommendationsStyles.output),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text("Join", style: RecommendationsStyles.output),
            style: ElevatedButton.styleFrom(
              backgroundColor: ThemeConstants.accentBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(RecommendationsStyles.borderRadiusMedium),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => req['_joining'] = true);

    try {
      final applicantRef = FirebaseDatabase.instance
          .ref('volunteer_requests/${req['id']}/applicants/${user.uid}');
      await applicantRef.set({
        'email': user.email ?? 'No email',
        'joinedAt': DateTime.now().toIso8601String(),
        'status': 'pending',
      });

      setState(() {
        req['_hasJoined'] = true;
        req['_joining'] = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("You've joined '${req['eventName']}' successfully!", style: RecommendationsStyles.output),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() => req['_joining'] = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error joining request: $e', style: RecommendationsStyles.output),
          backgroundColor: ThemeConstants.accent,
        ),
      );
    }
  }

  void _showRequestDetails(Map<String, dynamic> req) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(RecommendationsStyles.borderRadiusLarge)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(RecommendationsStyles.spacingMedium),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 50,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: RecommendationsStyles.spacingSmall),
                    decoration: BoxDecoration(
                      color: ThemeConstants.placeholder,
                      borderRadius: BorderRadius.circular(RecommendationsStyles.borderRadiusSmall),
                    ),
                  ),
                ),
                Text(req['eventName'] ?? 'No Title',
                    style: RecommendationsStyles.output.copyWith(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: RecommendationsStyles.spacingXSmall),
                Text(req['description'] ?? 'No description provided.',
                    style: RecommendationsStyles.subtitle),
                const SizedBox(height: RecommendationsStyles.spacingMedium),
                const Divider(),
                Row(
                  children: [
                    const Icon(Icons.location_on, color: ThemeConstants.accent),
                    const SizedBox(width: RecommendationsStyles.spacingXSmall),
                    Expanded(
                      child: Text(req['address'] ?? 'No address provided', style: RecommendationsStyles.output),
                    ),
                  ],
                ),
                const SizedBox(height: RecommendationsStyles.spacingXSmall),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, color: ThemeConstants.accentBlue),
                    const SizedBox(width: RecommendationsStyles.spacingXSmall),
                    Text("Date: ${req['date'] ?? 'N/A'}", style: RecommendationsStyles.output),
                    const SizedBox(width: RecommendationsStyles.spacingMedium),
                    const Icon(Icons.access_time, color: ThemeConstants.accentBlue),
                    const SizedBox(width: RecommendationsStyles.spacingXSmall),
                    Text("Time: ${req['time'] ?? 'N/A'}", style: RecommendationsStyles.output),
                  ],
                ),
                const SizedBox(height: RecommendationsStyles.spacingXSmall),
                Row(
                  children: [
                    const Icon(Icons.group, color: ThemeConstants.accentBlue),
                    const SizedBox(width: RecommendationsStyles.spacingXSmall),
                    Text("Volunteers needed: ${req['numberNeeded'] ?? 'N/A'}", style: RecommendationsStyles.output),
                  ],
                ),
                const SizedBox(height: RecommendationsStyles.spacingXSmall),
                if (req['distance'] != null && req['distance'] != double.infinity)
                  Text(
                    "📍 Distance: ${req['distance'].toStringAsFixed(2)} km away",
                    style: RecommendationsStyles.output.copyWith(color: ThemeConstants.accentBlue),
                  ),
                const SizedBox(height: RecommendationsStyles.spacingMedium),
                Text(
                  "Skills Required:",
                  style: RecommendationsStyles.output.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: RecommendationsStyles.spacingXSmall),
                Wrap(
                  spacing: RecommendationsStyles.spacingXSmall,
                  children: (req['skillsRequired'] as List?)
                          ?.map((s) => Chip(
                                label: Text(s.toString().trim(), style: RecommendationsStyles.output),
                                backgroundColor: ThemeConstants.accentBlue.withOpacity(0.2),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(RecommendationsStyles.borderRadiusMedium),
                                ),
                              ))
                          .toList() ??
                      [Text('None listed', style: RecommendationsStyles.subtitle)],
                ),
                const SizedBox(height: RecommendationsStyles.spacingLarge),
                Center(
                  child: ElevatedButton.icon(
                    onPressed: req['_hasJoined'] || req['_joining']
                        ? null
                        : () {
                            Navigator.pop(context);
                            _joinRequest(req);
                          },
                    icon: req['_joining']
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.volunteer_activism, color: Colors.white),
                    label: Text(
                      req['_hasJoined']
                          ? "Joined"
                          : req['_joining']
                              ? "Joining..."
                              : "Join",
                      style: RecommendationsStyles.output.copyWith(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ThemeConstants.accentBlue,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(RecommendationsStyles.borderRadiusMedium)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> req) {
    return Card(
      margin: const EdgeInsets.symmetric(
          horizontal: RecommendationsStyles.spacingSmall, vertical: RecommendationsStyles.spacingXSmall),
      elevation: 5,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RecommendationsStyles.borderRadiusLarge)),
      child: InkWell(
        borderRadius: BorderRadius.circular(RecommendationsStyles.borderRadiusLarge),
        onTap: () => _showRequestDetails(req),
        child: Padding(
          padding: const EdgeInsets.all(RecommendationsStyles.spacingMedium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(req['eventName'] ?? 'Unnamed Event',
                        style: RecommendationsStyles.output.copyWith(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  if (req['distance'] != null && req['distance'] != double.infinity)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: RecommendationsStyles.spacingXSmall,
                          vertical: RecommendationsStyles.spacingXSmall),
                      decoration: BoxDecoration(
                        color: ThemeConstants.accentBlue.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(RecommendationsStyles.borderRadiusMedium),
                      ),
                      child: Text(
                        "${req['distance'].toStringAsFixed(1)} km",
                        style: RecommendationsStyles.output.copyWith(
                            color: ThemeConstants.accentBlue, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: RecommendationsStyles.spacingXSmall),
              Text(req['description'] ?? 'No description',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: RecommendationsStyles.subtitle),
              const SizedBox(height: RecommendationsStyles.spacingXSmall),
              Wrap(
                spacing: RecommendationsStyles.spacingXSmall,
                runSpacing: RecommendationsStyles.spacingXSmall,
                children: (req['skillsRequired'] as List?)
                        ?.map((s) => Chip(
                              label: Text(s.toString(),
                                  style: RecommendationsStyles.output.copyWith(color: Colors.white)),
                              backgroundColor: ThemeConstants.accentBlue,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(RecommendationsStyles.borderRadiusMedium),
                              ),
                              visualDensity: VisualDensity.compact,
                            ))
                        .toList() ??
                    [Text('No skills listed', style: RecommendationsStyles.subtitle)],
              ),
              const SizedBox(height: RecommendationsStyles.spacingMedium),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: req['_hasJoined'] || req['_joining']
                      ? null
                      : () => _joinRequest(req),
                  icon: req['_joining']
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.volunteer_activism, color: Colors.white),
                  label: Text(
                    req['_hasJoined']
                        ? "Joined"
                        : req['_joining']
                            ? "Joining..."
                            : "Join",
                    style: RecommendationsStyles.output.copyWith(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThemeConstants.accentBlue,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(RecommendationsStyles.borderRadiusMedium)),
                    padding: const EdgeInsets.symmetric(vertical: RecommendationsStyles.spacingMedium),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomRight,
            colors: [Color(0x6614AEBB), Color(0xFFFFF9F0)],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(RecommendationsStyles.spacingMedium),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Volunteer Recommendations', style: RecommendationsStyles.header),
                          const SizedBox(height: RecommendationsStyles.spacingXSmall),
                          Text(
                            '${filteredRequests.length} Request(s)',
                            style: RecommendationsStyles.subtitle,
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: RecommendationsStyles.spacingSmall,
                          vertical: RecommendationsStyles.spacingXSmall),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: ThemeConstants.placeholder),
                          borderRadius: BorderRadius.circular(RecommendationsStyles.borderRadiusXLarge),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: _filterRequests,
                          style: RecommendationsStyles.output,
                          decoration: InputDecoration(
                            labelText: 'Search by event, skill, or location...',
                            labelStyle: RecommendationsStyles.subtitle,
                            prefixIcon: const Icon(Icons.search, color: ThemeConstants.primary),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: RecommendationsStyles.spacingMedium,
                                horizontal: RecommendationsStyles.spacingMedium),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: filteredRequests.isEmpty
                          ? Center(
                              child: Text('No nearby requests found.', style: RecommendationsStyles.subtitle),
                            )
                          : ListView.builder(
                              itemCount: filteredRequests.length,
                              itemBuilder: (context, index) {
                                final req = filteredRequests[index];
                                return _buildRequestCard(req);
                              },
                            ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}