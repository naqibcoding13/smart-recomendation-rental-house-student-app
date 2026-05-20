import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

// Colors
const Color primaryColor = Color(0xFF1E88E5);
const Color paidColor = Color(0xFF4CAF50); // Green
const Color pendingColor = Color(0xFFFFA726); // Orange
const Color dangerColor = Color(0xFFE53935); // Red

class PaymentsPage extends StatefulWidget {
  const PaymentsPage({super.key});

  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  late ScaffoldMessengerState _messenger;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messenger = ScaffoldMessenger.of(context);
  }

  // ToyyibPay credentials (IMPORTANT: Should be secured)
  final String toyibpaySecretKey = "uq0jngoa-rjsv-70ax-87ke-xa95e0qgfevb";
  final String toyibpayCategoryCode = "zgo2tf0d";

  /* ======================= PAYMENT BILL LOGIC ======================= */

  Future<void> _createPaymentBill({
    required String bookingId,
    required double amount,
    required String name,
    required String email,
    required String phone,
    required String houseTitle,
    bool isDeposit = false,
    String? monthlyPaymentId,
  }) async {
    if (amount <= 0) {
      _messenger.showSnackBar(const SnackBar(content: Text("Invalid payment amount")));
      return;
    }

    try {
      final amountInSen = (amount * 100).round().toString();

      String formattedPhone = phone.startsWith("0")
          ? phone.replaceFirst("0", "60")
          : phone.startsWith("60")
              ? phone
              : "60$phone";

      final response = await http.post(
        Uri.parse("https://dev.toyyibpay.com/index.php/api/createBill"),
        body: {
          'userSecretKey': toyibpaySecretKey,
          'categoryCode': toyibpayCategoryCode,
          'billName': houseTitle,
          'billDescription': isDeposit
              ? 'Deposit Payment'
              : 'Monthly Rental Payment',
          'billAmount': amountInSen,
          'billTo': name,
          'billEmail': email,
          'billPhone': formattedPhone,
          'billReturnUrl': 'https://google.com',
          'billCallbackUrl': 'https://google.com',
          'billPayorInfo': '1',
          'billPriceSetting': '1',
        },
      );

      final data = jsonDecode(response.body);

      if (data is List && data.isNotEmpty && data[0]['BillCode'] != null) {
        await launchUrl(
          Uri.parse("https://dev.toyyibpay.com/${data[0]['BillCode']}"),
          mode: LaunchMode.externalApplication,
        );

        // Show confirmation dialog after launching payment portal
        if (monthlyPaymentId != null) {
          _confirmMonthlyPayment(monthlyPaymentId, amount);
        } else {
          _confirmDepositPayment(bookingId, amount);
        }
      } else {
        _messenger.showSnackBar(
          SnackBar(content: Text("ToyyibPay Error: Failed to create bill.")),
        );
      }
    } catch (e) {
      _messenger.showSnackBar(
        SnackBar(content: Text("Payment error: ${e.toString()}")),
      );
    }
  }

  /* ======================= CONFIRM DIALOGS ======================= */

  void _confirmDepositPayment(String bookingId, double amount) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text("Deposit Payment Confirmation"),
        content: Text("Confirm if payment of RM ${amount.toStringAsFixed(2)} was successful."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("NO")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _firestore.collection('bookings').doc(bookingId).update({
                'paymentStatus': 'deposit_paid',
                'depositPaidAt': FieldValue.serverTimestamp(),
              });
              _messenger.showSnackBar(const SnackBar(content: Text("Deposit paid!")));
            },
            style: ElevatedButton.styleFrom(backgroundColor: paidColor, foregroundColor: Colors.white),
            child: const Text("YES, PAID"),
          ),
        ],
      ),
    );
  }

  void _confirmMonthlyPayment(String monthlyId, double amount) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text("Monthly Rent Confirmation"),
        content: Text("Confirm if the monthly rent of RM ${amount.toStringAsFixed(2)} was successfully paid."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("NO")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _firestore.collection('monthly_payments').doc(monthlyId).update({
                'status': 'paid',
                'paidAt': FieldValue.serverTimestamp(),
              });
              _messenger.showSnackBar(const SnackBar(content: Text("Monthly payment marked as paid!")));
            },
            style: ElevatedButton.styleFrom(backgroundColor: paidColor, foregroundColor: Colors.white),
            child: const Text("YES, PAID"),
          ),
        ],
      ),
    );
  }

  /* ======================= Rental Aggrement ======================= */

  Future<void> _openPdf(String url) async {
    try {
      final uri = Uri.parse(url);
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      _messenger.showSnackBar(
        SnackBar(content: Text("Failed to open agreement: $e")),
      );
    }
  }
  
  // --- UI Helpers ---

  // Helper for displaying a key financial row
  Widget _buildFinancialRow(String label, double amount, {IconData? icon, Color? color}) {
    final currencyFormat = NumberFormat.currency(locale: 'en_MY', symbol: 'RM ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (icon != null) Icon(icon, size: 18, color: color ?? Colors.grey),
              if (icon != null) const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(fontSize: 16, color: Colors.black87),
              ),
            ],
          ),
          Text(
            currencyFormat.format(amount),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  /* ======================= UI ======================= */

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;

    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text("Not logged in.")),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Payments & Schedule"), backgroundColor: primaryColor, foregroundColor: Colors.white),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('bookings')
            .where('studentId', isEqualTo: uid)
            .where('status', whereIn: ['accepted', 'deposit_paid', 'fully_paid']) // Only show actionable bookings
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: primaryColor));
          }

          final bookings = snapshot.data?.docs ?? [];

          if (bookings.isEmpty) {
            return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.payment, size: 80, color: Colors.grey.shade300),
                    const SizedBox(height: 10),
                    const Text("No active payments due.", style: TextStyle(fontSize: 18, color: Colors.grey)),
                    Text("Payments appear after a booking is accepted.", style: TextStyle(color: Colors.grey.shade600)),
                  ],
                ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              final booking = bookings[index];
              final data = booking.data() as Map<String, dynamic>;

              final deposit = (data['depositAmount'] ?? 0).toDouble();
              final rent = (data['rentAmount'] ?? 0).toDouble();
              final paymentStatus = data['paymentStatus'] as String? ?? 'pending';

              // Determine Deposit Status
              final isDepositPaid = paymentStatus == 'deposit_paid' || paymentStatus == 'fully_paid';
              final isFullyPaid = paymentStatus == 'fully_paid';

              // Get student info for payment transfer
              final studentInfo = {
                'name': data['name'],
                'email': data['email'],
                'phone': data['phone'],
                'houseTitle': data['houseTitle'],
              };


              return Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  // Highlight if payment is still due
                  side: isFullyPaid ? BorderSide.none : const BorderSide(color: pendingColor, width: 2), 
                ),
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- HEADER & GLOBAL STATUS ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              studentInfo['houseTitle'] ?? "House Details",
                              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: primaryColor),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isFullyPaid ? paidColor.withOpacity(0.15) : pendingColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isFullyPaid ? "FULLY PAID" : "PAYMENT DUE",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isFullyPaid ? paidColor : pendingColor,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const Divider(height: 25),

                      // --- RENTAL AGREEMENT ---
                      if (data['rentalAgreementUrl'] != null && data['rentalAgreementUrl'] is String && data['rentalAgreementUrl'].isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 15.0),
                          child: TextButton.icon(
                            icon: const Icon(Icons.description, color: primaryColor),
                            label: const Text("View/Download Rental Agreement", style: TextStyle(color: primaryColor)),
                            onPressed: () => _openPdf(data['rentalAgreementUrl']),
                          ),
                        )
                      else 
                        const Padding(
                          padding: EdgeInsets.only(bottom: 10.0),
                          child: Text("Rental agreement pending upload by homeowner.", style: TextStyle(color: Colors.grey)),
                        ),
                      
                      // --- DEPOSIT PAYMENT STATUS ---
                      _buildFinancialRow(
                        "Deposit Amount", deposit, 
                        icon: isDepositPaid ? Icons.check_circle_outline : Icons.warning_amber, 
                        color: isDepositPaid ? paidColor : dangerColor,
                      ),
                      
                      const SizedBox(height: 15),

                      // Deposit Action Button
                      if (!isDepositPaid)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              _createPaymentBill(
                                bookingId: booking.id,
                                amount: deposit,
                                name: studentInfo['name']!,
                                email: studentInfo['email']!,
                                phone: studentInfo['phone']!,
                                houseTitle: studentInfo['houseTitle']!,
                                isDeposit: true,
                              );
                            },
                            icon: const Icon(Icons.payment, color: Colors.white),
                            label: Text("PAY DEPOSIT RM ${deposit.toStringAsFixed(2)}"),
                            style: ElevatedButton.styleFrom(backgroundColor: dangerColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                          ),
                        ),
                      
                      const Divider(height: 30),

                      /* ================= MONTHLY PAYMENTS SCHEDULE ================= */
                      const Text(
                        "Monthly Payment Schedule",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const SizedBox(height: 10),


                      StreamBuilder<QuerySnapshot>(
                        stream: _firestore
                            .collection('monthly_payments')
                            .where('bookingId', isEqualTo: booking.id)
                            .orderBy('dueDate')
                            .snapshots(),
                        builder: (context, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                          }
                          if (!isDepositPaid) {
                            return const Text("Schedule appears once deposit is paid.", style: TextStyle(color: Colors.grey));
                          }
                          
                          final monthlyDocs = snap.data?.docs ?? [];
                          if (monthlyDocs.isEmpty) {
                            return const Text("Monthly schedule not generated yet.", style: TextStyle(color: Colors.grey));
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: monthlyDocs.map((doc) {
                              final m = doc.data() as Map<String, dynamic>;
                              final isPaid = m['status'] == 'paid';
                              final amount = (m['amount'] ?? 0).toDouble();
                              final month = m['month'] as String? ?? 'N/A';
                            final dueDateTimestamp = m['dueDate'] as Timestamp?;
                            final dueDate = dueDateTimestamp != null ? DateFormat('MMM dd, yyyy').format(dueDateTimestamp.toDate()) : 'N/A';
                            
                            final actionColor = isPaid ? paidColor : pendingColor;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                                decoration: BoxDecoration(
                                  color: isPaid ? paidColor.withOpacity(0.05) : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                    children: [
                                      // Icon/Status
                                      Icon(isPaid ? Icons.check_box : Icons.calendar_today, color: actionColor, size: 20),
                                      const SizedBox(width: 10),
                                      
                                      // Details
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('$month Payment', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                            Text('Due: $dueDate', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                          ],
                                        ),
                                      ),
                                      
                                      // Amount & Button
                                      Text(
                                        "RM ${amount.toStringAsFixed(2)}", 
                                        style: TextStyle(fontWeight: FontWeight.bold, color: actionColor),
                                      ),
                                      const SizedBox(width: 10),
                                      isPaid
                                        ? const Icon(Icons.paid, color: paidColor)
                                        : SizedBox(
                                          height: 35,
                                          child: ElevatedButton(
                                              onPressed: () {
                                                _createPaymentBill(
                                                  bookingId: booking.id,
                                                  amount: amount,
                                                  name: studentInfo['name']!,
                                                  email: studentInfo['email']!,
                                                  phone: studentInfo['phone']!,
                                                  houseTitle: studentInfo['houseTitle']!,
                                                  monthlyPaymentId: doc.id,
                                                );
                                              },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: pendingColor,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 10),
                                            minimumSize: Size.zero,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                                          ),
                                              child: const Text("Pay"),
                                            ),
                                        ),
                                    ],
                                ),
                              );
                            }).toList(),
                          );
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