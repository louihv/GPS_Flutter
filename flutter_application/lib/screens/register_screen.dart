import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
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

  // Skill categories
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

  // Availability date/time ranges
  List<Map<String, TextEditingController>> _availability = [
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
  String? _firstNameError;
  String? _lastNameError;
  String? _emailError;
  String? _mobileNumberError;
  String? _ageError;
  String? _socialMediaLinkError;
  String? _locationError;
  String? _skillsError;
  String? _availabilityError;
  String? _termsError;

  final _auth = FirebaseAuth.instance;
  final _database = FirebaseDatabase.instance.ref();

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
    for (var avail in _availability) {
      avail['startDate']!.dispose();
      avail['endDate']!.dispose();
      avail['startTime']!.dispose();
      avail['endTime']!.dispose();
    }
    super.dispose();
  }

  // Validators
  String? _validateFirstName(String? value) {
    if (value == null || value.isEmpty) return 'First name is required.';
    if (value.length < 2) return 'First name must be at least 2 characters.';
    return null;
  }

  String? _validateLastName(String? value) {
    if (value == null || value.isEmpty) return 'Last name is required.';
    if (value.length < 2) return 'Last name must be at least 2 characters.';
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Email is required.';
    final emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailPattern.hasMatch(value)) return 'Please enter a valid email address.';
    return null;
  }

  String? _validateMobileNumber(String? value) {
    if (value == null || value.isEmpty) return 'Mobile number is required.';
    final mobilePattern = RegExp(r'^\d{10,11}$');
    if (!mobilePattern.hasMatch(value)) return 'Enter a valid mobile number (10-11 digits).';
    return null;
  }

  String? _validateAge(String? value) {
    if (value == null || value.isEmpty) return 'Age is required.';
    final age = int.tryParse(value);
    if (age == null || age < 18) return 'Volunteers must be at least 18 years old.';
    return null;
  }

  String? _validateSocialMediaLink(String? value) {
    if (value == null || value.isEmpty) return null; // Optional
    final urlPattern = RegExp(r'^https?://(www\.)?facebook\.com/.+$');
    if (!urlPattern.hasMatch(value)) return 'Enter a valid Facebook profile URL.';
    return null;
  }

  String? _validateLocation(String? value) {
    if (value == null || value.isEmpty) return 'Location is required.';
    return null;
  }

  String? _validateSkills() {
    final selectedSkills = [
      ..._disasterResponseSkills.entries.where((e) => e.value).map((e) => e.key),
      ..._transportationLogisticsSkills.entries.where((e) => e.value).map((e) => e.key),
      ..._medicalSkills.entries.where((e) => e.value).map((e) => e.key),
      ..._specializedSkills.entries.where((e) => e.value).map((e) => e.key),
      if (_otherSkillsController.text.trim().isNotEmpty) _otherSkillsController.text.trim(),
    ];
    if (selectedSkills.isEmpty) return 'At least one skill is required.';
    if (selectedSkills.length > 5) return 'Select up to 5 skills.';
    return null;
  }

  String? _validateDate(String? value, String fieldName) {
    if (value == null || value.isEmpty) return '$fieldName is required.';
    final datePattern = RegExp(r'^\d{2}/\d{2}/\d{4}$');
    if (!datePattern.hasMatch(value)) return 'Enter date in dd/mm/yyyy format.';
    try {
      DateFormat('dd/MM/yyyy').parseStrict(value);
      return null;
    } catch (e) {
      return 'Invalid $fieldName format.';
    }
  }

  String? _validateTime(String? value, String fieldName) {
    if (value == null || value.isEmpty) return '$fieldName is required.';
    final timePattern = RegExp(r'^\d{2}:\d{2} (AM|PM)$');
    if (!timePattern.hasMatch(value)) return 'Enter time in hh:mm AM/PM format.';
    try {
      DateFormat('hh:mm a').parseStrict(value);
      return null;
    } catch (e) {
      return 'Invalid $fieldName format.';
    }
  }

  String? _validateAvailability() {
    for (var avail in _availability) {
      final startDateError = _validateDate(avail['startDate']!.text, 'Start date');
      final endDateError = _validateDate(avail['endDate']!.text, 'End date');
      final startTimeError = _validateTime(avail['startTime']!.text, 'Start time');
      final endTimeError = _validateTime(avail['endTime']!.text, 'End time');
      if (startDateError != null || endDateError != null || startTimeError != null || endTimeError != null) {
        return 'Please correct availability date/time fields.';
      }
    }
    return null;
  }

  String? _validateTerms() {
    if (!_termsAgreed) return 'You must agree to the Terms and Conditions.';
    return null;
  }

  Future<bool> _emailExists(String email) async {
    try {
      final emailLower = email.toLowerCase();
      final emailRef = _database.child('users/emailIndex/$emailLower');
      final snapshot = await emailRef.get();
      return snapshot.exists && snapshot.value != null;
    } catch (e) {
      debugPrint('Error checking email: $e');
      return false;
    }
  }

  Future<void> _handleRegister(BuildContext context) async {
    final firstName = _firstNameController.text.trim();
    final middleInitial = _middleInitialController.text.trim();
    final lastName = _lastNameController.text.trim();
    final nameExtension = _nameExtensionController.text.trim();
    final email = _emailController.text.trim();
    final mobileNumber = _mobileNumberController.text.trim();
    final age = _ageController.text.trim();
    final socialMediaLink = _socialMediaLinkController.text.trim();
    final location = _locationController.text.trim();
    final otherSkills = _otherSkillsController.text.trim();

    final firstNameError = _validateFirstName(firstName);
    final lastNameError = _validateLastName(lastName);
    final emailError = _validateEmail(email);
    final mobileNumberError = _validateMobileNumber(mobileNumber);
    final ageError = _validateAge(age);
    final socialMediaLinkError = _validateSocialMediaLink(socialMediaLink);
    final locationError = _validateLocation(location);
    final skillsError = _validateSkills();
    final availabilityError = _validateAvailability();
    final termsError = _validateTerms();

    if (firstNameError != null || lastNameError != null || emailError != null || mobileNumberError != null || ageError != null || socialMediaLinkError != null || locationError != null || skillsError != null || availabilityError != null || termsError != null) {
      if (mounted) {
        setState(() {
          _firstNameError = firstNameError;
          _lastNameError = lastNameError;
          _emailError = emailError;
          _mobileNumberError = mobileNumberError;
          _ageError = ageError;
          _socialMediaLinkError = socialMediaLinkError;
          _locationError = locationError;
          _skillsError = skillsError;
          _availabilityError = availabilityError;
          _termsError = termsError;
        });
      }
      return;
    }

    if (_isLoading) return;

    if (mounted) setState(() => _isLoading = true);

    try {
      final emailTaken = await _emailExists(email);
      if (emailTaken) {
        if (mounted) setState(() => _emailError = 'Email already in use.');
        Fluttertoast.showToast(msg: 'Email already registered. Please log in.');
        return;
      }

      final userCredential = await _auth.createUserWithEmailAndPassword(email: email, password: 'temporaryPassword'); // Password set temporarily
      final user = userCredential.user;

      if (user == null) throw FirebaseAuthException(code: 'unknown');

      final now = DateTime.now().millisecondsSinceEpoch;
      final selectedSkills = [
        ..._disasterResponseSkills.entries.where((e) => e.value).map((e) => e.key),
        ..._transportationLogisticsSkills.entries.where((e) => e.value).map((e) => e.key),
        ..._medicalSkills.entries.where((e) => e.value).map((e) => e.key),
        ..._specializedSkills.entries.where((e) => e.value).map((e) => e.key),
        if (otherSkills.isNotEmpty) otherSkills,
      ];
      final availabilityData = _availability.map((avail) => {
        'startDate': avail['startDate']!.text,
        'endDate': avail['endDate']!.text,
        'startTime': avail['startTime']!.text,
        'endTime': avail['endTime']!.text,
      }).toList();

      final volunteerData = {
        'firstName': firstName,
        'middleInitial': middleInitial,
        'lastName': lastName,
        'nameExtension': nameExtension,
        'email': email,
        'mobileNumber': mobileNumber,
        'age': int.parse(age),
        'socialMediaLink': socialMediaLink,
        'location': location,
        'skills': selectedSkills,
        'afterHoursAvailable': _afterHoursAvailable,
        'availability': availabilityData,
        'createdAt': now,
        'role': 'ABVN',
        'emailVerified': false,
        'isFirstLogin': true,
        'organization': 'ABVN',
      };

      await _database.child('users/${user.uid}').set(volunteerData);
      await _database.child('users/emailIndex/$email').set(user.uid);

      try {
        final actionCodeSettings = ActionCodeSettings(
          url: 'https://www.angat-bayanihan.com/pages/login.html',
          handleCodeInApp: true,
        );
        await user.sendEmailVerification(actionCodeSettings);
        await _database.child('users/${user.uid}/lastVerificationEmailSent').set(now);
        Fluttertoast.showToast(msg: 'Verification email sent. Check inbox (spam/junk).');
      } catch (verificationError) {
        debugPrint('Error sending verification: ${verificationError.toString()}');
        Fluttertoast.showToast(msg: 'Verification failed. Please log in to resend.');
      }

      Provider.of<myAuth.AuthProvider>(context, listen: false).setUser(user, volunteerData);
      Fluttertoast.showToast(msg: 'Registration successful. Please verify your email.');
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    } on FirebaseAuthException catch (authError) {
      debugPrint('Auth error: ${authError.code} - ${authError.message}');
      String errorMsg = 'Registration failed.';
      switch (authError.code) {
        case 'email-already-in-use':
          if (mounted) setState(() => _emailError = 'Email already in use.');
          break;
        case 'invalid-email':
          if (mounted) setState(() => _emailError = 'Invalid email format.');
          break;
        default:
          errorMsg = authError.message ?? authError.toString();
      }
      Fluttertoast.showToast(msg: errorMsg);
    } catch (e) {
      debugPrint('General register error: $e');
      Fluttertoast.showToast(msg: 'Registration failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToDashboard(BuildContext context) {
    Navigator.pushReplacementNamed(context, '/dashboard');
  }

Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
  final DateTime? picked = await showDatePicker(
    context: context,
    initialDate: DateTime.now(),
    firstDate: DateTime.now(),
    lastDate: DateTime(2100),
    builder: (BuildContext context, Widget? child) {
      return Theme(
        data: Theme.of(context).copyWith(
          textTheme: GoogleFonts.poppinsTextTheme(
            Theme.of(context).textTheme.copyWith(
              bodyLarge: const TextStyle(fontSize: 12), 
              bodyMedium: const TextStyle(fontSize: 12),
              titleLarge: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), // month/year
            ),
          ),
        ),
        child: child!,
      );
    },
  );

  if (picked != null && mounted) {
    setState(() {
      controller.text = DateFormat('dd/MM/yyyy').format(picked);
    });
  }
}


  Future<void> _selectTime(BuildContext context, TextEditingController controller) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null && mounted) {
      setState(() {
        controller.text = picked.format(context);
      });
    }
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
        _availabilityError = null;
      });
    }
  }

  void _removeAvailability(int index) {
    if (mounted && _availability.length > 1) {
      setState(() {
        _availability[index]['startDate']!.dispose();
        _availability[index]['endDate']!.dispose();
        _availability[index]['startTime']!.dispose();
        _availability[index]['endTime']!.dispose();
        _availability.removeAt(index);
        _availabilityError = null;
      });
    }
  }

  Widget _buildSkillCheckboxSection(String title, Map<String, bool> skills) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: RegisterStyles.labelStyle),
        const SizedBox(height: RegisterStyles.xsmall),
        ...skills.keys.map((skill) => CheckboxListTile(
          value: skills[skill]!,
          onChanged: (value) {
            if (mounted) {
              setState(() {
                skills[skill] = value!;
                _skillsError = null;
              });
            }
          },
          title: Text(skill, style: RegisterStyles.textSkills),
          
          contentPadding: EdgeInsets.zero,
          dense: true,
        )),
      ],
    );
  }

  Widget _buildAvailabilitySection(int index, Map<String, TextEditingController> avail) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Availability ${index + 1}', style: RegisterStyles.labelStyle),
        const SizedBox(height: RegisterStyles.xsmall),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: avail['startDate'],
                readOnly: true,
               style: RegisterStyles.inputStyle,
                decoration: RegisterStyles.inputDecoration(
                  hintText: 'dd/mm/yyyy',
                  labelText: 'Start Date',
                ),
                onChanged: (value) => _clearError(() => _availabilityError),
                validator: (value) => _validateDate(value, 'Start date'),
                onTap: () => _selectDate(context, avail['startDate']!),
              ),
            ),
            const SizedBox(width: RegisterStyles.small),
            Expanded(
              child: TextFormField(
                style: RegisterStyles.inputStyle,
                controller: avail['endDate'],
                readOnly: true,
                decoration: RegisterStyles.inputDecoration(
                  hintText: 'dd/mm/yyyy',
                  labelText: 'End Date',
                ),
                onChanged: (value) => _clearError(() => _availabilityError),
                validator: (value) => _validateDate(value, 'End date'),
                onTap: () => _selectDate(context, avail['endDate']!),
              ),
            ),
          ],
        ),
        const SizedBox(height: RegisterStyles.inputMarginBottom),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                style: RegisterStyles.inputStyle,
                controller: avail['startTime'],
                readOnly: true,
                decoration: RegisterStyles.inputDecoration(
                  hintText: '--:-- --',
                  labelText: 'Start Time',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.access_time, color: ThemeConstants.primary),
                    onPressed: () => _selectTime(context, avail['startTime']!),
                  ),
                ),
                onChanged: (value) => _clearError(() => _availabilityError),
                validator: (value) => _validateTime(value, 'Start time'),
              ),
            ),
            const SizedBox(width: RegisterStyles.small),
            Expanded(
              child: TextFormField(
                style: RegisterStyles.inputStyle,
                controller: avail['endTime'],
                readOnly: true,
                decoration: RegisterStyles.inputDecoration(
                  hintText: '--:-- --',
                  labelText: 'End Time',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.access_time, color: ThemeConstants.primary),
                    onPressed: () => _selectTime(context, avail['endTime']!),
                  ),
                ),
                onChanged: (value) => _clearError(() => _availabilityError),
                validator: (value) => _validateTime(value, 'End time'),
              ),
            ),
          ],
        ),
        if (_availability.length > 1)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _removeAvailability(index),
              child: Text('Remove', style: RegisterStyles.recoverTextStyle),
            ),
          ),
        const SizedBox(height: RegisterStyles.inputMarginBottom),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeConstants.lightBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(RegisterStyles.large),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, size: 26, color: ThemeConstants.primary),
                  onPressed: () => _navigateToDashboard(context),
                ),
                const SizedBox(height: RegisterStyles.xlarge),
                Text(
                  'Volunteer Registration',
                  style: RegisterStyles.welcomeTextStyle,
                ),
                const SizedBox(height: RegisterStyles.xlarge),
                Container(
                  width: RegisterStyles.formWidth,
                  decoration: RegisterStyles.formContainerDecoration(context),
                  padding: RegisterStyles.contentPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Volunteer Information
                      Text('Volunteer Information', style: RegisterStyles.labelStyle.copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
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
                          onChanged: (value) => _clearError(() => _firstNameError),
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
                          decoration: RegisterStyles.inputDecoration(
                            hintText: 'e.g., A',
                          ),
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
                          onChanged: (value) => _clearError(() => _lastNameError),
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
                          decoration: RegisterStyles.inputDecoration(
                            hintText: 'e.g., Jr.',
                          ),
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
                          onChanged: (value) => _clearError(() => _emailError),
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
                          onChanged: (value) => _clearError(() => _mobileNumberError),
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
                          onChanged: (value) => _clearError(() => _ageError),
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
                          onChanged: (value) => _clearError(() => _socialMediaLinkError),
                          validator: _validateSocialMediaLink,
                        ),
                      ),
                      const SizedBox(height: RegisterStyles.inputMarginBottom),
                      Text('Volunteer Location', style: RegisterStyles.labelStyle),
                      const SizedBox(height: RegisterStyles.xsmall),
                      SizedBox(
                        width: RegisterStyles.inputWidth,
                        child: TextFormField(
                          controller: _locationController,
                          style: const TextStyle(
                              fontSize: 12,
                            ),
                          decoration: RegisterStyles.inputDecoration(
                            hintText: 'Enter location (map integration placeholder)',
                            errorText: _locationError,
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.location_pin, color: ThemeConstants.primary),
                              onPressed: () {
                                Fluttertoast.showToast(msg: 'Map integration requires flutter_map or google_maps_flutter.');
                              },
                            ),
                          ),
                          onChanged: (value) => _clearError(() => _locationError),
                          validator: _validateLocation,
                        ),
                      ),
                      const SizedBox(height: RegisterStyles.inputMarginBottom),
                      // Skills
                      Text('Skills (Select 1–5)', style: RegisterStyles.labelStyle.copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
                      if (_skillsError != null)
                        Text(_skillsError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
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
                          decoration: RegisterStyles.inputDecoration(
                            hintText: 'Enter other skills',
                          ),
                          onChanged: (value) => _clearError(() => _skillsError),
                        ),
                      ),
                      const SizedBox(height: RegisterStyles.inputMarginBottom),
                      // Availability
                      Text('Availability', style: RegisterStyles.labelStyle.copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: RegisterStyles.xsmall),
                      CheckboxListTile(
                        value: _afterHoursAvailable,
                        onChanged: (value) {
                          if (mounted) setState(() => _afterHoursAvailable = value!);
                        },
                        title: Text('I am available for after-hours emergency response', style: RegisterStyles.textSkills),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                      if (_availabilityError != null)
                        Text(_availabilityError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                      const SizedBox(height: RegisterStyles.xsmall),
                      ..._availability.asMap().entries.map((entry) => _buildAvailabilitySection(entry.key, entry.value)),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _addAvailability,
                          child: Text('Add Another Date/Time', style: RegisterStyles.recoverTextStyle),
                        ),
                      ),
                      const SizedBox(height: RegisterStyles.inputMarginBottom),
                      // Terms
                      CheckboxListTile(
                        value: _termsAgreed,
                        onChanged: (value) {
                          if (mounted) {
                            setState(() {
                              _termsAgreed = value!;
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
                        Text(_termsError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                      const SizedBox(height: RegisterStyles.inputMarginBottom),
                      // Register Button
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _clearError(VoidCallback setter) {
    setter();
    if (mounted) setState(() {});
  }
}