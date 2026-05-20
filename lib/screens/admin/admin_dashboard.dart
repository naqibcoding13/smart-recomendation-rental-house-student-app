import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../login_screen.dart';

// Management Pages
import 'homeowner_management.dart';
import 'student_management.dart';
import 'payments_management.dart';
import 'admin_listing_management_page.dart';

// Admin Theme Colors - Professional Management Palette
const Color adminPrimary = Color(0xFF3F51B5); // Indigo
const Color adminDark = Color(0xFF1A237E);
const Color adminBg = Color(0xFFF8F9FE);
const Color adminAccent = Color(0xFF5C6BC0);

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  int _selectedIndex = 0;

  int homeownerCount = 0;
  int studentCount = 0;
  int paymentCount = 0;
  int listingCount = 0;

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    final homeownerSnap = await FirebaseFirestore.instance.collection('homeowners').get();
    final studentSnap = await FirebaseFirestore.instance.collection('students').get();
    final paymentSnap = await FirebaseFirestore.instance.collection('payments').get();
    final listingSnap = await FirebaseFirestore.instance.collection('houses').get();

    if (mounted) {
      setState(() {
        homeownerCount = homeownerSnap.size;
        studentCount = studentSnap.size;
        listingCount = listingSnap.size;
        paymentCount = paymentSnap.size;
      });
    }
  }

  final List<Map<String, dynamic>> menuItems = [
    {'label': 'Overview', 'icon': Icons.insights_rounded},
    {'label': 'Owners', 'icon': Icons.real_estate_agent_rounded},
    {'label': 'Students', 'icon': Icons.groups_rounded},
    {'label': 'Finances', 'icon': Icons.account_balance_wallet_rounded},
    {'label': 'Listings', 'icon': Icons.list_alt_rounded},

  ];

  Widget _getPage(int index) {
    switch (index) {
      case 1: return const HomeownerManagementPage();
      case 2: return const StudentManagementPage();
      case 3: return const PaymentsManagementPage();
      case 4: return const AdminListingManagementPage();
      default: return _buildOverviewPage();
    }
  }

  Widget _buildOverviewPage() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAdminHeader(),
          const SizedBox(height: 24),
          
          // Stats Grid - Modern 2x2 Layout
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 15,
            mainAxisSpacing: 15,
            childAspectRatio: 1.1,
            children: [
              _buildStatCard("Homeowners", homeownerCount, Icons.home_work_rounded, Colors.blue),
              _buildStatCard("Students", studentCount, Icons.school_rounded, Colors.orange),
              _buildStatCard("Payments", paymentCount, Icons.payments_rounded, Colors.green),
              _buildStatCard("Listings", listingCount, Icons.apartment_rounded, Colors.purple),
            ],
          ),

          const SizedBox(height: 32),

          // Chart Section
          _buildChartSection(),
        ],
      ),
    );
  }

  Widget _buildAdminHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "System Control",
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
        ),
        const Text(
          "Management Overview",
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: adminDark),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, int count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: adminPrimary.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 24),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                count.toString(),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: adminDark),
              ),
              Text(
                title,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildChartSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: adminPrimary.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Registration Trends",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: adminDark),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: (listingCount + studentCount).toDouble() + 5,
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const titles = ['Owners', 'Students', 'Finance'];
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(titles[value.toInt()], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: [
                  _makeGroupData(0, homeownerCount.toDouble(), adminPrimary),
                  _makeGroupData(1, studentCount.toDouble(), Colors.orange),
                  _makeGroupData(2, paymentCount.toDouble(), Colors.green),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  BarChartGroupData _makeGroupData(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 18,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          backDrawRodData: BackgroundBarChartRodData(show: true, toY: 20, color: adminBg),
        ),
      ],
    );
  }

  Future<void> _logout() async {
    await _auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: adminBg,
      appBar: AppBar(
        centerTitle: false,
        title: const Text(
          "Admin Console",
          style: TextStyle(color: adminDark, fontWeight: FontWeight.w800, fontSize: 20),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
            child: IconButton(
              onPressed: _logout,
              icon: const Icon(Icons.power_settings_new_rounded, color: Colors.redAccent, size: 22),
            ),
          )
        ],
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _getPage(_selectedIndex),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          selectedItemColor: adminPrimary,
          unselectedItemColor: Colors.grey.shade400,
          backgroundColor: Colors.white,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          elevation: 0,
          items: menuItems.map((item) {
            return BottomNavigationBarItem(
              icon: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Icon(item['icon'], size: 22),
              ),
              activeIcon: Icon(item['icon'], size: 24),
              label: item['label'],
            );
          }).toList(),
        ),
      ),
    );
  }
}