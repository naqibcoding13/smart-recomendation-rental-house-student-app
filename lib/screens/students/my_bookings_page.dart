import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; 

// Define consistent colors
const Color primaryColor = Color(0xFF1E88E5);
const Color acceptedColor = Color(0xFF4CAF50); // Green
const Color rejectedColor = Colors.red;
const Color pendingColor = Color(0xFFFFA726); // Orange

class MyBookingsPage extends StatefulWidget {
  const MyBookingsPage({super.key});

  @override
  State<MyBookingsPage> createState() => _MyBookingsPageState();
}

class _MyBookingsPageState extends State<MyBookingsPage> {
  final _auth = FirebaseAuth.instance;

  // --- Status Helpers ---

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
      case 'fully_paid':
      case 'deposit_paid': // Added deposit_paid here for visual consistency
        return acceptedColor;
      case 'rejected':
        return rejectedColor;
      default:
        return pendingColor;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
      case 'fully_paid':
      case 'deposit_paid':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.hourglass_empty;
    }
  }

  // Helper for displaying data rows consistently
  Widget _buildDataRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;

    // 💥 FIX: The entire page content is now wrapped in a Scaffold.
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Booking History'),
        backgroundColor: primaryColor,
      ),
      body: currentUser == null
          ? const Center(child: Text('Please log in to view your bookings'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('bookings')
                  .where('studentId', isEqualTo: currentUser.uid)
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: primaryColor));
                }
                
                // --- Handle No Data ---
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long, size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        const Text(
                          'You have no bookings yet.',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }
                
                // --- Display Bookings ---
                final bookings = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: bookings.length,
                  itemBuilder: (context, index) {
                    final booking = bookings[index];
                    final houseTitle = booking['houseTitle'] ?? 'Unknown House';
                    final status = (booking['status'] ?? 'pending').toString();
                    final timestamp = booking['timestamp'] as Timestamp?;
                    
                    final statusColor = _getStatusColor(status);
                    final statusIcon = _getStatusIcon(status);

                    final dateString = timestamp != null
                        ? DateFormat('MMM dd, yyyy').format(timestamp.toDate())
                        : 'Unknown Date';

                    return Card(
                        elevation: 6,
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: statusColor.withOpacity(0.5), width: 1.5), 
                        ),
                        child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                    // --- HEADER (Title & Date) ---
                                    Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                            Expanded(
                                                child: Text(
                                                    houseTitle,
                                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: primaryColor),
                                                    overflow: TextOverflow.ellipsis,
                                                ),
                                            ),
                                            const SizedBox(width: 10),
                                            Text(dateString, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                                        ],
                                    ),
                                    const Divider(height: 25),

                                    // --- STATUS BADGE ---
                                    Row(
                                        children: [
                                            Icon(statusIcon, size: 20, color: statusColor),
                                            const SizedBox(width: 8),
                                            Text(
                                                'Status:',
                                                style: TextStyle(fontSize: 15, color: statusColor),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                                status.toUpperCase().replaceAll('_', ' '),
                                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: statusColor),
                                            ),
                                        ],
                                    ),
                                    const SizedBox(height: 12),
                                    
                                    // --- ACTION / NEXT STEP ---
                                    if (status == 'accepted' || status == 'deposit_paid')
                                        SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton.icon(
                                                onPressed: () {
                                                    // TODO: Navigate to the Payments tab (Index 3 on StudentDashboard)
                                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Go to Payments tab to complete payment.')));
                                                },
                                                icon: const Icon(Icons.payment, color: Colors.white),
                                                label: const Text('Complete Payment', style: TextStyle(color: Colors.white)),
                                                style: ElevatedButton.styleFrom(backgroundColor: pendingColor),
                                            ),
                                        ),
                                        
                                    if (status == 'pending')
                                        Text('Awaiting homeowner review. You will be notified shortly.', style: TextStyle(color: pendingColor)),

                                    if (status == 'rejected')
                                        Text('Your booking was rejected by the homeowner.', style: TextStyle(color: rejectedColor)),
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