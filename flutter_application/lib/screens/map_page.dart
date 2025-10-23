import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:geolocator/geolocator.dart';

class MapPage extends StatefulWidget {
  const MapPage({Key? key}) : super(key: key);

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final DatabaseReference _dbRef =
      FirebaseDatabase.instance.ref().child('volunteer_requests');

  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> requests = [];
  List<Map<String, dynamic>> filteredRequests = [];
  LatLng center = const LatLng(14.5995, 120.9842); // Default Manila
  LatLng? userLocation;

  final PopupController _popupController = PopupController();

  @override
  void initState() {
    super.initState();
    _fetchRequests();
    _getUserLocation();
  }

  Future<void> _getUserLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

    setState(() {
      userLocation = LatLng(pos.latitude, pos.longitude);
      center = userLocation!;
    });

    Geolocator.getPositionStream(
            locationSettings:
                const LocationSettings(accuracy: LocationAccuracy.high))
        .listen((pos) {
      setState(() {
        userLocation = LatLng(pos.latitude, pos.longitude);
      });
    });
  }

  void _fetchRequests() {
    _dbRef.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        final fetched = data.entries.map((entry) {
          final req = Map<String, dynamic>.from(entry.value);
          req['id'] = entry.key;
          return req;
        }).toList();
        setState(() {
          requests = fetched;
          filteredRequests = fetched;
        });
      }
    });
  }

  void _filterRequests(String query) {
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

  void _showRequestPopup(Map<String, dynamic> req) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
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
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              Text(req['eventName'] ?? 'No Title',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(req['description'] ?? 'No description provided.'),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.redAccent),
                  const SizedBox(width: 6),
                  Expanded(child: Text(req['address'] ?? 'No address')),
                ],
              ),
              const SizedBox(height: 6),
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
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.group, color: Colors.blueAccent),
                  const SizedBox(width: 6),
                  Text("Volunteers needed: ${req['numberNeeded'] ?? 'N/A'}"),
                ],
              ),
              const SizedBox(height: 12),
              Text("Skills Required:",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: (req['skillsRequired'] as List?)
                        ?.map((s) => Chip(
                              label: Text(s.toString(),
                                  style:
                                      const TextStyle(color: Colors.white)),
                              backgroundColor: Colors.teal,
                            ))
                        .toList() ??
                    [const Text('None listed')],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final markers = filteredRequests.map((req) {
      final lat = req['latitude']?.toDouble();
      final lng = req['longitude']?.toDouble();
      if (lat == null || lng == null) return null;
      return Marker(
        point: LatLng(lat, lng),
        width: 50,
        height: 50,
        child: GestureDetector(
          onTap: () => _showRequestPopup(req),
          child:
              const Icon(Icons.location_pin, color: Colors.redAccent, size: 40),
        ),
      );
    }).whereType<Marker>().toList();

    if (userLocation != null) {
      markers.add(Marker(
        point: userLocation!,
        width: 40,
        height: 40,
        child: const Icon(Icons.person_pin_circle, color: Colors.blue, size: 40),
      ));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Volunteer Map'),
        backgroundColor: Colors.teal,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                  hintText: 'Search by event, skill, or location',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder()),
              onChanged: _filterRequests,
            ),
          ),
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: 13,
                maxZoom: 18,
                minZoom: 3,
              ),
              children: [
                TileLayer(
                  urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                  userAgentPackageName: 'com.example.app',
                ),
                MarkerClusterLayerWidget(
                  options: MarkerClusterLayerOptions(
                    markers: markers,
                    maxClusterRadius: 50,
                    size: const Size(40, 40),
                    builder: (context, cluster) => Container(
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Colors.teal,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        cluster.length.toString(),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (userLocation != null) {
            _mapController.move(userLocation!, 14);
          } else {
            _mapController.move(center, 11);
          }
        },
        backgroundColor: Colors.teal,
        child: const Icon(Icons.my_location),
      ),
    );
  }
}
