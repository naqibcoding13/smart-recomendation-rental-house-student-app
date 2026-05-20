import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'student_home.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Brand Colors
const Color primaryColor = Color(0xFF1E88E5);

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>(); // Added FormKey for validation
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  bool isPasswordVisible = false;
  bool isConfirmPasswordVisible = false;
  bool isLoading = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool isPassword = false,
    bool isConfirm = false,
    String? Function(String?)? validator,
  }) {
    bool currentVisibility = isConfirm ? isConfirmPasswordVisible : isPasswordVisible;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        enabled: !isLoading,
        obscureText: isPassword && !currentVisibility,
        keyboardType: keyboardType,
        validator: validator,
        style: const TextStyle(fontSize: 16),
        decoration: InputDecoration(
          labelText: labelText,
          labelStyle: const TextStyle(color: Colors.grey, fontSize: 14),
          prefixIcon: Icon(icon, color: primaryColor, size: 22),
          filled: true,
          fillColor: Colors.grey[50],
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey[200]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: primaryColor, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.redAccent),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.redAccent, width: 2),
          ),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    currentVisibility ? Icons.visibility : Icons.visibility_off,
                    color: Colors.grey,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      if (isConfirm) {
                        isConfirmPasswordVisible = !isConfirmPasswordVisible;
                      } else {
                        isPasswordVisible = !isPasswordVisible;
                      }
                    });
                  },
                )
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: const BackButton(color: Colors.black87),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey, // Attach FormKey
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Create Account", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 8),
                Text("Sign up to start your student rental journey.", style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                const SizedBox(height: 32),
                _buildTextField(
                  controller: nameController,
                  labelText: 'Full Name',
                  icon: Icons.person_outline,
                  validator: (v) => v!.isEmpty ? "Enter your name" : null,
                ),
                _buildTextField(
                  controller: emailController,
                  labelText: 'Email Address',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => !v!.contains('@') ? "Enter a valid email" : null,
                ),
                _buildTextField(
                  controller: phoneController,
                  labelText: 'Phone Number',
                  icon: Icons.phone_android_outlined,
                  keyboardType: TextInputType.phone,
                  validator: (v) => v!.isEmpty ? "Enter phone number" : null,
                ),
                _buildTextField(
                  controller: passwordController,
                  labelText: 'Password',
                  icon: Icons.lock_outline,
                  isPassword: true,
                  validator: (v) => v!.length < 6 ? "Min 6 characters" : null,
                ),
                _buildTextField(
                  controller: confirmPasswordController,
                  labelText: 'Confirm Password',
                  icon: Icons.lock_reset_outlined,
                  isPassword: true,
                  isConfirm: true,
                  validator: (v) => v != passwordController.text ? "Passwords do not match" : null,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _handleRegister,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
                    ),
                    child: isLoading
                        ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                        : const Text('Register', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

  // ============================
  // FIXED REGISTER LOGIC
  // ============================
  Future<void> _handleRegister() async {
    // 1. Trigger Form Validation
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      // 2. Create Auth Account
      final credential = await _auth.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final uid = credential.user!.uid;

      // 3. FIX: Initialize preferences as empty map {} instead of null
      await FirebaseFirestore.instance.collection('students').doc(uid).set({
        'uid': uid,
        'name': nameController.text.trim(),
        'email': emailController.text.trim(),
        'phone': phoneController.text.trim(),
        'role': 'student',
        'createdAt': FieldValue.serverTimestamp(),
        'preferences': {}, // Changed from null to {}
      });

      if (mounted) {
        setState(() => isLoading = false);
        _showSuccessDialog();
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        String errorMsg = "Registration failed";
        if (e.code == 'email-already-in-use') errorMsg = "Email is already registered";
        if (e.code == 'weak-password') errorMsg = "Password is too weak";
        _showErrorSnackBar(errorMsg);
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        _showErrorSnackBar("An unexpected error occurred");
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSuccessDialog() {
    _animationController.reset();
    _animationController.forward();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                  child: const Icon(Icons.check, size: 48, color: Colors.white),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Account Created!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text('Your registration was successful. Welcome to the family.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    // FIX: Clears all previous routes so user can't click "back" to register again
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const StudentHome()),
                      (route) => false,
                    );
                  },
                  child: const Text('Continue to Home', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}