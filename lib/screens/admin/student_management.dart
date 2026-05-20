import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Matching the Admin Dashboard Palette
const Color adminPrimary = Color(0xFF3F51B5); 
const Color adminBg = Color(0xFFF8F9FE);
const Color adminDark = Color(0xFF1A237E);

class StudentManagementPage extends StatelessWidget {
  const StudentManagementPage({super.key});

  // Function to handle student deletion with success feedback
  Future<void> _deleteStudent(BuildContext context, String studentId, String studentName) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Delete Student Account"),
        content: Text("Are you sure you want to remove $studentName? This action will permanently delete their data."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('students').doc(studentId).delete();
        
        // SUCCESS FEEDBACK
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Text("Account for $studentName deleted successfully"),
                ],
              ),
              backgroundColor: Colors.green.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: Could not delete student")),
          );
        }
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
              "Student Registry",
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: adminDark),
            ),
            Text(
              "Manage active student accounts and credentials",
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 25),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('students').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: adminPrimary));
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.group_off_outlined, size: 80, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          const Text("No students currently registered.", style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    );
                  }

                  final students = snapshot.data!.docs;

                  return ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: students.length,
                    itemBuilder: (context, index) {
                      final student = students[index];
                      final data = student.data() as Map<String, dynamic>;
                      final name = data['name'] ?? 'Unknown Student';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 15),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: adminPrimary.withOpacity(0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            leading: CircleAvatar(
                              backgroundColor: adminPrimary.withOpacity(0.1),
                              child: Text(
                                name[0].toUpperCase(),
                                style: const TextStyle(color: adminPrimary, fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(
                              name,
                              style: const TextStyle(fontWeight: FontWeight.bold, color: adminDark),
                            ),
                            subtitle: Text(data['email'] ?? '-', style: const TextStyle(fontSize: 12)),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              onPressed: () => _deleteStudent(context, student.id, name),
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(72, 0, 20, 20),
                                child: Column(
                                  children: [
                                    const Divider(height: 1),
                                    const SizedBox(height: 12),
                                    _buildDetailRow(Icons.face, "Gender", data['gender'] ?? 'Not set'),
                                    _buildDetailRow(Icons.calendar_today, "Joined", data['registeredDate'] ?? 'Unknown'),
                                    _buildDetailRow(Icons.verified_user, "Status", "Verified Account", color: Colors.green),
                                  ],
                                ),
                              )
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

  Widget _buildDetailRow(IconData icon, String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text("$label: ", style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(value, style: TextStyle(color: color ?? adminDark, fontWeight: FontWeight.w500, fontSize: 13)),
        ],
      ),
    );
  }
}