import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/theme.dart';
import '../styles/volunteermap_styles.dart';

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
  List<Marker> filteredEventMarkers = [];
  List<Marker> filteredVolunteerMarkers = [];
  bool showVolunteers = false;
  int totalEvents = 0;
  int totalVolunteers = 0;
  String searchQuery = '';

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
            child: const Icon(Icons.flag, color: ThemeConstants.accent, size: 36),
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
                      color: ThemeConstants.accentBlue, size: 34),
                ),
              ));
            }
          }
        }
      }

      setState(() {
        eventMarkers = eventList;
        volunteerMarkers = volunteerList;
        filteredEventMarkers = eventList;
        filteredVolunteerMarkers = volunteerList;
        totalEvents = eventList.length;
        totalVolunteers = volunteerCount;
      });
    });
  }

  void _filterMarkers(String query) {
    setState(() {
      searchQuery = query;
      if (query.isEmpty) {
        filteredEventMarkers = eventMarkers;
        filteredVolunteerMarkers = volunteerMarkers;
      } else {
        filteredEventMarkers = eventMarkers.where((marker) {
          final eventData = marker.child is GestureDetector
              ? (marker.child as GestureDetector).child is Icon
                  ? marker // Assuming event markers have Icon as child
                  : null
              : null;
          if (eventData == null) return false;
          // Access event data from the marker's associated data
          final eventName = (marker as dynamic).eventData?['eventName']?.toString().toLowerCase() ?? '';
          return eventName.contains(query.toLowerCase());
        }).toList();

        filteredVolunteerMarkers = volunteerMarkers.where((marker) {
          final volunteerData = marker.child is GestureDetector
              ? (marker.child as GestureDetector).child is Icon
                  ? marker
                  : null
              : null;
          if (volunteerData == null) return false;
          final email = (marker as dynamic).applicantData?['email']?.toString().toLowerCase() ?? '';
          return email.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  void _showEventDetails(Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(MapStyles.borderRadiusLarge))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(MapStyles.spacingMedium),
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.flag, color: ThemeConstants.accent),
            title: Text(data['eventName'] ?? 'Unnamed Event',
                style: MapStyles.output.copyWith(fontWeight: FontWeight.bold)),
            subtitle: Text(data['description'] ?? 'No description available.', style: MapStyles.subtitle),
          ),
          const SizedBox(height: MapStyles.spacingSmall),
          Row(
            children: [
              const Icon(Icons.location_on, color: ThemeConstants.placeholder),
              const SizedBox(width: MapStyles.spacingXSmall),
              Text(
                  'Lat: ${data['latitude']}, Lng: ${data['longitude']}',
                  style: MapStyles.subtitle),
            ],
          ),
          const SizedBox(height: MapStyles.spacingSmall),
          Text(
              "Applicants: ${(data['applicants'] as Map?)?.length ?? 0}",
              style: MapStyles.output.copyWith(color: ThemeConstants.accentBlue)),
        ]),
      ),
    );
  }

  void _showVolunteerDetails(Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(MapStyles.borderRadiusLarge))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(MapStyles.spacingMedium),
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.person, color: ThemeConstants.accentBlue),
            title: Text(data['email'] ?? 'Anonymous Volunteer',
                style: MapStyles.output.copyWith(fontWeight: FontWeight.bold)),
            subtitle: Text('Status: ${data['status'] ?? 'Pending'}', style: MapStyles.subtitle),
          ),
          if (data['latitude'] != null)
            Text(
              'Location: (${data['latitude']}, ${data['longitude']})',
              style: MapStyles.subtitle,
            ),
        ]),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(
          vertical: MapStyles.spacingMedium, horizontal: MapStyles.spacingLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Volunteer Map Overview', style: MapStyles.header),
          const SizedBox(height: MapStyles.spacingXSmall),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatBox(Icons.flag, "Events", totalEvents, ThemeConstants.accent),
              _buildStatBox(Icons.people, "Volunteers", totalVolunteers, ThemeConstants.accentBlue),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox(IconData icon, String label, int count, Color color) {
    return Row(
      children: [
        CircleAvatar(
            backgroundColor: color.withOpacity(0.2), child: Icon(icon, color: color)),
        const SizedBox(width: MapStyles.spacingSmall),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(count.toString(),
                style: MapStyles.output.copyWith(
                    color: color, fontWeight: FontWeight.bold, fontSize: 18)),
            Text(label, style: MapStyles.subtitle),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final markersToShow = showVolunteers ? filteredVolunteerMarkers : filteredEventMarkers;

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
          child: Column(
            children: [
              _buildHeader(),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: MapStyles.spacingSmall, vertical: MapStyles.spacingXSmall),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: ThemeConstants.placeholder),
                    borderRadius: BorderRadius.circular(MapStyles.borderRadiusXLarge),
                  ),
                  child: TextField(
                    onChanged: _filterMarkers,
                    style: MapStyles.output,
                    decoration: InputDecoration(
                      labelText: showVolunteers ? 'Search volunteers...' : 'Search events...',
                      labelStyle: MapStyles.subtitle,
                      prefixIcon: const Icon(Icons.search, color: ThemeConstants.primary),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: MapStyles.spacingMedium, horizontal: MapStyles.spacingMedium),
                    ),
                  ),
                ),
              ),
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
                          decoration: BoxDecoration(
                            color: ThemeConstants.accentBlue,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            cluster.length.toString(),
                            style: MapStyles.output.copyWith(
                                color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          setState(() {
            showVolunteers = !showVolunteers;
            searchQuery = '';
            filteredEventMarkers = eventMarkers;
            filteredVolunteerMarkers = volunteerMarkers;
            _mapController.move(const LatLng(14.5995, 120.9842), 6);
          });
        },
        label: Text(
          showVolunteers ? "Show Events" : "Show Volunteers",
          style: MapStyles.output.copyWith(color: Colors.white),
        ),
        icon: Icon(
          showVolunteers ? Icons.flag : Icons.people_alt,
          color: Colors.white,
        ),
        backgroundColor: ThemeConstants.accentBlue,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MapStyles.borderRadiusMedium),
        ),
      ),
    );
  }
}