import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Admin Theme Palette
const Color adminPrimary = Color(0xFF3F51B5);
const Color adminBg = Color(0xFFF8F9FE);
const Color adminDark = Color(0xFF1A237E);

class AdminListingManagementPage extends StatelessWidget {
  const AdminListingManagementPage({super.key});

  // ---------------- REACTIVATE LISTING ----------------
  Future<void> _reactivateListing(BuildContext context, String docId, String title) async {
    // UPDATED: Changed 'active' to 'available' to match Homeowner app logic
    await FirebaseFirestore.instance
        .collection('houses')
        .doc(docId)
        .update({'status': 'available'});

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$title is now available for rent'),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ---------------- SUSPEND LISTING ----------------
  Future<void> _suspendListing(BuildContext context, String docId, String title) async {
    await FirebaseFirestore.instance
        .collection('houses')
        .doc(docId)
        .update({'status': 'suspended'});

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$title has been suspended'),
          backgroundColor: Colors.orange.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ---------------- DELETE LISTING ----------------
  Future<void> _deleteListing(BuildContext context, String docId, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Listing'),
        content: Text('Are you sure you want to delete "$title"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('houses').doc(docId).delete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$title deleted successfully'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: adminBg,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            const Text(
              "Property Listings",
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: adminDark),
            ),
            Text(
              "Monitor and moderate all house advertisements",
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 25),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('houses')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(child: Text('❌ Error loading listings'));
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: adminPrimary));
                  }

                  final docs = snapshot.data!.docs;

                  if (docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.house_siding_rounded, size: 80, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          const Text("No house listings found.", style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;

                      final title = data['title'] ?? 'No title';
                      final price = data['price'] ?? 0;
                      final status = data['status'] ?? 'available';
                      final houseType = data['houseType'] ?? '-';
                      final gender = data['genderPreference'] ?? '-';
                      final List images = data['images'] ?? [];

                      bool isSuspended = status == 'suspended';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: adminPrimary.withOpacity(0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: images.isNotEmpty
                                        ? Image.network(images.first, width: 60, height: 60, fit: BoxFit.cover)
                                        : Container(width: 60, height: 60, color: Colors.grey.shade200, child: const Icon(Icons.image)),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: adminDark)),
                                        const SizedBox(height: 4),
                                        _buildStatusBadge(status),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _infoTile(Icons.payments_outlined, "RM $price"),
                                  _infoTile(Icons.home_outlined, houseType),
                                  _infoTile(Icons.wc_outlined, gender),
                                ],
                              ),
                              const SizedBox(height: 16),
                              const Divider(height: 1),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  // Conditional Toggle Button
                                  isSuspended
                                      ? TextButton.icon(
                                          onPressed: () => _reactivateListing(context, doc.id, title),
                                          icon: const Icon(Icons.check_circle_outline, size: 18),
                                          label: const Text("Reactivate"),
                                          style: TextButton.styleFrom(foregroundColor: Colors.green.shade700),
                                        )
                                      : TextButton.icon(
                                          onPressed: () => _suspendListing(context, doc.id, title),
                                          icon: const Icon(Icons.block_flipped, size: 18),
                                          label: const Text("Suspend"),
                                          style: TextButton.styleFrom(foregroundColor: Colors.orange.shade800),
                                        ),
                                  const Spacer(),
                                  IconButton(
                                    onPressed: () => _deleteListing(context, doc.id, title),
                                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                                    tooltip: "Delete Listing",
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    // Logic: Color code by status type
    Color badgeColor;
    switch (status) {
      case 'available':
        badgeColor = Colors.green;
        break;
      case 'suspended':
        badgeColor = Colors.red;
        break;
      case 'booked':
        badgeColor = Colors.blue;
        break;
      default:
        badgeColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _infoTile(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 16, color: adminPrimary.withOpacity(0.6)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w500)),
      ],
    );
  }
}