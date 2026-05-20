import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PendingHouseApprovalsPage extends StatelessWidget {
  const PendingHouseApprovalsPage({super.key});

  // Helper to update status
  Future<void> updateHouseStatus(String houseId, String status) async {
    await FirebaseFirestore.instance
        .collection('houses')
        .doc(houseId)
        .update({'status': status});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Pending House Approvals",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Fetch all houses with "pending" status
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('houses')
                    .where('status', isEqualTo: 'pending')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text("No pending houses found."));
                  }

                  final houses = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: houses.length,
                    itemBuilder: (context, index) {
                      final house = houses[index];
                      final data = house.data() as Map<String, dynamic>;

                      final images = List<String>.from(data['images'] ?? []);

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 3,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // House title
                              Text(
                                data['houseType'] ?? 'Unknown House Type',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),

                              // House info
                              Text("Price: RM${data['price'] ?? '-'} / month"),
                              Text("Gender Preference: ${data['genderPreference'] ?? '-'}"),
                              if (data['location'] != null)
                                Text("Location: ${data['location']}"),

                              
                              // Owner info
                                Text("Added by: ${data['homeownerName']}"),

                                Text("Contact: ${data['contactNumber']}"),

                              const SizedBox(height: 15),
                              
                              // Image carousel
                              if (images.isNotEmpty)
                                SizedBox(
                                  height: 150,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: images.length,
                                    itemBuilder: (context, imgIndex) {
                                      return Padding(
                                        padding: const EdgeInsets.only(right: 8),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: Image.network(
                                            images[imgIndex],
                                            width: 150,
                                            height: 150,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              const SizedBox(height: 10),

                              

                              // Action buttons
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                    ),
                                    icon: const Icon(Icons.check),
                                    label: const Text("Approve"),
                                    onPressed: () async {
                                      await updateHouseStatus(house.id, 'approved');
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text("House approved successfully."),
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 10),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                    ),
                                    icon: const Icon(Icons.close),
                                    label: const Text("Reject"),
                                    onPressed: () async {
                                      await updateHouseStatus(house.id, 'rejected');
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text("House rejected."),
                                        ),
                                      );
                                    },
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
}
