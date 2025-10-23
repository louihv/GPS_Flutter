import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_database/firebase_database.dart';

class AdminVolunteerMap extends StatefulWidget {
  const AdminVolunteerMap({Key? key}) : super(key: key);

  @override
  State<AdminVolunteerMap> createState() => _AdminVolunteerMapState();
}

class _AdminVolunteerMapState extends State<AdminVolunteerMap> {
  final MapController _mapController = MapController();
  final DatabaseReference _dbRef =
      FirebaseDatabase.instance.ref('volunteer_requests');

  List<Marker> eventMarkers = [];
  List<Marker> volunteerMarkers = [];
  bool showVolunteers = false;
  int totalEvents = 0;
  int totalVolunteers = 0;

  @override
  void initState() {
    super.initState();
    _fetchMapData();
  }

  void _fetchMapData() {
    _dbRef.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;

      if (data == null) return;

      List<Marker> eventList = [];
      List<Marker> volunteerList = [];
      int volunteerCount = 0;

      for (var entry in data.entries) {
        final eventData = Map<String, dynamic>.from(entry.value);
        final lat = eventData['latitude']?.toDouble();
        final lng = eventData['longitude']?.toDouble();
        if (lat == null || lng == null) continue;

        // Event marker
        eventList.add(Marker(
          point: LatLng(lat, lng),
          width: 45,
          height: 45,
          child: GestureDetector(
            onTap: () => _showEventDetails(eventData),
            child: const Icon(Icons.flag, color: Colors.redAccent, size: 36),
          ),
        ));

        // Volunteer markers
        final applicants = eventData['applicants'] as Map<dynamic, dynamic>?;
        if (applicants != null) {
          volunteerCount += applicants.length;
          for (var applicant in applicants.values) {
            final applicantData = Map<String, dynamic>.from(applicant);
            final vLat = applicantData['latitude']?.toDouble();
            final vLng = applicantData['longitude']?.toDouble();
            if (vLat != null && vLng != null) {
              volunteerList.add(Marker(
                point: LatLng(vLat, vLng),
                width: 40,
                height: 40,
                child: GestureDetector(
                  onTap: () => _showVolunteerDetails(applicantData),
                  child: const Icon(Icons.person_pin_circle,
                      color: Colors.teal, size: 34),
                ),
              ));
            }
          }
        }
      }

      setState(() {
        eventMarkers = eventList;
        volunteerMarkers = volunteerList;
        totalEvents = eventList.length;
        totalVolunteers = volunteerCount;
      });
    });
  }

  void _showEventDetails(Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.flag, color: Colors.redAccent),
            title: Text(data['eventName'] ?? 'Unnamed Event',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(data['description'] ?? 'No description available.'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                  'Lat: ${data['latitude']}, Lng: ${data['longitude']}',
                  style: const TextStyle(fontSize: 13, color: Colors.black54)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
              "Applicants: ${(data['applicants'] as Map?)?.length ?? 0}",
              style: const TextStyle(color: Colors.teal)),
        ]),
      ),
    );
  }

  void _showVolunteerDetails(Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.person, color: Colors.teal),
            title: Text(data['email'] ?? 'Anonymous Volunteer',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Status: ${data['status'] ?? 'Pending'}'),
          ),
          if (data['latitude'] != null)
            Text(
              'Location: (${data['latitude']}, ${data['longitude']})',
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
        ]),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      decoration: const BoxDecoration(
        color: Color(0xFFFA3B99),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStatBox(Icons.flag, "Events", totalEvents, Colors.redAccent),
          _buildStatBox(Icons.people, "Volunteers", totalVolunteers, const Color.fromARGB(255, 255, 255, 255)),
        ],
      ),
    );
  }

  Widget _buildStatBox(IconData icon, String label, int count, Color color) {
    return Row(
      children: [
        CircleAvatar(backgroundColor: color.withOpacity(0.2), child: Icon(icon, color: color)),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(count.toString(),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final markersToShow = showVolunteers ? volunteerMarkers : eventMarkers;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Volunteer Map Overview',style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
        backgroundColor: Color(0xFF14AEBB),
        actions: [
          IconButton(
            tooltip: showVolunteers ? "Show Events" : "Show Volunteers",
            icon: Icon(showVolunteers ? Icons.flag : Icons.people_alt),
            onPressed: () {
              setState(() => showVolunteers = !showVolunteers);
              _mapController.move(LatLng(14.5995, 120.9842), 6);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: const MapOptions(
                initialCenter: LatLng(14.5995, 120.9842),
                initialZoom: 6.3,
              ),
              children: [
                TileLayer(
                  urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                  userAgentPackageName: 'com.example.app',
                ),
                MarkerClusterLayerWidget(
                  options: MarkerClusterLayerOptions(
                    markers: markersToShow,
                    maxClusterRadius: 45,
                    size: const Size(45, 45),
                    builder: (context, cluster) => Container(
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Colors.teal,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        cluster.length.toString(),
                        style:
                            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => setState(() => showVolunteers = !showVolunteers),
        label: Text(showVolunteers ? "Show Events" : "Show Volunteers"),
        icon: Icon(showVolunteers ? Icons.flag : Icons.people_alt),
        backgroundColor: Colors.teal,
      ),
    );
  }
}
