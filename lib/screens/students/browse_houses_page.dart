import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';

// 💡 Define consistent colors for branding
const Color primaryColor = Color(0xFF1E88E5); // Deep Blue
const Color secondaryColor = Color(0xFF42A5F5); // Light Blue
const Color successColor = Color(0xFF4CAF50); // Green for success

class BrowseHousesPage extends StatefulWidget {
  const BrowseHousesPage({super.key});

  @override
  State<BrowseHousesPage> createState() => _BrowseHousesPageState();
}

class _BrowseHousesPageState extends State<BrowseHousesPage> {
  final CollectionReference _housesRef =
      FirebaseFirestore.instance.collection('houses');
  final Map<String, String> _addressCache = {};
  bool _isLoadingMap = false;

  // --- Logic for Address Lookup ---
  Future<String> _getAddress(double lat, double lng, String docId) async {
    if (_addressCache.containsKey(docId)) {
      return _addressCache[docId]!;
    }

    final url =
        "https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lng&format=json";

    final response = await http.get(
      Uri.parse(url),
      headers: {"User-Agent": "Flutter App"},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final address = data["display_name"] ?? "Unknown address";
      _addressCache[docId] = address;
      return address;
    }

    return "Unknown address";
  }

  // --- Logic for Map Launch ---
  Future<void> _openMap(double lat, double lng) async {
    final googleUrl = "https://www.google.com/maps/search/?api=1&query=$lat,$lng";
    final uri = Uri.parse(googleUrl);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not open Google Maps")),
        );
      }
    }
  }
  
  // --- Logic for Booking ---
  Future<void> _bookHouse(String houseId, String title, String? homeownerId, double rentAmount) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You must be logged in to book")),
      );
      return;
    }

    if (homeownerId == null || homeownerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Homeowner information unavailable")),
      );
      return;
    }

    final studentSnap = await FirebaseFirestore.instance
        .collection('students')
        .doc(uid)
        .get();

    final studentData = studentSnap.data() ?? {};

    final studentName = studentData['name'] ?? 'Student';
    final studentEmail = studentData['email'] ?? '';
    final studentPhone = studentData['phone'] ?? '';

    await FirebaseFirestore.instance.collection('bookings').add({
      'houseId': houseId,
      'houseTitle': title,
      'studentId': uid,
      'homeownerId': homeownerId,
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
      'name': studentName,
      'email': studentEmail,
      'phone': studentPhone,
      'rentAmount': rentAmount,
      'depositAmount': rentAmount * 0.5,
      'paymentStatus': 'pending',
      'depositPaidAt': null,
      'fullPaymentPaidAt': null,
      'totalAmount': rentAmount,
    });

    _showSuccessDialog();
  }

  // --- Success Dialog (Consistent UI) ---
  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16), 
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Success Checkmark Animation
                Container(
                  height: 80,
                  width: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: successColor.withOpacity(0.1),
                    border: Border.all(color: successColor, width: 3),
                  ),
                  child: const Icon(
                    Icons.check_circle_outline, 
                    size: 50,
                    color: successColor,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Booking Request Sent!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'The homeowner has been notified waiting to approve.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('OK', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- UI Build Methods ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Houses 🏘️'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: Colors.grey.shade100, // Light background for card contrast
      body: StreamBuilder<QuerySnapshot>(
      stream: _housesRef
              .where('availabilityStatus', isEqualTo: 'available')
              .snapshots(),

        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: primaryColor));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No houses available right now.'));
          }

          final houses = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            itemCount: houses.length,
            itemBuilder: (context, index) {
              final house = houses[index];
              final data = house.data() as Map<String, dynamic>? ?? {};

              if (data.isEmpty) return const SizedBox.shrink();

              final title = data['title'] ?? 'Untitled House';
              final price = data['price']?.toString() ?? 'Not specified';
              final gender = data['genderPreference'] ?? 'Any';
              final phone = data['phoneNumber'] ?? 'Not provided';
              final houseType = data['houseType'] ?? 'Not specified';
              final List images = data['images'] ?? [];
              final double? lat = data['latitude'] is num ? data['latitude'].toDouble() : null;
              final double? lng = data['longitude'] is num ? data['longitude'].toDouble() : null;
              final String? homeownerId = data['homeownerId'] is String ? data['homeownerId'] : null;
              final double rentAmount = data['price'] is num ? (data['price'] as num).toDouble() : 0.0;

              return FutureBuilder<String>(
                future: (lat != null && lng != null)
                    ? _getAddress(lat, lng, house.id)
                    : Future.value("Location unavailable"),
                builder: (context, addressSnapshot) {
                  final address = addressSnapshot.data ?? "Loading address...";

                  return HouseListingCard(
                    title: title,
                    price: price,
                    gender: gender,
                    houseType: houseType,
                    address: address, // Passing the full address
                    phone: phone,
                    images: images,
                    isLoadingMap: _isLoadingMap,
                    onViewMap: (lat != null && lng != null && !_isLoadingMap) 
                        ? () async {
                              setState(() => _isLoadingMap = true);
                              await _openMap(lat, lng);
                              setState(() => _isLoadingMap = false);
                            }
                        : null,
                    onBookNow: () => _bookHouse(
                      house.id,
                      title,
                      homeownerId,
                      rentAmount,
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

// ===================== WIDGETS FOR REDESIGN (Functional Components) =====================

// 📦 Professional Listing Card Widget
class HouseListingCard extends StatelessWidget {
  final String title;
  final String price;
  final String gender;
  final String houseType;
  final String address;
  final String phone;
  final List images;
  final bool isLoadingMap;
  final VoidCallback? onViewMap;
  final VoidCallback onBookNow;

  const HouseListingCard({
    super.key,
    required this.title,
    required this.price,
    required this.gender,
    required this.houseType,
    required this.address,
    required this.phone,
    required this.images,
    required this.isLoadingMap,
    this.onViewMap,
    required this.onBookNow,
  });

  Widget _buildInfoPill(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. IMAGE CAROUSEL 
          _ImageCarousel(images: images),
          
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 2. TITLE & PRICE HEADER
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'RM $price',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                
                // 3. ADDRESS (Showing the full address)
                Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.grey, size: 18),
                    const SizedBox(width: 6),
                    Expanded( 
                      child: Text(
                        address, // Displaying the full address
                        style: const TextStyle(color: Colors.grey, fontSize: 14),
                        maxLines: 2, 
                        overflow: TextOverflow.ellipsis, 
                      ),
                    ),
                  ],
                ),
                const Divider(height: 25),

                // 4. INFORMATION PILLS (House Type, Gender, Contact)
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: [
                    _buildInfoPill(Icons.apartment, houseType, Colors.green.shade700),
                    _buildInfoPill(Icons.group, 'Gender: $gender', Colors.orange.shade700),
                    // Contact information moved to a pill
                    _buildInfoPill(Icons.phone_android, 'Contact: $phone', Colors.purple.shade700),
                  ],
                ),
                const SizedBox(height: 20),

                // 5. CALLS TO ACTION (Full-width buttons)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onViewMap,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: secondaryColor),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: isLoadingMap
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: secondaryColor),
                            )
                          : const Icon(Icons.map, size: 20, color: secondaryColor),
                        label: Text(
                          isLoadingMap ? "Loading..." : "View Map",
                          style: TextStyle(color: secondaryColor, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onBookNow,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 3,
                        ),
                        icon: const Icon(Icons.bookmark_add, size: 20, color: Colors.white),
                        label: const Text(
                          "Book Now",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===================== IMAGE CAROUSEL (Needed to run the code) =====================
class _ImageCarousel extends StatefulWidget {
  final List images;

  const _ImageCarousel({required this.images});

  @override
  State<_ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<_ImageCarousel> {
  int currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          children: [
            SizedBox(
              height: 220,
              child: ClipRRect( 
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)), 
                child: PageView.builder(
                  itemCount: widget.images.length,
                  onPageChanged: (i) {
                    setState(() => currentIndex = i);
                  },
                  itemBuilder: (context, i) {
                    return Image.network(
                      widget.images[i],
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[300],
                          alignment: Alignment.center,
                          child: const Icon(Icons.image_not_supported,
                              size: 60, color: Colors.grey),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
            
            // Indicator dots overlayed on the bottom of the image
            Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.images.length,
                  (i) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: currentIndex == i ? Colors.white : Colors.white54, 
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black12, width: 1),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}