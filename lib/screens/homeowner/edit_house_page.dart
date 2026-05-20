import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class EditHousePage extends StatefulWidget {
  final String houseId;
  const EditHousePage({super.key, required this.houseId});

  @override
  State<EditHousePage> createState() => _EditHousePageState();
}

class _EditHousePageState extends State<EditHousePage> {
  final _formKey = GlobalKey<FormState>();

  final _titleCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  String _houseType = 'Terrace House';
  String _genderPref = 'Male';

  List<String> _existingImages = [];
  List<XFile> _newImages = [];

  LatLng? _location;
  bool _loading = true;
  bool _saving = false;
  String _status = 'available';

  final _firestore = FirebaseFirestore.instance;

  final CloudinaryPublic cloudinary =
      CloudinaryPublic('dhmb80o8g', 'houseimage_preset', cache: false);

  @override
  void initState() {
    super.initState();
    _loadHouse();
  }

  Future<void> _loadHouse() async {
    final doc =
        await _firestore.collection('houses').doc(widget.houseId).get();

    if (!doc.exists) {
      Navigator.pop(context);
      return;
    }

    final data = doc.data()!;
    _status = data['status'] ?? 'available';

    _titleCtrl.text = data['title'];
    _priceCtrl.text = data['price'].toString();
    _phoneCtrl.text = data['phoneNumber'] ?? '';
    _houseType = data['houseType'];
    _genderPref = data['genderPreference'];
    _existingImages = List<String>.from(data['images'] ?? []);
    _location = LatLng(data['latitude'], data['longitude']);

    setState(() => _loading = false);
  }

  bool get _canEdit => _status == 'available';

  Future<List<String>> _uploadNewImages() async {
    List<String> urls = [];
    for (final img in _newImages) {
      final res = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          img.path,
          folder: 'rental_house_images',
          resourceType: CloudinaryResourceType.Image,
        ),
      );
      urls.add(res.secureUrl);
    }
    return urls;
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_canEdit) {
      _showError('This property cannot be edited once booked.');
      return;
    }

    setState(() => _saving = true);

    try {
      final newImageUrls = await _uploadNewImages();

      await _firestore.collection('houses').doc(widget.houseId).update({
        'title': _titleCtrl.text.trim(),
        'price': double.parse(_priceCtrl.text),
        'phoneNumber': _phoneCtrl.text.trim(),
        'houseType': _houseType,
        'genderPreference': _genderPref,
        'images': [..._existingImages, ...newImageUrls],
        'latitude': _location!.latitude,
        'longitude': _location!.longitude,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      Navigator.pop(context, true);
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => _saving = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Property'),
        backgroundColor: Colors.blue,
      ),
      body: AbsorbPointer(
        absorbing: !_canEdit,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!_canEdit)
                  const Text(
                    '⚠ This property cannot be edited because it is already booked.',
                    style: TextStyle(color: Colors.red),
                  ),

                TextFormField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(labelText: 'House Title'),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Required' : null,
                ),

                TextFormField(
                  controller: _priceCtrl,
                  decoration: const InputDecoration(labelText: 'Monthly Price'),
                  keyboardType: TextInputType.number,
                  validator: (v) =>
                      double.tryParse(v ?? '') == null ? 'Invalid price' : null,
                ),

                TextFormField(
                  controller: _phoneCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Contact Phone'),
                ),

                DropdownButtonFormField(
                  value: _houseType,
                  items: const [
                    DropdownMenuItem(value: 'Terrace House', child: Text('Terrace House')),
                    DropdownMenuItem(value: 'Townhouse', child: Text('Townhouse')),
                    DropdownMenuItem(value: 'Apartment', child: Text('Apartment')),
                  ],
                  onChanged: (v) => setState(() => _houseType = v!),
                  decoration: const InputDecoration(labelText: 'House Type'),
                ),

                DropdownButtonFormField(
                  value: _genderPref,
                  items: const [
                    DropdownMenuItem(value: 'Male', child: Text('Male')),
                    DropdownMenuItem(value: 'Female', child: Text('Female')),
                    DropdownMenuItem(value: 'Any', child: Text('Any')),
                  ],
                  onChanged: (v) => setState(() => _genderPref = v!),
                  decoration:
                      const InputDecoration(labelText: 'Gender Preference'),
                ),

                const SizedBox(height: 16),

                ElevatedButton.icon(
                  onPressed: () async {
                    final picker = ImagePicker();
                    final imgs = await picker.pickMultiImage(imageQuality: 75);
                    if (imgs.isNotEmpty) {
                      setState(() => _newImages.addAll(imgs));
                    }
                  },
                  icon: const Icon(Icons.add_a_photo),
                  label: const Text('Add Images'),
                ),

                const SizedBox(height: 16),

                SizedBox(
                  height: 200,
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: _location!,
                      initialZoom: 13,
                      onTap: (_, p) => setState(() => _location = p),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      ),
                      MarkerLayer(markers: [
                        Marker(
                          point: _location!,
                          width: 40,
                          height: 40,
                          child: const Icon(Icons.location_pin,
                              color: Colors.red, size: 40),
                        )
                      ]),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _saveChanges,
                    child: _saving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Save Changes'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
