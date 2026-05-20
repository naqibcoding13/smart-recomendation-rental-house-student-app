import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // For date formatting

// Define consistent colors for professional look
const Color primaryColor = Color(0xFF1E88E5);
const Color acceptedColor = Color(0xFF4CAF50);
const Color rejectedColor = Colors.red;
const Color pendingColor = Color(0xFFFFA726);
const Color backgroundColor = Color(0xFFF5F5F5);

class BookingsPage extends StatelessWidget {
  const BookingsPage({super.key});

  // Helper for status badge
  Widget _buildStatusBadge(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }

  // Helper for data rows
  Widget _buildDataRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$label:',
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

Future<void> _updateBookingStatus(
  String bookingId,
  String status,
  BuildContext context,
) async {
  try {
    final FirebaseFirestore _firestore = FirebaseFirestore.instance;
    final bookingRef = _firestore.collection('bookings').doc(bookingId);

    if (status == 'accepted') {
      // 1️⃣ Get booking data
      final bookingSnap = await bookingRef.get();
      final bookingData = bookingSnap.data() as Map<String, dynamic>?;

      if (bookingData == null) {
        throw 'Booking not found';
      }

      final String? houseId = bookingData['houseId'];
      double rent = 0;
      String? agreementUrl;

      // 2️⃣ Get house data
      if (houseId != null && houseId.isNotEmpty) {
        final houseRef = _firestore.collection('houses').doc(houseId);
        final houseSnap = await houseRef.get();
        final houseData = houseSnap.data() as Map<String, dynamic>?;

        if (houseData != null) {
          final priceField = houseData['price'];
          if (priceField is num) {
            rent = priceField.toDouble();
          }
          agreementUrl = houseData['rentalAgreementUrl'];

          // 🔥 3️⃣ MARK HOUSE AS BOOKED (KEY CHANGE)
          await houseRef.update({
            'availabilityStatus': 'booked',
          });
        }
      }

      final double deposit = rent * 0.5;

      // 4️⃣ Update booking document
      await bookingRef.update({
        'status': 'accepted',

        // 💰 Payment fields
        'rentAmount': rent,
        'depositAmount': deposit,
        'totalAmount': rent,
        'paymentStatus': 'pending',
        'depositPaidAt': null,
        'fullPaymentPaidAt': null,

        // 👤 Student info
        'studentName': bookingData['name'],
        'studentEmail': bookingData['email'],
        'studentPhone': bookingData['phone'] ?? 'No Phone',

        // 📄 Agreement
        'rentalAgreementUrl': agreementUrl,
      });
    } else {
      // Rejected
      await bookingRef.update({
        'status': status,
      });
    }

    if (context.mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Success'),
          content: Text(
            'Booking ${status == 'accepted' ? 'accepted' : 'rejected'} successfully!',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update booking status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}


  Future<void> _deleteBooking(String bookingId, BuildContext context) async {
    try {
      final FirebaseFirestore _firestore = FirebaseFirestore.instance;
      await _firestore.collection('bookings').doc(bookingId).delete();
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Success'),
            content: const Text('Booking deleted successfully!'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete booking: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final FirebaseAuth _auth = FirebaseAuth.instance;
    final FirebaseFirestore _firestore = FirebaseFirestore.instance;
    final uid = _auth.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Booking Requests',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor,
        elevation: 2,
        centerTitle: true,
      ),
      backgroundColor: backgroundColor,
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('bookings')
            .where('homeownerId', isEqualTo: uid)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: primaryColor),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No booking requests yet.',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'New requests will appear here.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;

              final studentName = data['name'] ?? 'Unknown Student';
              final studentEmail = data['email'] ?? 'No Email';
              final studentPhone = data['phone'] ?? 'No Phone';
              final houseTitle = data['houseTitle'] ?? 'Unknown House';
              final status = (data['status'] ?? 'pending').toString();
              final timestamp = data['timestamp'] as Timestamp?;
              final bookingDate = timestamp != null
                  ? DateFormat('MMM dd, yyyy - hh:mm a').format(timestamp.toDate())
                  : 'Unknown Date';

              Color statusColor;
              switch (status) {
                case 'accepted':
                  statusColor = acceptedColor;
                  break;
                case 'rejected':
                  statusColor = rejectedColor;
                  break;
                default:
                  statusColor = pendingColor;
              }

              return Card(
                elevation: 6,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: status == 'pending'
                      ? BorderSide(color: pendingColor, width: 1.5)
                      : BorderSide.none,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: House Title & Status
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              houseTitle,
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _buildStatusBadge(status, statusColor),
                        ],
                      ),
                      const Divider(height: 20),

                      // Student Details Section
                      const Text(
                        'Student Details',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildDataRow(Icons.person_outline, 'Name', studentName),
                      _buildDataRow(Icons.email_outlined, 'Email', studentEmail),
                      _buildDataRow(Icons.phone_android, 'Phone', studentPhone),
                      const Divider(height: 20),

                      // Booking Date
                      _buildDataRow(Icons.calendar_today, 'Requested On', bookingDate),

                      const SizedBox(height: 16),

                      // Actions
                      if (status == 'pending')
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _updateBookingStatus(doc.id, 'accepted', context),
                                icon: const Icon(Icons.check, color: Colors.white),
                                label: const Text('Accept'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: acceptedColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _updateBookingStatus(doc.id, 'rejected', context),
                                icon: const Icon(Icons.close, color: Colors.white),
                                label: const Text('Reject'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: rejectedColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                      // Delete Button for all statuses
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.grey),
                          tooltip: 'Delete Booking',
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete Booking'),
                                content: const Text(
                                  'Are you sure you want to delete this booking? This action cannot be undone.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(true),
                                    child: const Text('Delete', style: TextStyle(color: rejectedColor)),
                                  ),
                                ],
                              ),
                            ) ?? false;
                            if (confirm) {
                              await _deleteBooking(doc.id, context);
                            }
                          },
                        ),
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