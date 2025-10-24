import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart' as myAuth;
import '../constants/theme.dart';
import '../styles/register_styles.dart';
import 'package:intl/intl.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _middleInitialController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _nameExtensionController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileNumberController = TextEditingController();
  final _ageController = TextEditingController();
  final _socialMediaLinkController = TextEditingController();
  final _locationController = TextEditingController();
  final _otherSkillsController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final Map<String, bool> _disasterResponseSkills = {
    'First Aid & Basic Life Support': false,
    'Search & Rescue': false,
    'Evacuation Assistance': false,
    'Relief Goods Distribution': false,
    'On-the-ground responders': false,
  };
  final Map<String, bool> _transportationLogisticsSkills = {
    'Logistics & Supply Chain Management': false,
    'Transport Coordination': false,
    'Truck Driving': false,
    'Bus Driving': false,
    'Van / Shuttle Driving': false,
    'Motorcycle Delivery': false,
    'Forklift Operation': false,
  };
  final Map<String, bool> _medicalSkills = {
    'General Medicine': false,
    'Pediatrics': false,
    'Psychology / Mental Health': false,
    'Nursing': false,
    'Paramedic / EMT': false,
    'Pharmacy': false,
  };
  final Map<String, bool> _specializedSkills = {
    'Engineering / Construction': false,
    'Water, Sanitation & Hygiene': false,
    'Agricultural Recovery': false,
    'Animal Rescue & Care': false,
    'Information Technology': false,
  };

  final List<Map<String, TextEditingController>> _availability = [
    {
      'startDate': TextEditingController(),
      'endDate': TextEditingController(),
      'startTime': TextEditingController(),
      'endTime': TextEditingController(),
    }
  ];

  bool _afterHoursAvailable = false;
  bool _termsAgreed = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  String? _firstNameError;
  String? _lastNameError;
  String? _emailError;
  String? _mobileNumberError;
  String? _ageError;
  String? _socialMediaLinkError;
  String? _locationError;
  String? _skillsError;
  String? _termsError;
  String? _passwordError;
  String? _confirmPasswordError;

  Position? _location;
  LocationPermission? _permissionStatus;
  final MapController _mapController = MapController();

  final _auth = FirebaseAuth.instance;
  final _database = FirebaseDatabase.instance.ref();

  @override
  void initState() {
    super.initState();
    _checkPermissionStatus();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleInitialController.dispose();
    _lastNameController.dispose();
    _nameExtensionController.dispose();
    _emailController.dispose();
    _mobileNumberController.dispose();
    _ageController.dispose();
    _socialMediaLinkController.dispose();
    _locationController.dispose();
    _otherSkillsController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    for (var a in _availability) {
      a['startDate']!.dispose();
      a['endDate']!.dispose();
      a['startTime']!.dispose();
      a['endTime']!.dispose();
    }
    super.dispose();
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required.';
    if (value.length < 8) return 'Password must be at least 8 characters.';
    if (!RegExp(r'(?=.*[A-Z])').hasMatch(value)) {
      return 'Must contain an uppercase letter.';
    }
    if (!RegExp(r'(?=.*[a-z])').hasMatch(value)) {
      return 'Must contain a lowercase letter.';
    }
    if (!RegExp(r'(?=.*\d)').hasMatch(value)) {
      return 'Must contain a number.';
    }
    if (!RegExp(r'(?=.*[!@#\$%^&*])').hasMatch(value)) {
      return 'Must contain a special character (!@#\$%^&*).';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value != _passwordController.text) return 'Passwords do not match.';
    return null;
  }

  String? _validateFirstName(String? v) {
    if (v == null || v.isEmpty) return 'First name is required.';
    if (v.length < 2) return 'First name must be at least 2 characters.';
    return null;
  }

  String? _validateLastName(String? v) {
    if (v == null || v.isEmpty) return 'Last name is required.';
    if (v.length < 2) return 'Last name must be at least 2 characters.';
    return null;
  }

  String? _validateEmail(String? v) {
    if (v == null || v.isEmpty) return 'Email is required.';
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v)) {
      return 'Please enter a valid email address.';
    }
    return null;
  }

  String? _validateMobileNumber(String? v) {
    if (v == null || v.isEmpty) return 'Mobile number is required.';
    if (!RegExp(r'^\d{10,11}$').hasMatch(v)) {
      return 'Enter a valid mobile number (10-11 digits).';
    }
    return null;
  }

  String? _validateAge(String? v) {
    if (v == null || v.isEmpty) return 'Age is required.';
    final age = int.tryParse(v);
    if (age == null || age < 18) return 'Volunteers must be at least 18 years old.';
    return null;
  }

  String? _validateSocialMediaLink(String? v) {
    if (v == null || v.isEmpty) return null;
    if (!RegExp(r'^https?://(www\.)?facebook\.com/.+$').hasMatch(v)) {
      return 'Enter a valid Facebook profile URL.';
    }
    return null;
  }

  String? _validateLocation(String? v) {
    if (v == null || v.isEmpty) return 'Location is required.';
    return null;
  }

  String? _validateSkills() {
    final selected = [
      ..._disasterResponseSkills.entries.where((e) => e.value).map((e) => e.key),
      ..._transportationLogisticsSkills.entries.where((e) => e.value).map((e) => e.key),
      ..._medicalSkills.entries.where((e) => e.value).map((e) => e.key),
      ..._specializedSkills.entries.where((e) => e.value).map((e) => e.key),
      if (_otherSkillsController.text.trim().isNotEmpty)
        _otherSkillsController.text.trim(),
    ];
    if (selected.isEmpty) return 'At least one skill is required.';
    if (selected.length > 5) return 'Select up to 5 skills.';
    return null;
  }

  String? _validateTerms() {
    if (!_termsAgreed) return 'You must agree to the Terms and Conditions.';
    return null;
  }

  Future<bool> _emailExists(String email) async {
    try {
      final safe = email.toLowerCase().replaceAll('.', '_dot_').replaceAll('@', '_at_');
      final snap = await _database.child('users/emailIndex/$safe').get();
      return snap.exists;
    } catch (_) {
      return false;
    }
  }

  Future<void> _handleRegister(BuildContext ctx) async {
    final firstName = _firstNameController.text.trim();
    final middle = _middleInitialController.text.trim();
    final lastName = _lastNameController.text.trim();
    final ext = _nameExtensionController.text.trim();
    final email = _emailController.text.trim();
    final mobile = _mobileNumberController.text.trim();
    final age = _ageController.text.trim();
    final social = _socialMediaLinkController.text.trim();
    final location = _locationController.text.trim();
    final other = _otherSkillsController.text.trim();
    final password = _passwordController.text;

    final err = {
      _validateFirstName(firstName),
      _validateLastName(lastName),
      _validateEmail(email),
      _validateMobileNumber(mobile),
      _validateAge(age),
      _validateSocialMediaLink(social),
      _validateLocation(location),
      _validateSkills(),
      _validateTerms(),
      _validatePassword(password),
      _validateConfirmPassword(_confirmPasswordController.text),
    }.where((e) => e != null).toList();

    if (err.isNotEmpty) {
      if (mounted) {
        setState(() {
          _firstNameError = _validateFirstName(firstName);
          _lastNameError = _validateLastName(lastName);
          _emailError = _validateEmail(email);
          _mobileNumberError = _validateMobileNumber(mobile);
          _ageError = _validateAge(age);
          _socialMediaLinkError = _validateSocialMediaLink(social);
          _locationError = _validateLocation(location);
          _skillsError = _validateSkills();
          _termsError = _validateTerms();
          _passwordError = _validatePassword(password);
          _confirmPasswordError = _validateConfirmPassword(_confirmPasswordController.text);
        });
      }
      return;
    }

    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      // 1. Email already taken?
      if (await _emailExists(email)) {
        setState(() => _emailError = 'Email already in use.');
        Fluttertoast.showToast(msg: 'Email already registered. Please log in.');
        return;
      }

      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = cred.user!;
      final now = DateTime.now().millisecondsSinceEpoch;

      final selectedSkills = [
        ..._disasterResponseSkills.entries.where((e) => e.value).map((e) => e.key),
        ..._transportationLogisticsSkills.entries.where((e) => e.value).map((e) => e.key),
        ..._medicalSkills.entries.where((e) => e.value).map((e) => e.key),
        ..._specializedSkills.entries.where((e) => e.value).map((e) => e.key),
        if (other.isNotEmpty) other,
      ];
      final avail = _availability.map((a) => {
            'startDate': a['startDate']!.text,
            'endDate': a['endDate']!.text,
            'startTime': a['startTime']!.text,
            'endTime': a['endTime']!.text,
          }).toList();

      final volunteerData = {
        'firstName': firstName,
        'middleInitial': middle,
        'lastName': lastName,
        'nameExtension': ext,
        'email': email,
        'mobileNumber': mobile,
        'age': int.tryParse(age) ?? 0,
        'socialMediaLink': social,
        'location': {
          'address': location,
          'latitude': _location?.latitude ?? 0.0,
          'longitude': _location?.longitude ?? 0.0,
        },
        'skills': selectedSkills,
        'afterHoursAvailable': _afterHoursAvailable,
        'availability': avail,
        'createdAt': now,
        'role': 'ABVN',
        'isFirstLogin': true,
        'organization': 'ABVN',
      };

      final ref = _database.child('users').push();
      await ref.set(volunteerData);
      final safeEmail = email.replaceAll('.', '_dot_').replaceAll('@', '_at_');
      await _database.child('users/emailIndex/$safeEmail').set(user.uid);

      final fullName = '$firstName ${middle.isNotEmpty ? '$middle. ' : ''}$lastName${ext.isNotEmpty ? ' $ext' : ''}'.trim();
      

      Provider.of<myAuth.AuthProvider>(ctx, listen: false).setUser(user, volunteerData);
      Fluttertoast.showToast(
        msg: 'Registered! ',
      );
      if (mounted) Navigator.pushReplacementNamed(ctx, '/login');
    } on FirebaseAuthException catch (e) {
      String msg = 'Registration failed.';
      if (e.code == 'email-already-in-use') {
        setState(() => _emailError = 'Email already in use.');
      } else if (e.code == 'weak-password') {
        setState(() => _passwordError = 'Password is too weak.');
      } else {
        msg = e.message ?? msg;
      }
      Fluttertoast.showToast(msg: msg);
    } catch (e) {
      Fluttertoast.showToast(msg: 'Registration failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── UI HELPERS ───────────────────────────────────────────────────────────
  void _clearError(VoidCallback setter) {
    setter();
    if (mounted) setState(() {});
  }

  Widget _buildPasswordFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: RegisterStyles.inputMarginBottom),
        Text('Password', style: RegisterStyles.labelStyle),
        const SizedBox(height: RegisterStyles.xsmall),
        SizedBox(
          width: RegisterStyles.inputWidth,
          child: TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: RegisterStyles.inputStyle,
            decoration: RegisterStyles.inputDecoration(
              hintText: 'Enter strong password',
              errorText: _passwordError,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: ThemeConstants.primary,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            onChanged: (_) => _clearError(() => _passwordError),
            validator: _validatePassword,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Alphanumeric Characters(!@#\$%^&*)',
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),

        const SizedBox(height: RegisterStyles.inputMarginBottom),
        Text('Confirm Password', style: RegisterStyles.labelStyle),
        const SizedBox(height: RegisterStyles.xsmall),
        SizedBox(
          width: RegisterStyles.inputWidth,
          child: TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            style: RegisterStyles.inputStyle,
            decoration: RegisterStyles.inputDecoration(
              hintText: 'Re-enter password',
              errorText: _confirmPasswordError,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                  color: ThemeConstants.primary,
                ),
                onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
              ),
            ),
            onChanged: (_) => _clearError(() => _confirmPasswordError),
            validator: _validateConfirmPassword,
          ),
        ),
      ],
    );
  }

  Future<void> _checkPermissionStatus() async {
    try {
      setState(() => _isLoading = true);
      final permission = await Geolocator.checkPermission();
      if (mounted) {
        setState(() => _permissionStatus = permission);
      }
      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high);
        if (mounted) {
          setState(() {
            _location = position;
            if (position.accuracy > 50) {
              Fluttertoast.showToast(
                  msg: 'Location accuracy is low. The pin may not be precise.');
            }
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _permissionStatus = permission;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Permission check error: $e');
      if (mounted) {
        setState(() {
          _permissionStatus = LocationPermission.denied;
          _isLoading = false;
        });
      }
      Fluttertoast.showToast(
          msg: 'Failed to check location permission. Please enter location manually.');
    }
  }



  Future<void> _requestPermission() async {
    try {
      setState(() => _isLoading = true);
      final permission = await Geolocator.requestPermission();
      if (mounted) {
        setState(() => _permissionStatus = permission);
      }
      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high);
        if (mounted) {
          setState(() {
            _location = position;
            if (position.accuracy > 50) {
              Fluttertoast.showToast(
                  msg: 'Location accuracy is low. The pin may not be precise.');
            }
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        Fluttertoast.showToast(
            msg: 'Location access is required for map. Please enter location manually.');
      }
    } catch (e) {
      debugPrint('Permission request error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
      Fluttertoast.showToast(
          msg: 'Failed to request permission. Please enter location manually.');
    }
  }


  void _showMapModal() {
    if (_permissionStatus == LocationPermission.denied ||
        _permissionStatus == LocationPermission.deniedForever) {
      _requestPermission();
      return;
    }
    LatLng initialLocation = _location != null
        ? LatLng(_location!.latitude, _location!.longitude)
        : const LatLng(14.5995, 120.9842); // Default: Manila
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ThemeConstants.lightBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Select Location',
                style: RegisterStyles.labelStyle
                    .copyWith(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: initialLocation,
                    initialZoom: 11,
                    onTap: (tapPosition, point) {
                      setState(() {
                        _location = Position(
                          latitude: point.latitude,
                          longitude: point.longitude,
                          timestamp: DateTime.now(),
                          accuracy: 0,
                          altitude: 0,
                          heading: 0,
                          speed: 0,
                          speedAccuracy: 0,
                          altitudeAccuracy: 0,
                          headingAccuracy: 0,
                        );
                      });
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                    ),
                    if (_location != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(
                                _location!.latitude, _location!.longitude),
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
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _confirmLocation(),
                  style: RegisterStyles.primaryButtonStyle(context),
                  child: Text('Confirm Location',
                      style: RegisterStyles.buttonTextStyle),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLocation() async {
    if (_location == null) {
      Fluttertoast.showToast(msg: 'Please select a location on the map.');
      return;
    }

    try {
      // Reverse geocode using Nominatim API
      final response = await http.get(
        Uri.parse(
            'https://nominatim.openstreetmap.org/reverse?format=json&lat=${_location!.latitude}&lon=${_location!.longitude}&addressdetails=1'),
        headers: {'User-Agent': 'BayanihanApp/1.0 (your.email@example.com)'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final displayName = data['display_name'] ?? '';
        setState(() {
          _locationController.text = displayName.isNotEmpty
              ? displayName
              : 'Lat: ${_location!.latitude.toStringAsFixed(5)}, Lng: ${_location!.longitude.toStringAsFixed(5)}';
          _locationError = null;
        });
      } else {
        // Fallback to coordinates
        setState(() {
          _locationController.text =
              'Lat: ${_location!.latitude.toStringAsFixed(5)}, Lng: ${_location!.longitude.toStringAsFixed(5)}';
          _locationError = null;
        });
        Fluttertoast.showToast(
            msg: 'Could not fetch address. Using coordinates.');
      }
    } catch (e) {
      debugPrint('Reverse geocoding error: $e');
      // Fallback to coordinates
      setState(() {
        _locationController.text =
            'Lat: ${_location!.latitude.toStringAsFixed(5)}, Lng: ${_location!.longitude.toStringAsFixed(5)}';
        _locationError = null;
      });
      Fluttertoast.showToast(
          msg: 'Could not fetch address. Using coordinates.');
    }

    Navigator.of(context).pop();
  }


  Future<void> _selectDate(BuildContext ctx, TextEditingController c) async {
    final d = await showDatePicker(
      context: ctx,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (_, child) => Theme(
        data: Theme.of(ctx).copyWith(
          textTheme: GoogleFonts.poppinsTextTheme(
            Theme.of(ctx).textTheme.copyWith(
                  bodyLarge: const TextStyle(fontSize: 12),
                  bodyMedium: const TextStyle(fontSize: 12),
                  titleLarge: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
          ),
        ),
        child: child!,
      ),
    );
    if (d != null && mounted) setState(() => c.text = DateFormat('dd/MM/yyyy').format(d));
  }

  Future<void> _selectTime(BuildContext ctx, TextEditingController c) async {
    final t = await showTimePicker(context: ctx, initialTime: TimeOfDay.now());
    if (t != null && mounted) setState(() => c.text = t.format(ctx));
  }

  void _addAvailability() {
    if (mounted) {
      setState(() {
        _availability.add({
          'startDate': TextEditingController(),
          'endDate': TextEditingController(),
          'startTime': TextEditingController(),
          'endTime': TextEditingController(),
        });
      });
    }
  }

  void _removeAvailability(int i) {
    if (mounted && _availability.length > 1) {
      setState(() {
        _availability[i].forEach((_, c) => c.dispose());
        _availability.removeAt(i);
      });
    }
  }

  Widget _buildSkillCheckboxSection(String title, Map<String, bool> map) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: RegisterStyles.labelStyle),
        const SizedBox(height: RegisterStyles.xsmall),
        ...map.keys.map((s) => CheckboxListTile(
              value: map[s]!,
              onChanged: (v) {
                if (mounted) {
                  setState(() {
                    map[s] = v!;
                    _skillsError = null;
                  });
                }
              },
              title: Text(s, style: RegisterStyles.textSkills),
              contentPadding: EdgeInsets.zero,
              dense: true,
            )),
      ],
    );
  }

  Widget _buildAvailabilitySection(int i, Map<String, TextEditingController> a) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Availability ${i + 1}', style: RegisterStyles.labelStyle),
        const SizedBox(height: RegisterStyles.xsmall),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: a['startDate'],
                readOnly: true,
                style: RegisterStyles.inputStyle,
                decoration: RegisterStyles.inputDecoration(
                  hintText: 'dd/mm/yyyy',
                  labelText: 'Start Date',
                ),
                onTap: () => _selectDate(context, a['startDate']!),
              ),
            ),
            const SizedBox(width: RegisterStyles.small),
            Expanded(
              child: TextFormField(
                controller: a['endDate'],
                readOnly: true,
                style: RegisterStyles.inputStyle,
                decoration: RegisterStyles.inputDecoration(
                  hintText: 'dd/mm/yyyy',
                  labelText: 'End Date',
                ),
                onTap: () => _selectDate(context, a['endDate']!),
              ),
            ),
          ],
        ),
        const SizedBox(height: RegisterStyles.inputMarginBottom),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: a['startTime'],
                readOnly: true,
                style: RegisterStyles.inputStyle,
                decoration: RegisterStyles.inputDecoration(
                  hintText: '--:-- --',
                  labelText: 'Start Time',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.access_time, color: ThemeConstants.primary),
                    onPressed: () => _selectTime(context, a['startTime']!),
                  ),
                ),
              ),
            ),
            const SizedBox(width: RegisterStyles.small),
            Expanded(
              child: TextFormField(
                controller: a['endTime'],
                readOnly: true,
                style: RegisterStyles.inputStyle,
                decoration: RegisterStyles.inputDecoration(
                  hintText: '--:-- --',
                  labelText: 'End Time',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.access_time, color: ThemeConstants.primary),
                    onPressed: () => _selectTime(context, a['endTime']!),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_availability.length > 1)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _removeAvailability(i),
              child: Text('Remove', style: RegisterStyles.recoverTextStyle),
            ),
          ),
        const SizedBox(height: RegisterStyles.inputMarginBottom),
      ],
    );
  }

  void _navigateToOnboarding(BuildContext ctx) {
    Navigator.pushReplacementNamed(ctx, '/onboarding');
  }

  // ── BUILD ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeConstants.lightBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(RegisterStyles.medium),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, size: 26, color: ThemeConstants.primary),
                  onPressed: () => _navigateToOnboarding(context),
                ),
                const SizedBox(height: RegisterStyles.small),
                Text('Volunteer Registration', style: RegisterStyles.welcomeTextStyle),
                const SizedBox(height: RegisterStyles.xlarge),
                Center(
                child: Container(
                  width: RegisterStyles.formWidth,
                  decoration: RegisterStyles.formContainerDecoration(context),
                  padding: RegisterStyles.contentPadding,
                  
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      
                      Text('Volunteer Information',
                          style: RegisterStyles.labelStyle.copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: RegisterStyles.inputMarginBottom),

                      Text('First Name', style: RegisterStyles.nameLabelStyle),
                      const SizedBox(height: RegisterStyles.xsmall),
                      SizedBox(
                        width: RegisterStyles.inputWidth,
                        child: TextFormField(
                          style: RegisterStyles.inputStyle,
                          controller: _firstNameController,
                          decoration: RegisterStyles.inputDecoration(
                            hintText: 'e.g., Juan',
                            errorText: _firstNameError,
                          ),
                          onChanged: (_) => _clearError(() => _firstNameError),
                          validator: _validateFirstName,
                        ),
                      ),
                      const SizedBox(height: RegisterStyles.inputMarginBottom),

                      Text('Middle Initial (Optional)', style: RegisterStyles.nameLabelStyle),
                      const SizedBox(height: RegisterStyles.xsmall),
                      SizedBox(
                        width: RegisterStyles.inputWidth,
                        child: TextFormField(
                          style: RegisterStyles.inputStyle,
                          controller: _middleInitialController,
                          decoration: RegisterStyles.inputDecoration(hintText: 'e.g., A'),
                        ),
                      ),
                      const SizedBox(height: RegisterStyles.inputMarginBottom),

                      Text('Last Name', style: RegisterStyles.nameLabelStyle),
                      const SizedBox(height: RegisterStyles.xsmall),
                      SizedBox(
                        width: RegisterStyles.inputWidth,
                        child: TextFormField(
                          style: RegisterStyles.inputStyle,
                          controller: _lastNameController,
                          decoration: RegisterStyles.inputDecoration(
                            hintText: 'e.g., Dela Cruz',
                            errorText: _lastNameError,
                          ),
                          onChanged: (_) => _clearError(() => _lastNameError),
                          validator: _validateLastName,
                        ),
                      ),
                      const SizedBox(height: RegisterStyles.inputMarginBottom),

                      Text('Name Extension (Optional)', style: RegisterStyles.nameLabelStyle),
                      const SizedBox(height: RegisterStyles.xsmall),
                      SizedBox(
                        width: RegisterStyles.inputWidth,
                        child: TextFormField(
                          style: RegisterStyles.inputStyle,
                          controller: _nameExtensionController,
                          decoration: RegisterStyles.inputDecoration(hintText: 'e.g., Jr.'),
                        ),
                      ),
                      const SizedBox(height: RegisterStyles.inputMarginBottom),

                      Text('Email Address', style: RegisterStyles.labelStyle),
                      const SizedBox(height: RegisterStyles.xsmall),
                      SizedBox(
                        width: RegisterStyles.inputWidth,
                        child: TextFormField(
                          style: RegisterStyles.inputStyle,
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textCapitalization: TextCapitalization.none,
                          decoration: RegisterStyles.inputDecoration(
                            hintText: 'e.g., juan.delacruz@gmail.com',
                            errorText: _emailError,
                          ),
                          onChanged: (_) => _clearError(() => _emailError),
                          validator: _validateEmail,
                        ),
                      ),
                      const SizedBox(height: RegisterStyles.inputMarginBottom),

                      Text('Mobile Number', style: RegisterStyles.labelStyle),
                      const SizedBox(height: RegisterStyles.xsmall),
                      SizedBox(
                        width: RegisterStyles.inputWidth,
                        child: TextFormField(
                          style: RegisterStyles.inputStyle,
                          controller: _mobileNumberController,
                          keyboardType: TextInputType.phone,
                          decoration: RegisterStyles.inputDecoration(
                            hintText: 'e.g., 09171234567',
                            errorText: _mobileNumberError,
                          ),
                          onChanged: (_) => _clearError(() => _mobileNumberError),
                          validator: _validateMobileNumber,
                        ),
                      ),
                      const SizedBox(height: RegisterStyles.inputMarginBottom),

                      Text('Age', style: RegisterStyles.labelStyle),
                      const SizedBox(height: RegisterStyles.xsmall),
                      SizedBox(
                        width: RegisterStyles.inputWidth,
                        child: TextFormField(
                          style: RegisterStyles.inputStyle,
                          controller: _ageController,
                          keyboardType: TextInputType.number,
                          decoration: RegisterStyles.inputDecoration(
                            hintText: 'e.g., 18',
                            errorText: _ageError,
                          ),
                          onChanged: (_) => _clearError(() => _ageError),
                          validator: _validateAge,
                        ),
                      ),
                      const SizedBox(height: RegisterStyles.inputMarginBottom),

                      Text('Social Media Link (Optional)', style: RegisterStyles.labelStyle),
                      const SizedBox(height: RegisterStyles.xsmall),
                      SizedBox(
                        width: RegisterStyles.inputWidth,
                        child: TextFormField(
                          style: RegisterStyles.inputStyle,
                          controller: _socialMediaLinkController,
                          keyboardType: TextInputType.url,
                          decoration: RegisterStyles.inputDecoration(
                            hintText: 'e.g., https://facebook.com/yourprofile',
                            errorText: _socialMediaLinkError,
                          ),
                          onChanged: (_) => _clearError(() => _socialMediaLinkError),
                          validator: _validateSocialMediaLink,
                        ),
                      ),

                      _buildPasswordFields(),

                      const SizedBox(height: RegisterStyles.inputMarginBottom),
                      Text('Volunteer Location', style: RegisterStyles.labelStyle),
                      const SizedBox(height: RegisterStyles.xsmall),
                      SizedBox(
                        width: RegisterStyles.inputWidth,
                        child: TextFormField(
                          controller: _locationController,
                          style: RegisterStyles.inputStyle,
                          decoration: RegisterStyles.inputDecoration(
                            hintText: 'Enter or select location',
                            errorText: _locationError,
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.location_pin, color: ThemeConstants.primary),
                              onPressed: _showMapModal,
                            ),
                          ),
                          onChanged: (_) => _clearError(() => _locationError),
                          validator: _validateLocation,
                          onTap: _showMapModal,
                        ),
                      ),

                      const SizedBox(height: RegisterStyles.inputMarginBottom),
                      Text('Skills (Select 1-5)',
                          style: RegisterStyles.labelStyle.copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
                      if (_skillsError != null)
                        Text(_skillsError!,
                            style: const TextStyle(color: Colors.red, fontSize: 12)),
                      const SizedBox(height: RegisterStyles.xsmall),
                      _buildSkillCheckboxSection('Disaster Response Skills', _disasterResponseSkills),
                      const SizedBox(height: RegisterStyles.inputMarginBottom),
                      _buildSkillCheckboxSection('Transportation & Logistics Skills', _transportationLogisticsSkills),
                      const SizedBox(height: RegisterStyles.inputMarginBottom),
                      _buildSkillCheckboxSection('Medical Skills', _medicalSkills),
                      const SizedBox(height: RegisterStyles.inputMarginBottom),
                      _buildSkillCheckboxSection('Specialized Skills', _specializedSkills),
                      const SizedBox(height: RegisterStyles.inputMarginBottom),

                      Text('Other Skills (Optional)', style: RegisterStyles.labelStyle),
                      const SizedBox(height: RegisterStyles.xsmall),
                      SizedBox(
                        width: RegisterStyles.inputWidth,
                        child: TextFormField(
                          style: RegisterStyles.inputStyle,
                          controller: _otherSkillsController,
                          decoration: RegisterStyles.inputDecoration(hintText: 'Enter other skills'),
                          onChanged: (_) => _clearError(() => _skillsError),
                        ),
                      ),

                      const SizedBox(height: RegisterStyles.inputMarginBottom),
                      Text('Availability',
                          style: RegisterStyles.labelStyle.copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: RegisterStyles.xsmall),
                      CheckboxListTile(
                        value: _afterHoursAvailable,
                        onChanged: (v) => setState(() => _afterHoursAvailable = v!),
                        title: Text('I am available for after-hours emergency response',
                            style: RegisterStyles.textSkills),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                      const SizedBox(height: RegisterStyles.xsmall),
                      ..._availability.asMap().entries.map((e) => _buildAvailabilitySection(e.key, e.value)),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _addAvailability,
                          child: Text('Add Another Date/Time', style: RegisterStyles.recoverTextStyle),
                        ),
                      ),

                      const SizedBox(height: RegisterStyles.inputMarginBottom),
                      CheckboxListTile(
                        value: _termsAgreed,
                        onChanged: (v) {
                          if (mounted) {
                            setState(() {
                              _termsAgreed = v!;
                              _termsError = null;
                            });
                          }
                        },
                        title: Text(
                          'I have read and agree to the Terms and Conditions and Privacy Policy.',
                          style: RegisterStyles.termsTextStyle.copyWith(fontSize: 12),
                        ),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                      if (_termsError != null)
                        Text(_termsError!,
                            style: const TextStyle(color: Colors.red, fontSize: 12)),

                      const SizedBox(height: RegisterStyles.inputMarginBottom),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : () => _handleRegister(context),
                          style: _isLoading
                              ? RegisterStyles.disabledButtonStyle(context)
                              : RegisterStyles.primaryButtonStyle(context),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Text('Register', style: RegisterStyles.buttonTextStyle),
                        ),
                      ),
                      const SizedBox(height: RegisterStyles.large),
                    ],
                  ),
                ),
            )
              ],
            ),
          ),
        ),
      ),
    );
  }
}