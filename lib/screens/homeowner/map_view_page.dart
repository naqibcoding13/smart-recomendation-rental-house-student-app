// map_view_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MapViewPage extends StatefulWidget {
  const MapViewPage({super.key});

  @override
  State<MapViewPage> createState() => _MapViewPageState();
}

class _MapViewPageState extends State<MapViewPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Marker> _markers = [];

  @override
  void initState() {
    super.initState();
    _loadMarkers();
  }

  Future<void> _loadMarkers() async {
    final uid = _auth.currentUser?.uid;
    final snapshot = await _firestore.collection('houses').where('homeownerId', isEqualTo: uid).get();
    List<Marker> markers = [];
    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (data['latitude'] != null && data['longitude'] != null) {
        markers.add(Marker(
          point: LatLng((data['latitude'] as num).toDouble(), (data['longitude'] as num).toDouble()),
          width: 40,
          height: 40,
          child: const Icon(Icons.location_on, color: Colors.purple, size: 36),
        ));
      }
    }
    setState(() => _markers = markers);
  }

  @override
  Widget build(BuildContext context) {
    final center = _markers.isNotEmpty ? _markers.first.point : LatLng(2.1896, 102.2501); // Melaka
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Card(
        child: SizedBox(
          height: 420,
          child: FlutterMap(
            options: MapOptions(initialCenter: center, initialZoom: 12),
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
              MarkerLayer(markers: _markers),
            ],
          ),
        ),
      ),
    );
  }
}
