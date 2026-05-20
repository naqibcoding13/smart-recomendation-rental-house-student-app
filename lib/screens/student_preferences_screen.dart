import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'students/student_dashboard.dart';

class StudentPreferencesScreen extends StatefulWidget {
  final String userId; // Pass student ID from register screen
  const StudentPreferencesScreen({super.key, required this.userId});

  @override
  State<StudentPreferencesScreen> createState() => _StudentPreferencesScreenState();
}

class _StudentPreferencesScreenState extends State<StudentPreferencesScreen> {
  final _formKey = GlobalKey<FormState>();
  String? selectedLocation;
  String? selectedHouseType;
  String? selectedGenderPreference;
  String? budget;

  final List<String> locations = [
    'Merlimau',
    'Mendapat',
    'Lipat kajang',
    'Taman Mayang Lestari',
    'Taman Maju',
  ];

  final List<String> houseTypes = [
    'Condominium',
    'terraced House',
    'Flat',
    'Apartment',
    'Bungalow',
  ];

  final List<String> genderOptions = ['Male', 'Female'];

  bool isLoading = false;

  Future<void> savePreferences() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
    });

    await FirebaseFirestore.instance
        .collection('students')
        .doc(widget.userId)
        .collection('preferences')
        .doc('details')
        .set({
      'location': selectedLocation,
      'houseType': selectedHouseType,
      'genderPreference': selectedGenderPreference,
      'budget': budget,
      'createdAt': FieldValue.serverTimestamp(),
    });

    setState(() {
      isLoading = false;
    });

    // Navigate to dashboard after saving
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const StudentDashboard()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Your Preferences'),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    const Text(
                      'Choose your preferred location',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    DropdownButtonFormField<String>(
                      value: selectedLocation,
                      hint: const Text('Select location'),
                      items: locations
                          .map((loc) => DropdownMenuItem(value: loc, child: Text(loc)))
                          .toList(),
                      onChanged: (value) => setState(() => selectedLocation = value),
                      validator: (value) =>
                          value == null ? 'Please select a location' : null,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Select house type',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    DropdownButtonFormField<String>(
                      value: selectedHouseType,
                      hint: const Text('Select house type'),
                      items: houseTypes
                          .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                          .toList(),
                      onChanged: (value) => setState(() => selectedHouseType = value),
                      validator: (value) =>
                          value == null ? 'Please select a house type' : null,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Preferred gender for housemates',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    DropdownButtonFormField<String>(
                      value: selectedGenderPreference,
                      hint: const Text('Select gender preference'),
                      items: genderOptions
                          .map((gender) =>
                              DropdownMenuItem(value: gender, child: Text(gender)))
                          .toList(),
                      onChanged: (value) =>
                          setState(() => selectedGenderPreference = value),
                      validator: (value) =>
                          value == null ? 'Please select a gender preference' : null,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Budget (RM)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) => budget = value,
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Enter your budget' : null,
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: savePreferences,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Save Preferences'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
