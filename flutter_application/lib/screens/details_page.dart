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
  bool _joining = false;
  bool _loading = true;

  int _joinedCount = 0;
  late DatabaseReference _applicantsRef;
  late Stream<DatabaseEvent> _applicantsStream;

  @override
  void initState() {
    super.initState();
    _applicantsRef = FirebaseDatabase.instance
        .ref('volunteer_requests/${widget.request['id']}/applicants');
    _applicantsStream = _applicantsRef.onValue;

    _listenApplicants();
    _checkIfJoined();
  }

  void _listenApplicants() {
    _applicantsStream.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      setState(() {
        _joinedCount = data?.length ?? 0;
      });
    });
  }

  Future<void> _checkIfJoined() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snapshot = await _applicantsRef.child(user.uid).get();
    if (snapshot.exists) {
      setState(() {
        _hasJoined = true;
      });
    }
    setState(() => _loading = false);
  }

  Future<void> _joinRequest(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Confirm Join"),
        content: const Text(
            "Are you sure you want to join this volunteer opportunity?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Join")),
        ],
      ),
    );

    if (confirmed != true) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to join.')),
      );
      return;
    }

    setState(() => _joining = true);

    try {
      await _applicantsRef.child(user.uid).set({
        'email': user.email ?? 'No email',
        'joinedAt': DateTime.now().toIso8601String(),
        'status': 'pending',
      });

      setState(() {
        _hasJoined = true;
        _joining = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'You’ve joined "${widget.request['eventName']}" successfully!'),
          backgroundColor: Colors.green.shade600,
        ),
      );
    } catch (e) {
      setState(() => _joining = false);
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
                        fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(widget.request['description'] ?? 'No description provided.'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.group, color: Colors.blueAccent),
                      const SizedBox(width: 6),
                      Text(
                          "Volunteers needed: ${widget.request['numberNeeded'] ?? 'N/A'}"),
                      const SizedBox(width: 16),
                      const Icon(Icons.person, color: Colors.green),
                      const SizedBox(width: 6),
                      Text("Joined: $_joinedCount"),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text("Skills Required:",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: (widget.request['skillsRequired'] as List?)
                            ?.map((s) => Chip(
                                  label: Text(s.toString(),
                                      style: const TextStyle(color: Colors.white)),
                                  backgroundColor: Colors.teal,
                                ))
                            .toList() ?? [const Text('None listed')],
                  ),
                  const SizedBox(height: 24),
                  if (latitude != null && longitude != null) ...[
                    Text("Event Location Map:",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.black87)),
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
                              userAgentPackageName: 'com.example.bayanihan_connect',
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
              child: ElevatedButton.icon(
                onPressed: _hasJoined || _joining
                    ? null
                    : () => _joinRequest(context),
                icon: _joining
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(_hasJoined ? Icons.check_circle : Icons.volunteer_activism),
                label: Text(_hasJoined
                    ? "Already Joined"
                    : _joining
                        ? "Joining..."
                        : "Join This Opportunity"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _hasJoined ? Colors.grey : Colors.teal,
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
