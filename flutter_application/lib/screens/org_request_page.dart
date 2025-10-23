import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_database/firebase_database.dart';

class OrgRequestPage extends StatefulWidget {
  const OrgRequestPage({super.key});

  @override
  State<OrgRequestPage> createState() => _OrgRequestPageState();
}

class _OrgRequestPageState extends State<OrgRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final _db = FirebaseDatabase.instance.ref().child('volunteer_requests');

  // Controllers
  final nameController = TextEditingController();
  final descController = TextEditingController();
  final skillsController = TextEditingController();
  final dateController = TextEditingController();
  final timeController = TextEditingController();
  final numberController = TextEditingController();
  final addressController = TextEditingController();

  LatLng? selectedLocation;
  final MapController mapController = MapController();

  // Submit Function
  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      final data = {
        "eventName": nameController.text,
        "description": descController.text,
        "skillsRequired": skillsController.text.split(','),
        "date": dateController.text,
        "time": timeController.text,
        "numberNeeded": int.tryParse(numberController.text) ?? 0,
        "address": addressController.text,
        "latitude": selectedLocation?.latitude ?? '',
        "longitude": selectedLocation?.longitude ?? '',
        "timestamp": DateTime.now().toIso8601String(),
      };

      await _db.push().set(data);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Volunteer request submitted!'),
          backgroundColor: Color(0xFF14AEBB),
        ),
      );

      _formKey.currentState!.reset();
      setState(() => selectedLocation = null);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill out all fields.'),
          backgroundColor: Color(0xFFFA3B99),
        ),
      );
    }
  }

  InputDecoration _inputDecoration(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon, color: const Color(0xFF14AEBB)) : null,
      filled: true,
      fillColor: const Color(0xFFFDFBF9),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFCCCCCC), width: 0.8),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFFA3B99), width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: const Text(
          'Volunteer Request Form',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'Poppins',
          ),
        ),
        backgroundColor: const Color(0xFF14AEBB),
        centerTitle: true,
        elevation: 4,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 650),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              color: const Color(0xFFFFFFFF),
              shadowColor: Colors.black12,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Column(
                        children: const [
                          Text(
                            "Angat Buhay Volunteer Request",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF14AEBB),
                              fontFamily: 'Poppins',
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            "Mobilize help. Empower communities. Together, we rise.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF9E9E9E),
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Fields
                      TextFormField(
                        controller: nameController,
                        decoration: _inputDecoration('Event Name', icon: Icons.event),
                        validator: (v) => v!.isEmpty ? 'Enter event name' : null,
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: descController,
                        decoration: _inputDecoration('Description', icon: Icons.description),
                        validator: (v) => v!.isEmpty ? 'Enter description' : null,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: addressController,
                        decoration: _inputDecoration('Location (address or coordinates)', icon: Icons.location_on),
                        validator: (v) => v!.isEmpty ? 'Enter location' : null,
                      ),
                      const SizedBox(height: 14),

                      // Map
                      ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: SizedBox(
                          height: 250,
                          child: FlutterMap(
                            mapController: mapController,
                            options: MapOptions(
                              initialCenter: const LatLng(14.5995, 120.9842),
                              initialZoom: 11,
                              onTap: (tapPosition, point) {
                                setState(() {
                                  selectedLocation = point;
                                  addressController.text =
                                      "Lat: ${point.latitude.toStringAsFixed(5)}, Lng: ${point.longitude.toStringAsFixed(5)}";
                                });
                              },
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                              ),
                              if (selectedLocation != null)
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: selectedLocation!,
                                      width: 50,
                                      height: 50,
                                      child: const Icon(
                                        Icons.location_pin,
                                        color: Color(0xFFFA3B99),
                                        size: 40,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),
                      TextFormField(
                        controller: skillsController,
                        decoration: _inputDecoration('Required Skills (comma-separated)', icon: Icons.build),
                        validator: (v) => v!.isEmpty ? 'Enter required skills' : null,
                      ),
                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: dateController,
                              decoration: _inputDecoration('Date (e.g., 2025-10-25)', icon: Icons.calendar_today),
                              validator: (v) => v!.isEmpty ? 'Enter date' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: timeController,
                              decoration: _inputDecoration('Time (e.g., 10:00 AM)', icon: Icons.access_time),
                              validator: (v) => v!.isEmpty ? 'Enter time' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: numberController,
                        decoration: _inputDecoration('Number of Volunteers Needed', icon: Icons.people),
                        keyboardType: TextInputType.number,
                        validator: (v) => v!.isEmpty ? 'Enter number of volunteers' : null,
                      ),
                      const SizedBox(height: 28),

                      // Gradient button
                      GestureDetector(
                        onTap: _submitForm,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF14AEBB), Color(0xFFFA3B99)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.send_rounded, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                "Submit Request",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
