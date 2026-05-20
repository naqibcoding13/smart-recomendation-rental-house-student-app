import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:rental_house/screens/students/browse_houses_page.dart';

class StudentMapPage extends StatefulWidget {
  const StudentMapPage({super.key});

  @override
  State<StudentMapPage> createState() => _StudentMapPageState();
}

class _StudentMapPageState extends State<StudentMapPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};

  bool _isLoading = true;
  final Set<String> _takenHouseIds = {};
  bool _hasMovedCamera = false;
  LatLng? _firstHouseLatLng;

  static const LatLng _defaultCenter = LatLng(2.1896, 102.2501); // Melaka

  @override
  void initState() {
    super.initState();
    _loadTakenHouses();
  }

  Future<void> _loadTakenHouses() async {
    try {
      final snap = await _firestore
          .collection('bookings')
          .where(
            'status',
            whereIn: ['accepted', 'deposit_paid', 'fully_paid'],
          )
          .get();

      for (final doc in snap.docs) {
        final houseId = doc.data()['houseId'];
        if (houseId != null) {
          _takenHouseIds.add(houseId);
        }
      }
    } catch (e) {
      debugPrint('Error loading taken houses: $e');
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (!_hasMovedCamera && _firstHouseLatLng != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_firstHouseLatLng!, 14),
      );
      _hasMovedCamera = true;
    }
  }

  /// 🔹 Interactive Bottom Sheet with Image
  void _showHouseBottomSheet(Map<String, dynamic> data) {
    // Get the first image from the list or a single string
    String? imageUrl;
    if (data['images'] != null && (data['images'] as List).isNotEmpty) {
      imageUrl = data['images'][0];
    } else if (data['imageUrl'] != null) {
      imageUrl = data['imageUrl'];
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Center handle for the sheet
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 15),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: imageUrl != null
                    ? Image.network(
                        imageUrl,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 180,
                          color: Colors.grey[200],
                          child: const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                        ),
                      )
                    : Container(
                        height: 180,
                        color: Colors.grey[200],
                        child: const Icon(Icons.home, size: 50, color: Colors.grey),
                      ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      data['title'] ?? 'Untitled House',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    'RM ${data['price']}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.category, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text('${data['houseType']}'),
                  const SizedBox(width: 16),
                  const Icon(Icons.person, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text('For: ${data['genderPreference']}'),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    Navigator.pop(context); // Close the bottom sheet
                    // Navigate to house details page
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BrowseHousesPage(),
                      ),
                    );
                    
                  },
                  child: const Text('View Full Details', style: TextStyle(color: Colors.white)),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Scaffold(body: Center(child: Text('Please log in first')));
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text('Available Houses Map')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('houses').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          _markers.clear();
          LatLng? firstLatLng;

          for (final doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;

            if (_takenHouseIds.contains(doc.id)) continue;
            if (data['availabilityStatus'] != 'available') continue;

            final lat = data['latitude'];
            final lng = data['longitude'];

            if (lat == null || lng == null || lat is! num || lng is! num) continue;

            final position = LatLng(lat.toDouble(), lng.toDouble());
            firstLatLng ??= position;

            _markers.add(
              Marker(
                markerId: MarkerId(doc.id),
                position: position,
                onTap: () {
                  // Center the map on the marker when clicked
                  _mapController?.animateCamera(CameraUpdate.newLatLng(position));
                  _showHouseBottomSheet(data);
                },
              ),
            );
          }

          _firstHouseLatLng = firstLatLng;

          return _markers.isEmpty
              ? const Center(child: Text('No available houses on the map.'))
              : GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: const CameraPosition(
                    target: _defaultCenter,
                    zoom: 12,
                  ),
                  markers: _markers,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                );
        },
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}