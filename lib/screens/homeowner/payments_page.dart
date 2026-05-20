import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// ================= COLORS =================
const Color primaryColor = Color(0xFF1E88E5);
const Color paidColor = Color(0xFF4CAF50);
const Color depositColor = Color(0xFF1976D2);
const Color dueColor = Color(0xFFFFA726);

// ================= PAGE =================
class PaymentsPage extends StatefulWidget {
  const PaymentsPage({super.key});

  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ================= HELPERS =================
  Widget _buildFinancialRow(
    String label,
    dynamic amount,
    Color color, {
    bool isStatus = false,
  }) {
    final double value = double.tryParse(amount.toString()) ?? 0.0;
    final currency =
        NumberFormat.currency(locale: 'en_MY', symbol: 'RM ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            isStatus ? amount.toString() : currency.format(value),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ================= ADD NEXT MONTH PAYMENT =================
  Future<void> _addNextMonthlyPayment({
    required String bookingId,
    required int rentAmount,
  }) async {
    final now = DateTime.now();

    final lastPayment = await _firestore
        .collection('monthly_payments')
        .where('bookingId', isEqualTo: bookingId)
        .orderBy('dueDate', descending: true)
        .limit(1)
        .get();

    DateTime nextDate;

    if (lastPayment.docs.isEmpty) {
      nextDate = DateTime(now.year, now.month + 1, 1);
    } else {
      final lastDate =
          (lastPayment.docs.first['dueDate'] as Timestamp).toDate();
      nextDate = DateTime(lastDate.year, lastDate.month + 1, 1);
    }

    final monthLabel = DateFormat('MMMM yyyy').format(nextDate);

    await _firestore.collection('monthly_payments').add({
      'bookingId': bookingId,
      'homeownerId': _auth.currentUser!.uid,
      'month': monthLabel,
      'amount': rentAmount,
      'status': 'unpaid',
      'dueDate': Timestamp.fromDate(nextDate),
      'createdAt': Timestamp.now(),
    });
  }

  // ================= BUILD =================
  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;

    if (uid == null) {
      return const Center(child: Text("Please log in"));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Payments"),
        backgroundColor: primaryColor,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('bookings')
            .where('homeownerId', isEqualTo: uid)
            .where('paymentStatus',
            whereIn: ['deposit_paid', 'fully_paid'])
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
    !snapshot.hasData) {
  return const Center(child: CircularProgressIndicator());
}

if (snapshot.data!.docs.isEmpty) {
  return const Center(
    child: Text("No payment records yet."),
  );
}


          final bookings = snapshot.data!.docs;

          if (bookings.isEmpty) {
            return const Center(child: Text("No payment records yet."));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              final booking = bookings[index];
              final data = booking.data() as Map<String, dynamic>;

              final String studentName =
                  data['studentName'] ?? 'Unknown Student';
              final String houseTitle =
                  data['houseTitle'] ?? 'Untitled Property';
              final String paymentStatus =
                  data['paymentStatus'] ?? 'pending';

              final num rentAmount = data['rentAmount'] ?? 0;
              final num depositAmount = data['depositAmount'] ?? 0;

              return Card(
                elevation: 5,
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ================= HEADER =================
                      Text(
                        houseTitle,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),

                      const SizedBox(height: 6),
                      Text("Rented by: $studentName"),

                      const Divider(height: 20),

                      _buildFinancialRow(
                          "Monthly Rent", rentAmount, Colors.black),
                      _buildFinancialRow(
                          "Deposit", depositAmount, Colors.black),

                      const Divider(height: 20),

                      _buildFinancialRow(
                        "Deposit Status",
                        paymentStatus == 'deposit_paid' ||
                                paymentStatus == 'fully_paid'
                            ? 'RECEIVED'
                            : 'PENDING',
                        depositColor,
                        isStatus: true,
                      ),

                      _buildFinancialRow(
                        "First Month Rent",
                        paymentStatus == 'fully_paid'
                            ? 'RECEIVED'
                            : 'PENDING',
                        paymentStatus == 'fully_paid'
                            ? paidColor
                            : dueColor,
                        isStatus: true,
                      ),

                      const Divider(height: 24),

                      // ================= MONTHLY PAYMENTS =================
                      const Text(
                        "Monthly Payments",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),

                      const SizedBox(height: 8),

                      StreamBuilder<QuerySnapshot>(
                        stream: _firestore
                            .collection('monthly_payments')
                            .where('bookingId', isEqualTo: booking.id)
                            .orderBy('dueDate')
                            .snapshots(),
                        builder: (context, snap) {
                          if (!snap.hasData) {
                            return const CircularProgressIndicator();
                          }

                          if (snap.data!.docs.isEmpty) {
                            return const Text(
                                "No monthly payments yet.");
                          }

                          return Column(
                            children: snap.data!.docs.map((doc) {
                              final m =
                                  doc.data() as Map<String, dynamic>;
                              final bool isPaid =
                                  m['status'] == 'paid';

                              return Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(m['month']),
                                  Text(
                                    isPaid ? 'PAID' : 'UNPAID',
                                    style: TextStyle(
                                      color: isPaid
                                          ? paidColor
                                          : dueColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          );
                        },
                      ),

                      const SizedBox(height: 16),

                      // ================= ADD NEXT MONTH =================
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text("Add Next Month Payment"),
                        onPressed: () async {
                          await _addNextMonthlyPayment(
                            bookingId: booking.id,
                            rentAmount: rentAmount.toInt(),
                          );

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Next month payment added'),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
