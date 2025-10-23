import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class DetailsPage extends StatefulWidget {
  final Map<String, dynamic> request;

  const DetailsPage({Key? key, required this.request}) : super(key: key);

  @override
  State<DetailsPage> createState() => _DetailsPageState();
}

class _DetailsPageState extends State<DetailsPage> {
  bool _hasJoined = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkIfJoined();
  }

  Future<void> _checkIfJoined() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final applicantRef = FirebaseDatabase.instance.ref(
        'volunteer_requests/${widget.request['id']}/applicants/${user.uid}');

    final snapshot = await applicantRef.get();
    if (snapshot.exists) {
      setState(() {
        _hasJoined = true;
      });
    }
    setState(() {
      _loading = false;
    });
  }

  Future<void> _joinRequest(BuildContext context) async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be logged in to join.')),
        );
        return;
      }

      final applicantRef = FirebaseDatabase.instance
          .ref('volunteer_requests/${widget.request['id']}/applicants/${user.uid}');

      await applicantRef.set({
        'email': user.email ?? 'No email',
        'joinedAt': DateTime.now().toIso8601String(),
        'status': 'pending',
      });

      setState(() => _hasJoined = true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('You’ve joined "${widget.request['eventName']}" successfully!'),
          backgroundColor: Colors.green.shade600,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error joining request: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final double? latitude = widget.request['latitude']?.toDouble();
    final double? longitude = widget.request['longitude']?.toDouble();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        title: Text(widget.request['eventName'] ?? 'Event Details'),
        backgroundColor: Colors.teal,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Banner
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/images/volunteer_banner.jpg',
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    widget.request['eventName'] ?? 'Untitled Event',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(widget.request['description'] ?? 'No description provided.'),
                  const SizedBox(height: 16),
                  const Divider(),

                  Row(
                    children: [
                      const Icon(Icons.calendar_today, color: Colors.teal),
                      const SizedBox(width: 6),
                      Text("Date: ${widget.request['date'] ?? 'N/A'}"),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.access_time, color: Colors.teal),
                      const SizedBox(width: 6),
                      Text("Time: ${widget.request['time'] ?? 'N/A'}"),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on, color: Colors.redAccent),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                            widget.request['address'] ?? 'No address provided'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.group, color: Colors.blueAccent),
                      const SizedBox(width: 6),
                      Text(
                          "Volunteers needed: ${widget.request['numberNeeded'] ?? 'N/A'}"),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Text(
                    "Skills Required:",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: (widget.request['skillsRequired'] as List?)
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

                  // OpenStreetMap preview
                  if (latitude != null && longitude != null) ...[
                    Text(
                      "Event Location Map:",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        height: 200,
                        child: FlutterMap(
                          options: MapOptions(
                            initialCenter: LatLng(latitude, longitude),
                            initialZoom: 15.0,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                              subdomains: const ['a', 'b', 'c'],
                              userAgentPackageName:
                                  'com.example.bayanihan_connect',
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: LatLng(latitude, longitude),
                                  width: 40,
                                  height: 40,
                                  child: const Icon(
                                    Icons.location_pin,
                                    color: Colors.redAccent,
                                    size: 40,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else
                    const Text('No map data available.'),
                ],
              ),
            ),
      bottomNavigationBar: !_loading
          ? Padding(
              padding: const EdgeInsets.all(16.0),
              child: _hasJoined
                  ? ElevatedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.check_circle),
                      label: const Text("Already Joined"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: () => _joinRequest(context),
                      icon: const Icon(Icons.volunteer_activism),
                      label: const Text("Join This Opportunity"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
            )
          : null,
    );
  }
}
