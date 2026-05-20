// add_house_page.dart (HOMEOWNER) - Google Map Picker version
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// Colors
const Color primaryColor = Color(0xFF1E88E5);
const Color successColor = Color(0xFF4CAF50);
const Color accentColor = Color(0xFFFFA726);

class AddHousePage extends StatefulWidget {
  final VoidCallback? onHouseAdded;
  const AddHousePage({super.key, this.onHouseAdded});

  @override
  State<AddHousePage> createState() => _AddHousePageState();
}

class _AddHousePageState extends State<AddHousePage> {
  final _formKey = GlobalKey<FormState>();

  final _titleCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  String _selectedHouseType = 'Terrace House';
  String _selectedGenderPref = 'Male';

  List<XFile>? _pickedImages;
  File? _pickedPdf;
  String? _pickedPdfName;

  // ✅ Google Maps location
  LatLng? _pickedLocation;
  GoogleMapController? _mapController;

  bool _isUploading = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cloudinary (Images only)
  final CloudinaryPublic cloudinary =
      CloudinaryPublic('dhmb80o8g', 'houseimage_preset', cache: false);

  @override
  void initState() {
    super.initState();
    final user = _auth.currentUser;
    if (user?.phoneNumber != null) {
      _phoneCtrl.text = user!.phoneNumber!;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _priceCtrl.dispose();
    _phoneCtrl.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // ---------------- PICKERS & UPLOAD LOGIC ----------------

  Future<void> _pickImages() async {
    // On Android 13+ you may need Permission.photos; on older android storage.
    final photosGranted = await Permission.photos.request().isGranted;
    final storageGranted = await Permission.storage.request().isGranted;

    if (photosGranted || storageGranted) {
      final picker = ImagePicker();
      final images = await picker.pickMultiImage(imageQuality: 75);
      setState(() => _pickedImages = images);
    } else {
      _showError('Permission required to access gallery.');
    }
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform
        .pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (result != null && result.files.single.path != null) {
      setState(() {
        _pickedPdf = File(result.files.single.path!);
        _pickedPdfName = result.files.single.name;
      });
    }
  }

  Future<List<String>> _uploadImages() async {
    if (_pickedImages == null || _pickedImages!.isEmpty) return [];

    List<String> urls = [];
    for (final img in _pickedImages!) {
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

  Future<String?> _uploadPdfToFirebase() async {
    if (_pickedPdf == null) return null;

    final user = _auth.currentUser;
    if (user == null) return null;

    final ref = FirebaseStorage.instance.ref(
      'rental_agreements/${user.uid}_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );

    final task = await ref.putFile(
      _pickedPdf!,
      SettableMetadata(contentType: 'application/pdf'),
    );

    return await task.ref.getDownloadURL();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_pickedImages == null || _pickedImages!.isEmpty) {
      _showError('Please select at least one image.');
      return;
    }
    if (_pickedPdf == null) {
      _showError('Please upload the rental agreement PDF.');
      return;
    }
    if (_pickedLocation == null) {
      _showError('Please select a location on the map.');
      return;
    }

    setState(() => _isUploading = true);

    try {
      final imageUrls = await _uploadImages();
      final pdfUrl = await _uploadPdfToFirebase();
      final user = _auth.currentUser!;

      await _firestore.collection('houses').add({
        // Ownership
        'homeownerId': user.uid,
        'homeownerEmail': user.email,

        // Property details
        'title': _titleCtrl.text.trim(),
        'price': double.parse(_priceCtrl.text),
        'houseType': _selectedHouseType,
        'genderPreference': _selectedGenderPref,

        // Media
        'images': imageUrls,
        'rentalAgreementUrl': pdfUrl,

        // ✅ Location (Google Maps)
        'latitude': _pickedLocation!.latitude,
        'longitude': _pickedLocation!.longitude,

        // Contact
        'phoneNumber': _phoneCtrl.text.trim(),

        // Availability control
        'isActive': true,
        'availabilityStatus': "available",

        // Metadata
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _showSubmissionSuccessDialog();
      widget.onHouseAdded?.call();
      _resetForm();
    } catch (e) {
      _showError('Submission failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _resetForm() {
    _titleCtrl.clear();
    _priceCtrl.clear();
    _phoneCtrl.clear();
    setState(() {
      _pickedImages = null;
      _pickedPdf = null;
      _pickedPdfName = null;
      _pickedLocation = null;
      _selectedHouseType = 'Terrace House';
      _selectedGenderPref = 'Male';
    });
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: successColor),
    );
  }

  Future<void> _showSubmissionSuccessDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
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
                  'Listing Submitted!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: successColor,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Your property is now added in Browse House Page.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child:
                        const Text('Got It', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------- UI WIDGETS ----------------

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    IconData? icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          labelText: labelText,
          prefixIcon: icon != null ? Icon(icon, color: primaryColor) : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primaryColor, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownField<T>({
    required String labelText,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: DropdownButtonFormField<T>(
        value: value,
        items: items,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: labelText,
          prefixIcon: Icon(icon, color: primaryColor),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primaryColor, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, color: primaryColor, size: 24),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePicker() {
    int imageCount = _pickedImages?.length ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          onPressed: _isUploading ? null : _pickImages,
          icon: const Icon(Icons.photo_library, color: primaryColor),
          label: Text(
            imageCount > 0 ? '$imageCount Images Selected' : 'Select House Images (Required)',
            style: const TextStyle(color: primaryColor),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            side: BorderSide(color: primaryColor.withOpacity(0.5)),
          ),
        ),
        const SizedBox(height: 10),

        if (_pickedImages != null && _pickedImages!.isNotEmpty)
          SizedBox(
            height: 90,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _pickedImages!.map((x) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(x.path),
                          width: 100,
                          height: 90,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => setState(() => _pickedImages!.remove(x)),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.8),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, size: 18, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildPdfPicker() {
    bool pdfSelected = _pickedPdf != null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: pdfSelected ? successColor : Colors.grey.shade300,
          width: pdfSelected ? 2 : 1,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(
            pdfSelected ? Icons.check_circle : Icons.picture_as_pdf,
            color: pdfSelected ? successColor : Colors.red,
            size: 30,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              pdfSelected
                  ? _pickedPdfName ?? 'Agreement selected'
                  : 'Upload Rental Agreement (PDF - Required)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: pdfSelected ? FontWeight.bold : FontWeight.normal,
                color: Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          pdfSelected
              ? IconButton(
                  onPressed: () => setState(() {
                    _pickedPdf = null;
                    _pickedPdfName = null;
                  }),
                  icon: const Icon(Icons.close, color: Colors.red),
                )
              : IconButton(
                  onPressed: _isUploading ? null : _pickPdf,
                  icon: const Icon(Icons.cloud_upload, color: primaryColor),
                ),
        ],
      ),
    );
  }

  // ✅ Google Map picker widget
  Widget _buildMapPicker() {
    const defaultCenter = LatLng(2.1896, 102.2501); // Melaka

    final markers = <Marker>{};
    if (_pickedLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('picked_location'),
          position: _pickedLocation!,
          infoWindow: const InfoWindow(title: 'Selected Location'),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          border: Border.all(
            color: _pickedLocation != null ? successColor : primaryColor,
            width: 2,
          ),
        ),
        child: GoogleMap(
          onMapCreated: (c) => _mapController = c,
          initialCameraPosition: CameraPosition(
            target: _pickedLocation ?? defaultCenter,
            zoom: 14,
          ),
          markers: markers,
          myLocationEnabled: false, // keep simple (no location permission needed)
          myLocationButtonEnabled: false,
          zoomControlsEnabled: true,
          onTap: (pos) {
            setState(() => _pickedLocation = pos);
            _showSuccess('Location selected!');
          },
        ),
      ),
    );
  }

  // ---------------- BUILD ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('List New Property', style: TextStyle(color: Colors.white)),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1) Property details
              _buildSectionTitle('Property Details', Icons.info_outline),
              _buildTextField(
                controller: _titleCtrl,
                labelText: 'House Title (e.g., Cozy 3-room Apartment)',
                icon: Icons.title,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Please enter a descriptive title' : null,
              ),
              _buildTextField(
                controller: _priceCtrl,
                labelText: 'Monthly Price (RM)',
                icon: Icons.attach_money,
                keyboardType: TextInputType.number,
                validator: (v) =>
                    v == null || double.tryParse(v.trim()) == null ? 'Enter a valid price' : null,
              ),
              _buildTextField(
                controller: _phoneCtrl,
                labelText: 'Contact Phone Number',
                icon: Icons.phone,
                keyboardType: TextInputType.phone,
                validator: (v) => v == null || v.trim().isEmpty ? 'Enter phone number' : null,
              ),

              _buildDropdownField<String>(
                labelText: 'House Type',
                value: _selectedHouseType,
                icon: Icons.apartment,
                items: const [
                  DropdownMenuItem(value: 'Terrace House', child: Text('Terrace House')),
                  DropdownMenuItem(value: 'Townhouse', child: Text('Townhouse')),
                  DropdownMenuItem(value: 'Apartment', child: Text('Apartment')),
                  DropdownMenuItem(value: 'Condominium', child: Text('Condominium')),
                ],
                onChanged: (v) => setState(() => _selectedHouseType = v ?? 'Terrace House'),
              ),

              _buildDropdownField<String>(
                labelText: 'Gender Preference',
                value: _selectedGenderPref,
                icon: Icons.group,
                items: const [
                  DropdownMenuItem(value: 'Male', child: Text('Male')),
                  DropdownMenuItem(value: 'Female', child: Text('Female')),
                  DropdownMenuItem(value: 'Any', child: Text('Any')),
                ],
                onChanged: (v) => setState(() => _selectedGenderPref = v ?? 'Male'),
              ),

              const SizedBox(height: 20),
              const Divider(),

              // 2) Media
              _buildSectionTitle('Media & Documents', Icons.camera_alt),
              _buildImagePicker(),
              const SizedBox(height: 20),
              _buildPdfPicker(),

              const SizedBox(height: 20),
              const Divider(),

              // 3) Location picker
              _buildSectionTitle('Property Location', Icons.map),
              const Padding(
                padding: EdgeInsets.only(bottom: 8.0),
                child: Text(
                  'Tap anywhere on the map to pin the exact location of the property.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              _buildMapPicker(),

              const SizedBox(height: 40),

              // Submit
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: _isUploading ? null : _submit,
                  icon: _isUploading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.send, color: Colors.white),
                  label: Text(
                    _isUploading ? 'Uploading...' : 'Submit Listing',
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 5,
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
