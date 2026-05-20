import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// Admin Theme Palette
const Color adminPrimary = Color(0xFF3F51B5); 
const Color adminBg = Color(0xFFF8F9FE);
const Color adminDark = Color(0xFF1A237E);
const Color paidColor = Color(0xFF4CAF50);
const Color unpaidColor = Color(0xFFFFA726);

class PaymentsManagementPage extends StatefulWidget {
  const PaymentsManagementPage({super.key});

  @override
  State<PaymentsManagementPage> createState() => _PaymentsManagementPageState();
}

class _PaymentsManagementPageState extends State<PaymentsManagementPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: adminBg,
      appBar: AppBar(
        title: const Text(
          "Payments History",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: adminPrimary,
        elevation: 0,
        centerTitle: true,
        // Logout IconButton removed from actions
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderSection(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('monthly_payments')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: adminPrimary));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                final payments = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  physics: const BouncingScrollPhysics(),
                  itemCount: payments.length,
                  itemBuilder: (context, index) {
                    final data = payments[index].data() as Map<String, dynamic>;
                    final String bookingId = data['bookingId'] ?? '';
                    final String month = data['month'] ?? '-';
                    final int amount = data['amount'] ?? 0;
                    final String status = data['status'] ?? 'unpaid';
                    final DateTime dueDate = (data['dueDate'] as Timestamp).toDate();

                    return FutureBuilder<DocumentSnapshot>(
                      future: _firestore.collection('bookings').doc(bookingId).get(),
                      builder: (context, bookingSnap) {
                        final String studentName = (bookingSnap.data?.data() as Map<String, dynamic>?)?['studentName'] ?? 'Loading...';
                        
                        return _buildPaymentCard(month, studentName, amount, status, dueDate);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Monthly Rent Tracker",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: adminDark),
          ),
          Text(
            "Read-only view of rental transactions and payment history",
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(String month, String student, int amount, String status, DateTime dueDate) {
    bool isPaid = status.toLowerCase() == 'paid';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: adminPrimary.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Left Status Icon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (isPaid ? paidColor : unpaidColor).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPaid ? Icons.check_circle_rounded : Icons.history_rounded,
                color: isPaid ? paidColor : unpaidColor,
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            // Middle Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    month,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: adminDark),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Student: $student",
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  Text(
                    "Due: ${DateFormat('dd MMM yyyy').format(dueDate)}",
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            // Right Amount & Badge
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "RM $amount",
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: adminDark),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPaid ? paidColor : unpaidColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_balance_wallet_outlined, size: 70, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text("No payments recorded yet", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}