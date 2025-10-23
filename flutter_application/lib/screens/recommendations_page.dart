import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application/screens/details_page.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' show cos, sqrt, asin;

class RecommendationsPage extends StatefulWidget {
  const RecommendationsPage({Key? key}) : super(key: key);

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
          const SnackBar(content: Text('Please enable location services.')),
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
          const SnackBar(content: Text('Location permission denied.')),
        );
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() => _currentPosition = pos);

      _fetchRequests(); // fetch after getting location
    } catch (e) {
      print("Error getting location: $e");
    }
  }

  void _fetchRequests() {
    _dbRef.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        final fetched = data.entries.map((entry) {
          final req = Map<String, dynamic>.from(entry.value);
          req['id'] = entry.key;

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

          return req;
        }).toList();

        fetched.sort((a, b) => a['distance'].compareTo(b['distance']));

        setState(() {
          requests = fetched;
          filteredRequests = fetched;
          _isLoading = false;
        });
      }
    });
  }

  double _calculateDistance(lat1, lon1, lat2, lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) *
            cos(lat2 * p) *
            (1 - cos((lon2 - lon1) * p)) /
            2;
    return 12742 * asin(sqrt(a)); // in kilometers
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
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be logged in to join.')),
        );
        return;
      }

      final applicantRef = FirebaseDatabase.instance
          .ref('volunteer_requests/${req['id']}/applicants/${user.uid}');

      await applicantRef.set({
        'email': user.email ?? 'No email',
        'joinedAt': DateTime.now().toIso8601String(),
        'status': 'pending',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You’ve joined "${req['eventName']}" successfully!'),
          backgroundColor: Colors.green.shade600,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error joining request: $e')),
      );
    }
  }

  void _showRequestDetails(Map<String, dynamic> req) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 50,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                Text(req['eventName'] ?? 'No Title',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(req['description'] ?? 'No description provided.',
                    style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 12),
                const Divider(),

                Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.redAccent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(req['address'] ?? 'No address provided'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                Row(
                  children: [
                    const Icon(Icons.calendar_today, color: Colors.teal),
                    const SizedBox(width: 6),
                    Text("Date: ${req['date'] ?? 'N/A'}"),
                    const SizedBox(width: 16),
                    const Icon(Icons.access_time, color: Colors.teal),
                    const SizedBox(width: 6),
                    Text("Time: ${req['time'] ?? 'N/A'}"),
                  ],
                ),
                const SizedBox(height: 8),

                Row(
                  children: [
                    const Icon(Icons.group, color: Colors.blueAccent),
                    const SizedBox(width: 6),
                    Text("Volunteers needed: ${req['numberNeeded'] ?? 'N/A'}"),
                  ],
                ),
                const SizedBox(height: 8),

                if (req['distance'] != null &&
                    req['distance'] != double.infinity)
                  Text(
                    "📍 Distance: ${req['distance'].toStringAsFixed(2)} km away",
                    style: const TextStyle(color: Colors.teal),
                  ),

                const SizedBox(height: 12),
                Text(
                  "Skills Required:",
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.grey[700]),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: (req['skillsRequired'] as List?)
                          ?.map((s) => Chip(
                                label: Text(s.toString().trim(),
                                    style:
                                        const TextStyle(color: Colors.white)),
                                backgroundColor: Colors.teal,
                              ))
                          .toList() ??
                      [const Text('None listed')],
                ),
                const SizedBox(height: 24),

                Center(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _joinRequest(req);
                    },
                    icon: const Icon(Icons.volunteer_activism),
                    label: const Text("Join This Request"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        title: const Text('Volunteer Recommendations'),
        backgroundColor: Colors.teal,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _filterRequests,
                    decoration: InputDecoration(
                      hintText: "Search by event, skill, or location...",
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                Expanded(
                  child: filteredRequests.isEmpty
                      ? const Center(child: Text("No nearby requests found."))
                      : ListView.builder(
                          itemCount: filteredRequests.length,
                          itemBuilder: (context, index) {
                            final req = filteredRequests[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              elevation: 3,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              child: ListTile(
                                leading: const CircleAvatar(
                                  backgroundColor: Colors.teal,
                                  child: Icon(Icons.handshake,
                                      color: Colors.white),
                                ),
                                title:
                                    Text(req['eventName'] ?? 'Unnamed Event'),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(req['description'] ?? 'No description',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis),
                                    if (req['distance'] != null &&
                                        req['distance'] != double.infinity)
                                      Text(
                                          "📍 ${req['distance'].toStringAsFixed(2)} km away",
                                          style: const TextStyle(
                                              color: Colors.teal,
                                              fontSize: 13)),
                                  ],
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios,
                                    size: 18),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          DetailsPage(request: req,),
                                    ),
                                  );
                                }
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
