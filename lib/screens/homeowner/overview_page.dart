// overview_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class OverviewPage extends StatefulWidget {
  const OverviewPage({super.key});

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Colors for the professional theme
  final Color primaryColor = const Color(0xFF1E88E5);
  final Color slateColor = const Color(0xFF0F172A);

  Stream<QuerySnapshot> _recentBookingsStream() {
    final uid = _auth.currentUser?.uid;
    return _firestore
        .collection('bookings')
        .where('homeownerId', isEqualTo: uid)
        .orderBy('timestamp', descending: true)
        .limit(5)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeroHeader(),
          const SizedBox(height: 24),
          _buildStatGrid(),
          const SizedBox(height: 32),
          const Text(
            'Recent Activity',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 12),
          _buildBookingList(),
        ],
      ),
    );
  }

  Widget _buildHeroHeader() {
    final user = _auth.currentUser;
    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('homeowners').doc(user?.uid).get(),
      builder: (context, snapshot) {
        String name = snapshot.data?.get('fullName')?.toString().split(' ').first ?? 'Homeowner';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Welcome back,", style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
            Text(name, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          ],
        );
      },
    );
  }

  Widget _buildStatGrid() {
    final uid = _auth.currentUser?.uid;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                "Active Listings",
                _firestore.collection('houses').where('homeownerId', isEqualTo: uid).snapshots(),
                Icons.home_work_rounded,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                "Total Bookings",
                _firestore.collection('bookings').where('homeownerId', isEqualTo: uid).snapshots(),
                Icons.book_online_rounded,
                Colors.orange,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, Stream<QuerySnapshot> stream, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: stream,
            builder: (context, snapshot) {
              int count = snapshot.data?.docs.length ?? 0;
              return Text(count.toString(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold));
            },
          ),
          Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildBookingList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _recentBookingsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _buildEmptyState();
        }
        return Column(
          children: docs.map((d) {
            final data = d.data() as Map<String, dynamic>;
            final studentName = data['studentName'] ?? 'New Student';
            final property = data['houseTitle'] ?? 'Your Property';
            final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
            final dateStr = timestamp != null ? DateFormat('MMM dd, yyyy').format(timestamp) : '';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: primaryColor.withOpacity(0.1),
                  child: Text(studentName[0], style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
                ),
                title: Text(studentName, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("$property • $dateStr"),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                onTap: () {
                   // Navigate to Booking Details
                },
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Icon(Icons.history_rounded, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text("No recent bookings found", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}