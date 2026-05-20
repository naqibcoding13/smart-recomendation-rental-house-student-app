import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rental_house/screens/students/browse_houses_page.dart';
import 'package:rental_house/screens/students/profile_preferences_page.dart';
import 'package:rental_house/screens/students/student_map_page.dart';

import 'my_bookings_page.dart';
import 'payments_page.dart';
import 'student_ai_chat_page.dart';
// import 'map_view_page.dart'; // Import your map page here

// Colors
const Color primaryColor = Color(0xFF1E88E5);
const Color successColor = Color(0xFF4CAF50);
const Color secondaryColor = Color(0xFF42A5F5);
const Color accentColor = Color(0xFFFFA726);
const Color dangerColor = Color(0xFFE53935);
const Color mapButtonColor = Color(0xFF7E57C2); // Distinct purple for Map

class StudentHome extends StatefulWidget {
  const StudentHome({super.key});

  @override
  State<StudentHome> createState() => _StudentHomeState();
}

class _StudentHomeState extends State<StudentHome> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _studentName = '';
  Map<String, dynamic>? _preferences;
  bool _loadingStudent = true;

  final _budgetController = TextEditingController();
  String _selectedHouseType = 'Studio';
  String _selectedGender = 'Any';

  @override
  void initState() {
    super.initState();
    _loadStudentProfileAndPrefs();
  }

  Future<void> _loadStudentProfileAndPrefs() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await _firestore.collection('students').doc(uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _studentName = data['name'] ?? 'Student';
          _preferences = data['preferences'];
          _loadingStudent = false;
        });
      }
    } catch (e) {
      setState(() => _loadingStudent = false);
    }
  }

  Future<void> _saveInitialPreferences() async {
    if (_budgetController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a budget')),
      );
      return;
    }

    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final newPrefs = {
      'budget': _budgetController.text,
      'houseType': _selectedHouseType,
      'genderPreference': _selectedGender,
      'location': 'Any',
    };

    setState(() => _loadingStudent = true);

    await _firestore
        .collection('students')
        .doc(uid)
        .update({'preferences': newPrefs});

    await _loadStudentProfileAndPrefs();
  }

  double _computeHouseScore(Map<String, dynamic> house) {
    final prefs = _preferences ?? {};
    final double housePrice =
        double.tryParse(house['price']?.toString() ?? '0') ?? 0;
    final double? prefBudget =
        double.tryParse(prefs['budget']?.toString() ?? '');

    double budgetScore = (prefBudget == null || prefBudget <= 0)
        ? 0.5
        : (housePrice <= prefBudget ? 1.0 : 0.2);
    double typeScore = (prefs['houseType']?.toString().toLowerCase() ==
            house['houseType']?.toString().toLowerCase())
        ? 1.0
        : 0.2;
    double genderScore = (house['genderPreference']?.toString().toLowerCase() ==
                'any' ||
            house['genderPreference']?.toString().toLowerCase() ==
                prefs['genderPreference']?.toString().toLowerCase())
        ? 1.0
        : 0.1;

    return (budgetScore * 0.4) + (typeScore * 0.3) + (genderScore * 0.3);
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingStudent) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    bool hasPrefs = _preferences != null && _preferences!.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCustomHeader(),
            const SizedBox(height: 20),
            if (!hasPrefs)
              _buildSimplePreferenceForm()
            else ...[
              _buildRecommendationHeader(),
              _buildHouseRecommendations(),
              const SizedBox(height: 25),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Quick Services',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 15),
              _buildQuickActionsGrid(),
              const SizedBox(height: 30),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCustomHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 30),
      decoration: const BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(35),
          bottomRight: Radius.circular(35),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Welcome back,',
                    style: TextStyle(color: Colors.white70, fontSize: 16)),
                Text(
                  _studentName.split(' ').first,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const StudentAIChatPage())),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(15)),
              child: const Icon(Icons.smart_toy, color: Colors.white, size: 32),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimplePreferenceForm() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 5))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: Text("Welcome! Let's get started 🏠",
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text("Complete your preferences to see matches",
                      style: TextStyle(color: Colors.grey, fontSize: 14)),
                ),
                const SizedBox(height: 30),
                TextField(
                  controller: _budgetController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: "Max Monthly Budget (RM)",
                    prefixIcon: const Icon(Icons.money, color: primaryColor),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedHouseType,
                  decoration: InputDecoration(
                    labelText: "House Type",
                    prefixIcon: const Icon(Icons.home, color: primaryColor),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none),
                  ),
                  items: ['Studio', 'Apartment', 'Condominium', 'Townhouse', 'Flat', 'Landed', 'Room']
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedHouseType = val!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedGender,
                  decoration: InputDecoration(
                    labelText: "Gender Preference",
                    prefixIcon: const Icon(Icons.person, color: primaryColor),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none),
                  ),
                  items: ['Any', 'Male', 'Female']
                      .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedGender = val!),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _saveInitialPreferences,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15)),
                      elevation: 2,
                    ),
                    child: const Text("View My Recommendations",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text("You can update these later in your profile settings.",
              style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildRecommendationHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Recommended Houses',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          TextButton(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const BrowseHousesPage())),
            child: const Text('View All', style: TextStyle(color: primaryColor)),
          ),
        ],
      ),
    );
  }

  Widget _buildHouseRecommendations() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('houses')
          .where('availabilityStatus', isEqualTo: 'available')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
              height: 100, child: Center(child: CircularProgressIndicator()));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox(
              height: 100, child: Center(child: Text('No available houses')));
        }

        final scoredHouses = snapshot.data!.docs
            .map((doc) => {
                  'data': doc.data() as Map<String, dynamic>,
                  'score':
                      _computeHouseScore(doc.data() as Map<String, dynamic>)
                })
            .toList();

        scoredHouses.sort(
            (a, b) => (b['score'] as double).compareTo(a['score'] as double));
        final topMatches = scoredHouses.take(5).toList();

        return SizedBox(
          height: 260,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            scrollDirection: Axis.horizontal,
            itemCount: topMatches.length,
            itemBuilder: (context, index) {
              final house = topMatches[index]['data'] as Map<String, dynamic>;
              final score = ((topMatches[index]['score'] as double) * 100).toInt();
              final List images = house['images'] ?? [];

              return Container(
                width: 260,
                margin: const EdgeInsets.only(right: 14),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: images.isNotEmpty
                            ? Image.network(images.first,
                                width: double.infinity, fit: BoxFit.cover)
                            : Container(
                                color: Colors.grey.shade300,
                                child: const Center(
                                    child: Icon(Icons.home, size: 40))),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(house['title'] ?? 'House',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text('RM ${house['price']}',
                                style: const TextStyle(
                                    color: primaryColor,
                                    fontWeight: FontWeight.bold)),
                            Text('$score% Match',
                                style: const TextStyle(
                                    color: successColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildQuickActionsGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
        childAspectRatio: 1.4, // Adjusted for cleaner card look
        children: [
          _buildActionCard('Browse', Icons.explore, secondaryColor, () {
            Navigator.push(context,
                MaterialPageRoute(
                    builder: (_) => const BrowseHousesPage()));
          }),
          _buildActionCard('Bookings', Icons.bookmark_added, successColor, () {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const MyBookingsPage()));
          }),
          _buildActionCard('Payments', Icons.payment, dangerColor, () {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const PaymentsPage()));
          }),
          _buildActionCard('Explore Map', Icons.map_rounded, mapButtonColor, () {
            Navigator.push(context, 
            MaterialPageRoute(builder: (_) =>const StudentMapPage()));
           
          }),
          _buildActionCard('Settings', Icons.tune, accentColor, () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const ProfilePreferencesPage()));
          }),
        ],
      ),
    );
  }

  Widget _buildActionCard(
      String title, IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(title,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}