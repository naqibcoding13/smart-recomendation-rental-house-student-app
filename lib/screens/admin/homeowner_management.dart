import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

// Admin Theme Palette
const Color adminPrimary = Color(0xFF3F51B5);
const Color adminBg = Color(0xFFF8F9FE);
const Color adminDark = Color(0xFF1A237E);

class HomeownerManagementPage extends StatefulWidget {
  const HomeownerManagementPage({super.key});

  @override
  State<HomeownerManagementPage> createState() =>
      _HomeownerManagementPageState();
}

class _HomeownerManagementPageState extends State<HomeownerManagementPage> {
  final CollectionReference homeownersCollection =
      FirebaseFirestore.instance.collection('homeowners');

  Future<void> _approveHomeowner(String id, String name) async {
    await homeownersCollection.doc(id).update({
      'status': 'approved',
      'approvedAt': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$name account has been approved'),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _deleteHomeowner(String id, String name) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Remove Homeowner"),
        content: Text(
            "Are you sure you want to delete $name? This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete",
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await homeownersCollection.doc(id).delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$name removed successfully'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _viewOwnershipPdf(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Unable to open document")),
      );
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
              "Homeowner Management",
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: adminDark),
            ),
            Text(
              "Approve homeowners before they can use the system",
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 25),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: homeownersCollection.snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: adminPrimary));
                  }

                  if (!snapshot.hasData ||
                      snapshot.data!.docs.isEmpty) {
                    return const Center(
                        child: Text("No homeowners found"));
                  }

                  final homeowners = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: homeowners.length,
                    itemBuilder: (context, index) {
                      final doc = homeowners[index];
                      final data =
                          doc.data() as Map<String, dynamic>;

                      final name = data['fullName'] ?? 'Unknown';
                      final status = data['status'] ?? 'pending';
                      final pdfUrl = data['ownershipPdfUrl'];

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  adminPrimary.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: adminPrimary
                                        .withOpacity(0.1),
                                    child: const Icon(
                                        Icons.real_estate_agent,
                                        color: adminPrimary),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(name,
                                            style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight:
                                                    FontWeight.bold)),
                                        _buildStatusBadge(status),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _infoRow(Icons.email, data['email']),
                              _infoRow(
                                  Icons.phone,
                                  data['phoneNumber'] ??
                                      'No phone'),
                              _infoRow(Icons.badge,
                                  data['icNumber'] ?? 'No IC'),

                              if (pdfUrl != null)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(top: 10),
                                  child: TextButton.icon(
                                    onPressed: () =>
                                        _viewOwnershipPdf(pdfUrl),
                                    icon: const Icon(
                                        Icons.picture_as_pdf),
                                    label: const Text(
                                        "View Ownership Document"),
                                  ),
                                ),

                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () =>
                                          _deleteHomeowner(
                                              doc.id, name),
                                      icon: const Icon(
                                          Icons.delete_outline),
                                      label:
                                          const Text("Remove"),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor:
                                            Colors.redAccent,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  if (status != 'approved')
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () =>
                                            _approveHomeowner(
                                                doc.id, name),
                                        icon: const Icon(
                                            Icons.verified),
                                        label:
                                            const Text("Approve"),
                                        style:
                                            ElevatedButton.styleFrom(
                                          backgroundColor:
                                              adminPrimary,
                                        ),
                                      ),
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
    final isApproved = status == 'approved';
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isApproved
            ? Colors.green.shade50
            : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: isApproved
              ? Colors.green.shade700
              : Colors.orange.shade700,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String? text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon,
              size: 18,
              color: adminPrimary.withOpacity(0.6)),
          const SizedBox(width: 12),
          Text(text ?? '-', style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}
