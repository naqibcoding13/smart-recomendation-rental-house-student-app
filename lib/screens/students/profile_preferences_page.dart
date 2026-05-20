import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rental_house/screens/login_screen.dart';

// Define consistent colors
const Color primaryColor = Color(0xFF1E88E5); // Deep Blue
const Color accentColor = Color(0xFFFFA726); // Orange

class ProfilePreferencesPage extends StatefulWidget {
  const ProfilePreferencesPage({super.key});

  @override
  State<ProfilePreferencesPage> createState() => _ProfilePreferencesPageState();
}

class _ProfilePreferencesPageState extends State<ProfilePreferencesPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final _formKey = GlobalKey<FormState>();

  // State variables initialized from Firebase
  String? _name;
  String? _email;
  String? _phone;
  String? _gender;
  String? _location;
  String? _budget;
  String? _houseType;
  String? _genderPreference;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStudentData();
  }
  
  // --- Data Loading Logic ---

  Future<void> _loadStudentData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final doc = await _firestore.collection('students').doc(user.uid).get();
    
    if (!mounted) return;

    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        _name = data['name'];
        _email = data['email'];
        _phone = data['phone'];
        _gender = (data['gender'] == 'Male' || data['gender'] == 'Female') ? data['gender'] : null;

        // Preferences
        final prefs = data['preferences'] as Map<String, dynamic>?;
        _location = prefs?['location'];
        _budget = prefs?['budget'];
        _houseType = prefs?['houseType'];
        
        final prefGender = prefs?['genderPreference'];
        _genderPreference = (prefGender == 'Any' || prefGender == 'Male' || prefGender == 'Female') ? prefGender : null;
        
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('students').doc(user.uid).update({
      'name': _name,
      'email': _email,
      'phone': _phone,
      'gender': _gender,
      'preferences': {
        'location': _location,
        'budget': _budget,
        'houseType': _houseType,
        'genderPreference': _genderPreference,
      },
    });

    if(mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Profile updated successfully'), backgroundColor: primaryColor));
    }
  }

  // Note: Assuming navigation back to Login is handled by the parent Dashboard Scaffold.
  Future<void> _logout() async {
    await _auth.signOut();
    if (!mounted) return;
    // Replace with your actual route name or use Navigator.pushAndRemoveUntil
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  // --- UI Builders ---

  Widget _buildTextField({
    required String labelText,
    required String? initialValue,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    required Function(String?) onSaved,
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        initialValue: initialValue,
        keyboardType: keyboardType,
        validator: validator,
        onSaved: onSaved,
        enabled: enabled,
        style: TextStyle(color: enabled ? Colors.black87 : Colors.grey.shade600),
        decoration: InputDecoration(
          labelText: labelText,
          prefixIcon: Icon(icon, color: primaryColor),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primaryColor, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownField<T>({
    required String labelText,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: DropdownButtonFormField<T>(
        value: value,
        items: items,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: labelText,
          prefixIcon: Icon(icon, color: primaryColor),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primaryColor, width: 2),
          ),
        ),
        validator: (val) {
          if (val == null) return '$labelText is required';
          return null;
        },
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: primaryColor));
    }
    
    // Fallback: Ensure name is not null for display
    final displayedName = _name ?? "Student Profile";

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Fixed Header with User Info ---
            Container(
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 30),
              decoration: const BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Hello,',
                        style: TextStyle(fontSize: 16, color: Colors.white70),
                      ),
                      Text(
                        displayedName,
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.white),
                    onPressed: _logout, // Assuming parent handles navigation away
                    tooltip: 'Logout',
                  ),
                ],
              ),
            ),
            
            // --- Form Content ---
            Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- 1. Personal Information ---
                    const Text("1. Personal Information",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.black87)),
                    const Divider(height: 20),

                    _buildTextField(
                      labelText: 'Full Name',
                      initialValue: _name,
                      icon: Icons.person_outline,
                      validator: (val) => val == null || val.isEmpty ? 'Name is required' : null,
                      onSaved: (val) => _name = val,
                    ),
                    
                    _buildTextField(
                      labelText: 'Email',
                      initialValue: _email,
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      enabled: false, // Email is usually immutable after registration
                      validator: (val) => val == null || !RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(val) ? 'Enter a valid email' : null,
                      onSaved: (val) => _email = val,
                    ),

                    _buildTextField(
                      labelText: 'Phone Number (e.g., +60123456789)',
                      initialValue: _phone,
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      validator: (val) => val == null || val.isEmpty ? 'Phone number is required' : null,
                      onSaved: (val) => _phone = val,
                    ),

                    _buildDropdownField<String>(
                      labelText: 'Gender',
                      value: _gender,
                      icon: Icons.wc_outlined,
                      items: const [
                        DropdownMenuItem(value: 'Male', child: Text('Male')),
                        DropdownMenuItem(value: 'Female', child: Text('Female')),
                      ],
                      onChanged: (val) => setState(() => _gender = val),
                    ),

                    const SizedBox(height: 30),
                    const Divider(),
                    
                    // --- 2. Rental Preferences (AI Recommendation Data) ---
                    const Text("2. Rental Preferences (Score Matching Data)",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.black87)),
                    const Divider(height: 20),

                    _buildTextField(
                      labelText: 'Preferred Location (e.g., Melaka Tengah)',
                      initialValue: _location,
                      icon: Icons.location_city_outlined,
                      onSaved: (val) => _location = val,
                    ),

                    _buildTextField(
                      labelText: 'Budget (RM e.g., 500)',
                      initialValue: _budget,
                      icon: Icons.monetization_on_outlined,
                      keyboardType: TextInputType.number,
                      onSaved: (val) => _budget = val,
                    ),

                    _buildTextField(
                      labelText: 'House Type (e.g., Townhouse, Condominium)',
                      initialValue: _houseType,
                      icon: Icons.home_outlined,
                      onSaved: (val) => _houseType = val,
                    ),

                    _buildDropdownField<String>(
                      labelText: 'Preferred Housemate Gender',
                      value: _genderPreference,
                      icon: Icons.group_outlined,
                      items: const [
                        DropdownMenuItem(value: 'Any', child: Text('Any')),
                        DropdownMenuItem(value: 'Male', child: Text('Male')),
                        DropdownMenuItem(value: 'Female', child: Text('Female')),
                      ],
                      onChanged: (val) => setState(() => _genderPreference = val),
                    ),

                    const SizedBox(height: 40),

                    // --- Save Button ---
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton.icon(
                        onPressed: _updateProfile,
                        icon: const Icon(Icons.save, color: Colors.white),
                        label: const Text('Save Changes', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}