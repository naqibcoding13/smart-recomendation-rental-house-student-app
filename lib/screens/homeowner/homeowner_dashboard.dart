// homeowner_dashboard.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../login_screen.dart';

// Pages
import 'overview_page.dart';
import 'add_house_page.dart';
import 'manage_properties_page.dart';
import 'bookings_page.dart';
import 'payments_page.dart';
import 'map_view_page.dart';

// 💡 Define consistent colors
const Color primaryColor = Color(0xFF1E88E5); // Deep Blue

class HomeownerDashboard extends StatefulWidget {
  const HomeownerDashboard({super.key});

  @override
  State<HomeownerDashboard> createState() => _HomeownerDashboardState();
}

class _HomeownerDashboardState extends State<HomeownerDashboard> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  int _selectedIndex = 0;
  String _homeownerName = '';
  bool _loadingProfile = true;

  // Navigation items
  final List<Map<String, dynamic>> _navItems = [
    {'title': 'Overview', 'icon': Icons.dashboard},
    {'title': 'Add New House', 'icon': Icons.add_home_work},
    {'title': 'My Properties', 'icon': Icons.house},
    {'title': 'Bookings', 'icon': Icons.receipt_long},
    {'title': 'Payments', 'icon': Icons.credit_card},
    {'title': 'Map View', 'icon': Icons.map},
  ];

  final List<Widget> _pages = [
    OverviewPage(),
    AddHousePage(onHouseAdded: () {}),
    ManagePropertiesPage(),
    BookingsPage(),
    PaymentsPage(),
    MapViewPage(),
  ];

  @override
  void initState() {
    super.initState();
    _loadHomeownerProfile();
  }

  // 🔹 Load homeowner basic profile (NO verification)
  Future<void> _loadHomeownerProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final doc = await _firestore.collection('homeowners').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        _homeownerName =
            (data['fullName'] as String?)?.split(' ').first ??
            user.email!.split('@').first;
      } else {
        _homeownerName = user.email!.split('@').first;
      }
    } catch (_) {
      _homeownerName = user.email!.split('@').first;
    } finally {
      setState(() => _loadingProfile = false);
    }
  }

  Future<void> _logout() async {
    await _auth.signOut();
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  // Drawer Item
  Widget _buildDrawerItem({
    required IconData icon,
    required String label,
    required int idx,
  }) {
    final selected = idx == _selectedIndex;

    return ListTile(
      leading: Icon(
        icon,
        color: selected ? primaryColor : Colors.grey.shade700,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: selected ? primaryColor : Colors.black87,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: selected,
      selectedTileColor: primaryColor.withOpacity(0.1),
      onTap: () {
        setState(() => _selectedIndex = idx);
        Navigator.pop(context);
      },
    );
  }

  // Drawer UI
  Widget _buildDrawer() {
    final email = _auth.currentUser?.email ?? 'N/A';

    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(
              _homeownerName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            accountEmail: Text(email),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.business, color: primaryColor, size: 40),
            ),
            decoration: const BoxDecoration(color: primaryColor),
          ),

          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: _navItems.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = _navItems[index];
                return _buildDrawerItem(
                  icon: item['icon'],
                  label: item['title'],
                  idx: index,
                );
              },
            ),
          ),

          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.logout, color: Colors.white),
                label: const Text(
                  'Logout',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _logout,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Main UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_navItems[_selectedIndex]['title']),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      drawer: _buildDrawer(),
      body: _loadingProfile
          ? const Center(
              child: CircularProgressIndicator(color: primaryColor),
            )
          : IndexedStack(
              index: _selectedIndex,
              children: _pages,
            ),
    );
  }
}
