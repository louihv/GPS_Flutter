import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_application/styles/global_styles.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import '../constants/theme.dart';
import '../styles/orgrequest_styles.dart';

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
        SnackBar(
          content: Text('Please fill out all required fields and select a location.', style: OrgRequestStyles.output),
          backgroundColor: ThemeConstants.accent,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.info, color: ThemeConstants.primary),
            const SizedBox(width: OrgRequestStyles.spacingXSmall),
            Text('Confirm Submission', style: GlobalStyles.header),
          ],
        ),
        content: Text('Are you sure you want to submit this volunteer request?', style: OrgRequestStyles.output),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: OrgRequestStyles.output),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Submit', style: OrgRequestStyles.output),
            style: ElevatedButton.styleFrom(
              backgroundColor: ThemeConstants.accentBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(OrgRequestStyles.borderRadiusMedium),
              ),
            ),
          ),
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
      SnackBar(
        content: Text('Volunteer request submitted!', style: OrgRequestStyles.output),
        backgroundColor: Colors.green,
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
      labelStyle: OrgRequestStyles.subtitle,
      prefixIcon: icon != null ? Icon(icon, color: ThemeConstants.primary) : null,
      border: InputBorder.none,
      contentPadding: const EdgeInsets.symmetric(
          vertical: OrgRequestStyles.spacingMedium, horizontal: OrgRequestStyles.spacingMedium),
    );
  }

  Widget _buildSkillChips() {
    return Wrap(
      spacing: OrgRequestStyles.spacingXSmall,
      children: skillsMap.keys.map((skill) {
        final selected = skillsMap[skill]!;
        return ChoiceChip(
          label: Text(skill, style: OrgRequestStyles.output),
          selected: selected,
          selectedColor: ThemeConstants.accent,
          backgroundColor: Colors.grey[200],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(OrgRequestStyles.borderRadiusMedium),
          ),
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomRight,
            colors: [Color(0x6614AEBB), Color(0xFFFFF9F0)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(OrgRequestStyles.spacingMedium),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 650),
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(OrgRequestStyles.borderRadiusLarge)),
                  child: Padding(
                    padding: const EdgeInsets.all(OrgRequestStyles.spacingLarge),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            "Relief Operations Volunteer Request",
                            textAlign: TextAlign.center,
                            style: GlobalStyles.header,
                          ),
                          const SizedBox(height: OrgRequestStyles.spacingXSmall),
                          Text(
                            "Angat Buhay Tayong Lahat! Join us in making a difference by requesting volunteers for your relief operations. Fill out the form below with the necessary details, and together, we can bring hope and assistance to those in need.",
                            textAlign: TextAlign.center,
                            style: OrgRequestStyles.subtitle,
                          ),
                          const SizedBox(height: OrgRequestStyles.spacingLarge),

                          // Event Name
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: ThemeConstants.placeholder),
                              borderRadius: BorderRadius.circular(OrgRequestStyles.borderRadiusXLarge),
                              
                            ),
                            child: TextFormField(
                              controller: nameController,
                              decoration: _inputDecoration('Event Name', icon: Icons.event).copyWith(
                              filled: true,
                              fillColor: Colors.transparent, 
                              border: InputBorder.none,      
                            ),
                              style: OrgRequestStyles.output,
                              validator: (v) => v!.isEmpty ? 'Enter event name' : null,
                            ),
                          ),
                          const SizedBox(height: OrgRequestStyles.spacingMedium),

                          // Description
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: ThemeConstants.placeholder),
                              borderRadius: BorderRadius.circular(OrgRequestStyles.borderRadiusXLarge),
                            ),
                            child: TextFormField(
                              controller: descController,
                              decoration: _inputDecoration('Description', icon: Icons.description).copyWith(
                              filled: true,
                              fillColor: Colors.transparent,
                              border: InputBorder.none,     
                              ),    
                              style: OrgRequestStyles.output,
                              validator: (v) => v!.isEmpty ? 'Enter description' : null,
                              maxLines: 2,
                            ),
                          ),
                          const SizedBox(height: OrgRequestStyles.spacingMedium),

                          // Address
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: ThemeConstants.placeholder),
                              borderRadius: BorderRadius.circular(OrgRequestStyles.borderRadiusXLarge),
                            ),
                            child: TextFormField(
                              controller: addressController,
                              decoration: _inputDecoration('Location', icon: Icons.location_on).copyWith(
                              filled: true,
                              fillColor: Colors.transparent,
                              border: InputBorder.none,     
                              ),
                              style: OrgRequestStyles.output,
                              readOnly: true,
                            ),
                          ),
                          const SizedBox(height: OrgRequestStyles.spacingMedium),

                          // Map
                          ClipRRect(
                            borderRadius: BorderRadius.circular(OrgRequestStyles.borderRadiusMedium),
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
                                          child: const Icon(Icons.location_pin, color: ThemeConstants.accent, size: 40),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: OrgRequestStyles.spacingMedium),

                          // Skills Chips
                          Text('Required Skills', style: OrgRequestStyles.output.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: OrgRequestStyles.spacingXSmall),
                          _buildSkillChips(),
                          const SizedBox(height: OrgRequestStyles.spacingMedium),

                          // Date
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: ThemeConstants.placeholder),
                              borderRadius: BorderRadius.circular(OrgRequestStyles.borderRadiusXLarge),
                            ),
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
                              decoration: _inputDecoration('Date', icon: Icons.calendar_today).copyWith(
                              filled: true,
                              fillColor: Colors.transparent,
                              border: InputBorder.none,     
                              ),
                              style: OrgRequestStyles.output,
                              validator: (v) => v!.isEmpty ? 'Enter date' : null,
                            ),
                          ),
                          const SizedBox(height: OrgRequestStyles.spacingMedium),

                          // Time
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: ThemeConstants.placeholder),
                              borderRadius: BorderRadius.circular(OrgRequestStyles.borderRadiusXLarge),
                            ),
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
                              decoration: _inputDecoration('Time', icon: Icons.access_time).copyWith(
                              filled: true,
                              fillColor: Colors.transparent,
                              border: InputBorder.none,     
                              ),
                              style: OrgRequestStyles.output,
                              validator: (v) => v!.isEmpty ? 'Enter time' : null,
                            ),
                          ),
                          const SizedBox(height: OrgRequestStyles.spacingMedium),

                          // Number of Volunteers
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: ThemeConstants.placeholder),
                              borderRadius: BorderRadius.circular(OrgRequestStyles.borderRadiusXLarge),
                            ),
                            child: TextFormField(
                              controller: numberController,
                              decoration: _inputDecoration('Number of Volunteers Needed', icon: Icons.people).copyWith(
                              filled: true,
                              fillColor: Colors.transparent,
                              border: InputBorder.none,     
                              ),
                              style: OrgRequestStyles.output,
                              keyboardType: TextInputType.number,
                              validator: (v) => v!.isEmpty ? 'Enter number of volunteers' : null,
                            ),
                          ),
                          const SizedBox(height: OrgRequestStyles.spacingLarge),

                          // Submit button
                          ElevatedButton.icon(
                            onPressed: _isFormValid() && !_submitting ? _submitForm : null,
                            icon: const Icon(Icons.send_rounded, color: Colors.white),
                            label: Text('Submit Request', style: OrgRequestStyles.output),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: OrgRequestStyles.spacingMedium),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(OrgRequestStyles.borderRadiusMedium)),
                              backgroundColor: ThemeConstants.accentBlue,
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
        ),
      ),
    );
  }
}