import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HelpSupportPage extends StatefulWidget {
  const HelpSupportPage({super.key});

  @override
  State<HelpSupportPage> createState() => _HelpSupportPageState();
}

class _HelpSupportPageState extends State<HelpSupportPage> {
  final TextEditingController _descriptionController = TextEditingController();
  bool _isLoading = false;

  String? homeownerName;
  String? homeownerPhone;
  String? homeownerId;
  String? houseId;
  String? houseName;

  @override
  void initState() {
    super.initState();
    _loadBookingDetails();
  }

  Future<void> _loadBookingDetails() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Get the student's booking
    final bookingSnapshot = await FirebaseFirestore.instance
        .collection('bookings')
        .where('student_id', isEqualTo: user.uid)
        .where('status', isEqualTo: 'Active') // current rented house
        .limit(1)
        .get();

    if (bookingSnapshot.docs.isNotEmpty) {
      final bookingData = bookingSnapshot.docs.first.data();
      setState(() {
        houseId = bookingData['house_id'];
        houseName = bookingData['house_name'];
        homeownerName = bookingData['homeowner_name'];
        homeownerPhone = bookingData['homeowner_phone'];
        homeownerId = bookingData['homeowner_id'];
      });
    }
  }

  Future<void> _submitReport() async {
    if (_descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter issue details")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;

      await FirebaseFirestore.instance.collection('support_reports').add({
        'student_id': user?.uid,
        'student_name': user?.displayName ?? 'Student',
        'homeowner_id': homeownerId,
        'homeowner_name': homeownerName,
        'homeowner_phone': homeownerPhone,
        'house_id': houseId,
        'house_name': houseName,
        'description': _descriptionController.text,
        'status': 'Pending',
        'timestamp': Timestamp.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Report sent to homeowner successfully")),
      );

      _descriptionController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Help / Support")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: houseId == null
            ? const Center(child: Text("No active rented house found."))
            : ListView(
                children: [
                  Text(
                    "House: $houseName",
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text("Homeowner: $homeownerName"),
                  Text("Phone: $homeownerPhone"),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _descriptionController,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: "Describe the issue you’re facing",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                          onPressed: _submitReport,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text("Submit Report"),
                        ),
                ],
              ),
      ),
    );
  }
}
