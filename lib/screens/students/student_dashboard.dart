import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Import the actual pages (assuming they exist in your file structure)
import 'student_home.dart';
import 'browse_houses_page.dart';
import 'my_bookings_page.dart';
import 'payments_page.dart';
import 'help_support_page.dart';
import 'profile_preferences_page.dart';
import '../login_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'student_map_page.dart';

// 💡 Define consistent colors for branding
const Color primaryColor = Color(0xFF1E88E5); // Deep Blue
const Color secondaryColor = Color(0xFF42A5F5); // Light Blue

// Placeholder for the Map view (You'll replace this with your map implementation)
class MapViewPage extends StatelessWidget {
  const MapViewPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Map View Page Content (Houses on Map)', style: TextStyle(fontSize: 20)),
    );
  }
}

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  int _selectedIndex = 0;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 1. UPDATED CORE PAGES: Added MapViewPage at Index 2
  final List<Widget> _corePages = [
    const StudentHome(),         // Index 0: Home (Dashboard)
    const BrowseHousesPage(),    // Index 1: Browse Houses List
    const StudentMapPage(),         // Index 2: Map View
    const MyBookingsPage(),      // Index 3: My Bookings
    const PaymentsPage(),        // Index 4: Payments
    const ProfilePreferencesPage(), // Index 5: Profile/Preferences
  ];

  // UPDATED TITLES: Match the new page indices
  final List<String> _pageTitles = const [
    'Home Dashboard',
    'Browse Houses',
    'Houses on Map', // New title for the map page
    'My Bookings',
    'Payments',
    'Profile Settings',
  ];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  Future<void> _logout() async {
    await _auth.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 4, 
        // Dynamic Title based on selected page
        title: Text(
          _pageTitles[_selectedIndex],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      
      // Navigation Drawer (Secondary Actions)
      drawer: Drawer(
        child: Column(
          children: <Widget>[
            // Drawer Header (Branded)
            DrawerHeader(
              decoration: const BoxDecoration(color: primaryColor),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Smart Rental App', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(_auth.currentUser?.email ?? 'Student Portal', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
            ),
            
            // Drawer Item: Help & Support
            ListTile(
              leading: const Icon(Icons.help_outline, color: secondaryColor),
              title: const Text('Help & Support'),
              onTap: () {
                Navigator.pop(context); 
                Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpSupportPage()));
              },
            ),
            const Divider(),

            // Drawer Item: Logout
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout'),
              onTap: _logout,
            ),
            
            const Spacer(),
            const Padding(padding: EdgeInsets.all(16.0), child: Text('Version 1.0', style: TextStyle(color: Colors.grey, fontSize: 12))),
          ],
        ),
      ),

      // Page content
      body: IndexedStack(
        index: _selectedIndex,
        children: _corePages,
      ),
      
      // 4. UPDATED Bottom Navigation Bar with 6 items (Map added)
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey.shade600,
        // Using `BottomNavigationBarType.fixed` handles 6 items, though overflow is possible on very small screens.
        type: BottomNavigationBarType.fixed, 
        backgroundColor: Colors.white,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.house), label: 'Browse'),
          // 🗺️ NEW MAP BUTTON 
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'), 
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Bookings'),
          BottomNavigationBarItem(icon: Icon(Icons.credit_card), label: 'Payments'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}