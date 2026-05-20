import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';

// Brand Colors
const Color primaryColor = Color(0xFF1E88E5);
const Color accentColor = Color(0xFF0D47A1);
const Color successColor = Color(0xFF4CAF50);
const Color backgroundColor = Color(0xFFF5F7FA);

class HomeownerRegisterScreen extends StatefulWidget {
  const HomeownerRegisterScreen({super.key});

  @override
  State<HomeownerRegisterScreen> createState() => _HomeownerRegisterScreenState();
}

class _HomeownerRegisterScreenState extends State<HomeownerRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  File? _pickedPdf;
  String? _pickedPdfName;
  bool _isLoading = false;
  bool _obscurePwd = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _pickedPdf = File(result.files.single.path!);
        _pickedPdfName = result.files.single.name;
      });
    }
  }

  Future<String?> _uploadPdfToFirebase(String uid) async {
    if (_pickedPdf == null) return null;
    final ref = FirebaseStorage.instance.ref(
      'homeowner_documents/${uid}_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    final task = await ref.putFile(
      _pickedPdf!,
      SettableMetadata(contentType: 'application/pdf'),
    );
    return await task.ref.getDownloadURL();
  }

  Future<void> _registerHomeowner() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pickedPdf == null) {
      _showError('Ownership document (PDF) is required.');
      return;
    }
    if (_passwordCtrl.text != _confirmPasswordCtrl.text) {
      _showError('Passwords do not match.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
      );
      final uid = cred.user!.uid;
      final pdfUrl = await _uploadPdfToFirebase(uid);

      await _firestore.collection('homeowners').doc(uid).set({
        'fullName': _nameCtrl.text.trim(),
        'phoneNumber': _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'ownershipPdfUrl': pdfUrl,
        'role': 'homeowner',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      _showError('Registration failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Icon(Icons.check_circle_outline, color: successColor, size: 60),
        content: const Text(
          'Registration Submitted!\n\nPlease wait for the administrator to verify your ownership documents. You will be able to log in once approved.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back
            },
            child: const Text('Back to Login', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: const BackButton(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Join as Homeowner", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: accentColor)),
                const SizedBox(height: 8),
                const Text("Register your details and property documents for verification.", style: TextStyle(fontSize: 16, color: Colors.black54)),
                const SizedBox(height: 32),
                
                _buildField(_nameCtrl, 'Full Name', Icons.person_outline),
                _buildField(_phoneCtrl, 'Phone Number', Icons.phone_android_rounded, keyboard: TextInputType.phone),
                _buildField(_emailCtrl, 'Email Address', Icons.email_outlined, keyboard: TextInputType.emailAddress),
                
                _buildField(
                  _passwordCtrl, 'Password', Icons.lock_outline, 
                  isPassword: true, 
                  obscure: _obscurePwd,
                  toggle: () => setState(() => _obscurePwd = !_obscurePwd),
                ),
                
                _buildField(
                  _confirmPasswordCtrl, 'Confirm Password', Icons.lock_clock_outlined, 
                  isPassword: true, 
                  obscure: _obscureConfirm,
                  toggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
                ),
                
                const SizedBox(height: 10),
                const Text("Property Verification", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54)),
                const SizedBox(height: 8),
                _buildPdfPicker(),
                const SizedBox(height: 40),
                
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _registerHomeowner,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Submit Application', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String label, IconData icon,
      {bool isPassword = false, bool obscure = false, VoidCallback? toggle, TextInputType keyboard = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: TextFormField(
        controller: ctrl,
        obscureText: obscure,
        keyboardType: keyboard,
        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 22),
          filled: true,
          fillColor: Colors.white,
          suffixIcon: isPassword 
            ? IconButton(icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, size: 20), onPressed: toggle) 
            : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryColor, width: 1.5)),
        ),
      ),
    );
  }

  Widget _buildPdfPicker() {
    final selected = _pickedPdf != null;

    return InkWell(
      onTap: _isLoading ? null : _pickPdf,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? successColor.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: selected ? successColor : Colors.grey.shade300,
              style: selected ? BorderStyle.solid : BorderStyle.solid,
              width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: selected ? successColor : Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                selected ? Icons.check : Icons.picture_as_pdf,
                color: selected ? Colors.white : Colors.red,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selected ? "Document Attached" : "Ownership Document",
                    style: TextStyle(fontWeight: FontWeight.bold, color: selected ? successColor : Colors.black87),
                  ),
                  Text(
                    selected ? _pickedPdfName! : "Tap to upload PDF",
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (!selected) const Icon(Icons.cloud_upload_outlined, color: primaryColor),
          ],
        ),
      ),
    );
  }
}