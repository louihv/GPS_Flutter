import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;

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
  final dateController = TextEditingController();
  final timeController = TextEditingController();
  final numberController = TextEditingController();
  final addressController = TextEditingController();

  LatLng? selectedLocation;
  final MapController mapController = MapController();

  Map<String, bool> skillsMap = {
    "Medical Aid": false,
    "Teaching": false,
    "Food Distribution": false,
    "Logistics": false,
    "IT Support": false,
  };

  bool _submitting = false;

  // Submit function
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate() || selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill out all required fields and select a location.'),
          backgroundColor: Color(0xFFFA3B99),
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Submission'),
        content: const Text('Are you sure you want to submit this volunteer request?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Submit')),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _submitting = true);

    final data = {
      "eventName": nameController.text,
      "description": descController.text,
      "skillsRequired": skillsMap.entries.where((e) => e.value).map((e) => e.key).toList(),
      "date": dateController.text,
      "time": timeController.text,
      "numberNeeded": int.tryParse(numberController.text) ?? 0,
      "address": addressController.text,
      "latitude": selectedLocation!.latitude,
      "longitude": selectedLocation!.longitude,
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
    setState(() {
      selectedLocation = null;
      skillsMap.updateAll((key, value) => false);
      _submitting = false;
      addressController.text = '';
    });
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

  Widget _buildSkillChips() {
    return Wrap(
      spacing: 8,
      children: skillsMap.keys.map((skill) {
        final selected = skillsMap[skill]!;
        return ChoiceChip(
          label: Text(skill),
          selected: selected,
          selectedColor: const Color(0xFFFA3B99),
          onSelected: (v) => setState(() => skillsMap[skill] = v),
        );
      }).toList(),
    );
  }

  bool _isFormValid() {
    return nameController.text.isNotEmpty &&
        descController.text.isNotEmpty &&
        dateController.text.isNotEmpty &&
        timeController.text.isNotEmpty &&
        numberController.text.isNotEmpty &&
        selectedLocation != null;
  }

  Future<void> _setAddressFromPoint(LatLng point) async {
    try {
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=${point.latitude}&lon=${point.longitude}');
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          addressController.text = data['display_name'] ?? '';
        });
      }
    } catch (e) {
      debugPrint('Error fetching address: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: const Text('Volunteer Request Form', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF14AEBB),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 650),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        "Relief Operations Volunteer Request",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFFA3B99)),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        "Angat Buhay Tayong Lahat! Join us in making a difference by requesting volunteers for your relief operations. Fill out the form below with the necessary details, and together, we can bring hope and assistance to those in need.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Color(0xFF9E9E9E)),
                      ),
                      const SizedBox(height: 24),

                      // Event Name
                      TextFormField(
                        controller: nameController,
                        decoration: _inputDecoration('Event Name', icon: Icons.event),
                        validator: (v) => v!.isEmpty ? 'Enter event name' : null,
                      ),
                      const SizedBox(height: 14),

                      // Description
                      TextFormField(
                        controller: descController,
                        decoration: _inputDecoration('Description', icon: Icons.description),
                        validator: (v) => v!.isEmpty ? 'Enter description' : null,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 14),

                      // Address
                      TextFormField(
                        controller: addressController,
                        decoration: _inputDecoration('Location', icon: Icons.location_on),
                        readOnly: true,
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
                                setState(() => selectedLocation = point);
                                _setAddressFromPoint(point);
                              },
                            ),
                            children: [
                              TileLayer(urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png"),
                              if (selectedLocation != null)
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: selectedLocation!,
                                      width: 50,
                                      height: 50,
                                      child: const Icon(Icons.location_pin, color: Color(0xFFFA3B99), size: 40),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Skills Chips
                      const Text('Required Skills', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF14AEBB))),
                      const SizedBox(height: 6),
                      _buildSkillChips(),
                      const SizedBox(height: 14),

                      // Date & Time
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: dateController,
                              readOnly: true,
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime(2100),
                                );
                                if (date != null) dateController.text = date.toIso8601String().split('T')[0];
                              },
                              decoration: _inputDecoration('Date', icon: Icons.calendar_today),
                              validator: (v) => v!.isEmpty ? 'Enter date' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: timeController,
                              readOnly: true,
                              onTap: () async {
                                final time = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay.now(),
                                );
                                if (time != null) timeController.text = time.format(context);
                              },
                              decoration: _inputDecoration('Time', icon: Icons.access_time),
                              validator: (v) => v!.isEmpty ? 'Enter time' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Number of Volunteers
                      TextFormField(
                        controller: numberController,
                        decoration: _inputDecoration('Number of Volunteers Needed', icon: Icons.people),
                        keyboardType: TextInputType.number,
                        validator: (v) => v!.isEmpty ? 'Enter number of volunteers' : null,
                      ),
                      const SizedBox(height: 28),

                      // Submit button
                      ElevatedButton.icon(
                        onPressed: _isFormValid() && !_submitting ? _submitForm : null,
                        icon: const Icon(Icons.send_rounded),
                        label: const Text('Submit Request'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          backgroundColor: const Color(0xFF14AEBB),
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
