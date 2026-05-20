import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'edit_house_page.dart';

// Theme Palette
const Color primaryColor = Color(0xFF1E88E5);
const Color deleteColor = Colors.red;
const Color editColor = Color(0xFFFFA726); 
const Color suspendedColor = Colors.orange; // Color for suspended state

class ManagePropertiesPage extends StatefulWidget {
  const ManagePropertiesPage({super.key});

  @override
  State<ManagePropertiesPage> createState() => _ManagePropertiesPageState();
}

class _ManagePropertiesPageState extends State<ManagePropertiesPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ---------------- DELETE PROPERTY ----------------
  Future<void> _deleteProperty(BuildContext context, String id) async {
    final bool confirm = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: const Text('Confirm Deletion'),
            content: const Text('Are you sure you want to permanently delete this property listing?'),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete', style: TextStyle(color: deleteColor)),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    await _firestore.collection('houses').doc(id).delete();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Property deleted successfully'), backgroundColor: deleteColor),
    );
  }

  // ---------------- EDIT PROPERTY ----------------
  void _editProperty(BuildContext context, String propertyId, String status) {
    // UPDATED LOGIC: Allow editing if status is available OR suspended
    if (status != 'available' && status != 'suspended') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('This property is $status and cannot be edited.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditHousePage(houseId: propertyId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;

    if (uid == null) {
      return const Center(child: Text('Please log in to manage properties.'));
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('houses')
            .where('homeownerId', isEqualTo: uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: primaryColor));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.house_siding, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 10),
                  const Text('No properties added yet.', style: TextStyle(fontSize: 18, color: Colors.grey)),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final docId = docs[index].id;
              final data = docs[index].data() as Map<String, dynamic>;

              final firstImage = data['images'] != null && (data['images'] as List).isNotEmpty
                  ? (data['images'] as List).first
                  : null;

              final status = data['status'] ?? 'available';
              final title = data['title'] ?? 'Untitled House';
              final price = data['price']?.toString() ?? 'N/A';

              // Logic check for button states
              final bool isEditable = (status == 'available' || status == 'suspended');

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Thumbnail
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: firstImage != null
                            ? Image.network(firstImage, width: 90, height: 90, fit: BoxFit.cover)
                            : Container(
                                width: 90,
                                height: 90,
                                color: Colors.grey.shade200,
                                child: const Icon(Icons.house, size: 40, color: Colors.grey),
                              ),
                      ),
                      const SizedBox(width: 15),

                      // 2. Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text('RM $price / month',
                                style: const TextStyle(color: primaryColor, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            _buildStatusChip(status),
                          ],
                        ),
                      ),

                      // 3. Action Buttons
                      Column(
                        children: [
                          IconButton(
                            icon: Icon(Icons.edit, color: isEditable ? editColor : Colors.grey),
                            onPressed: () => _editProperty(context, docId, status),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete, color: isEditable ? deleteColor : Colors.grey),
                            onPressed: isEditable ? () => _deleteProperty(context, docId) : null,
                          ),
                        ],
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

  Widget _buildStatusChip(String status) {
    Color chipColor;
    IconData icon;

    switch (status) {
      case 'available':
        chipColor = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'suspended':
        chipColor = Colors.orange;
        icon = Icons.pause_circle_filled;
        break;
      case 'booked':
        chipColor = Colors.blue;
        icon = Icons.bookmark;
        break;
      default:
        chipColor = Colors.red;
        icon = Icons.lock;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: chipColor),
          const SizedBox(width: 4),
          Text(
            status.toUpperCase(),
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: chipColor),
          ),
        ],
      ),
    );
  }
}