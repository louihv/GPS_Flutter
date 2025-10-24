import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/theme.dart';
import '../styles/mappage_styles.dart';
import 'details_page.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

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
  LatLng center = const LatLng(14.5995, 120.9842);
  LatLng? userLocation;
  bool followUser = true;

  // Stream subscriptions
  StreamSubscription<DatabaseEvent>? _dbSubscription;
  StreamSubscription<Position>? _locationSubscription;

  @override
  void initState() {
    super.initState();
    _fetchRequests();
    _getUserLocation();
  }

  @override
  void dispose() {
    _dbSubscription?.cancel();
    _locationSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _getUserLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enable location services.', style: MapPageStyles.output),
          backgroundColor: ThemeConstants.accent,
        ),
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location permission denied.', style: MapPageStyles.output),
            backgroundColor: ThemeConstants.accent,
          ),
        );
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Location permission permanently denied.', style: MapPageStyles.output),
          backgroundColor: ThemeConstants.accent,
        ),
      );
      return;
    }

    try {
      // Get initial position
      Position pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      if (!mounted) return;
      setState(() {
        userLocation = LatLng(pos.latitude, pos.longitude);
        if (followUser) {
          center = userLocation!;
          _mapController.move(center, 14);
        }
      });

      // Cancel any previous stream
      await _locationSubscription?.cancel();

      // Start live location updates
      _locationSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      ).listen((pos) {
        if (!mounted) return;
        setState(() {
          userLocation = LatLng(pos.latitude, pos.longitude);
          if (followUser) {
            _mapController.move(userLocation!, 14);
          }
        });
      });
    } catch (e) {
      print('Location error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Location error: $e', style: MapPageStyles.output),
          backgroundColor: ThemeConstants.accent,
        ),
      );
    }
  }

  void _fetchRequests() {
    _dbSubscription?.cancel();

    _dbSubscription = _dbRef.onValue.listen((event) {
      if (!mounted) return;

      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return;

      final fetched = data.entries.map((entry) {
        final req = Map<String, dynamic>.from(entry.value);
        req['id'] = entry.key;

        if (userLocation != null &&
            req['latitude'] != null &&
            req['longitude'] != null) {
          req['distance'] = _calculateDistance(
            userLocation!.latitude,
            userLocation!.longitude,
            req['latitude'].toDouble(),
            req['longitude'].toDouble(),
          );
        } else {
          req['distance'] = double.infinity;
        }
        return req;
      }).toList();

      if (!mounted) return;
      setState(() {
        requests = fetched;
        filteredRequests = fetched;
      });
    });
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)); // km
  }

  void _filterRequests(String query) {
    final lowerQuery = query.toLowerCase();
    if (!mounted) return;
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

  void _openDetails(Map<String, dynamic> req) {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetailsPage(request: req),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final markers = filteredRequests.map((req) {
      final lat = req['latitude']?.toDouble();
      final lng = req['longitude']?.toDouble();
      if (lat == null || lng == null) return null;

      Color color = ThemeConstants.primary;
      final dist = req['distance'] as double?;
      if (dist != null && dist <= 5) {
        color = ThemeConstants.accent;
      } else if (dist != null && dist <= 15) {
        color = ThemeConstants.accentBlue;
      }

      return Marker(
        point: LatLng(lat, lng),
        width: 50,
        height: 50,
        child: GestureDetector(
          onTap: () => _openDetails(req),
          child: Icon(Icons.location_pin, color: color, size: 40),
        ),
      );
    }).whereType<Marker>().toList();

    if (userLocation != null) {
      markers.add(Marker(
        point: userLocation!,
        width: 40,
        height: 40,
        child: const Icon(Icons.person_pin_circle, color: ThemeConstants.accentBlue, size: 40),
      ));
    }

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
              Padding(
                padding: const EdgeInsets.all(MapPageStyles.spacingMedium),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Volunteer Map', style: MapPageStyles.header),
                    const SizedBox(height: MapPageStyles.spacingXSmall),
                    Text(
                      '${filteredRequests.length} Request(s)',
                      style: MapPageStyles.subtitle,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: MapPageStyles.spacingSmall, vertical: MapPageStyles.spacingXSmall),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: ThemeConstants.placeholder),
                    borderRadius: BorderRadius.circular(MapPageStyles.borderRadiusXLarge),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _filterRequests,
                    style: MapPageStyles.output,
                    decoration: InputDecoration(
                      labelText: 'Search events, skills, or locations...',
                      labelStyle: MapPageStyles.subtitle,
                      prefixIcon: const Icon(Icons.search, color: ThemeConstants.primary),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: MapPageStyles.spacingMedium, horizontal: MapPageStyles.spacingMedium),
                    ),
                  ),
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
                          decoration: BoxDecoration(
                            color: ThemeConstants.accentBlue,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            cluster.length.toString(),
                            style: MapPageStyles.output.copyWith(color: Colors.white),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (!mounted) return;
          setState(() => followUser = !followUser);
          if (followUser && userLocation != null) {
            _mapController.move(userLocation!, 14);
          }
        },
        backgroundColor: followUser ? ThemeConstants.accentBlue : ThemeConstants.placeholder,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MapPageStyles.borderRadiusMedium),
        ),
        child: Icon(
          followUser ? Icons.my_location : Icons.location_disabled,
          color: Colors.white,
        ),
      ),
    );
  }
}