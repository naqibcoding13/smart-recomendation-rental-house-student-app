import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rental_house/screens/homeowner/homeowner_register_screen.dart';
import 'students/student_dashboard.dart';
import 'students/register_screen.dart';
import 'admin/admin_dashboard.dart';
import 'homeowner/homeowner_dashboard.dart';

// 💡 Define a custom primary color for a modern look
const Color primaryColor = Color(0xFF1E88E5); // A nice, deep blue
const Color secondaryColor = Color(0xFF42A5F5);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isPasswordVisible = false;
  bool isLoading = false;
  bool showSuccessAnimation = false;

  // 👇 Role selection logic is maintained
  String selectedRole = "Student"; // Default

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
    emailController.dispose();
    passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // NOTE: Your _handleLogin method remains the same as it handles the core logic.
  // I have omitted it here for brevity, assume it is unchanged.
  Future<void> _handleLogin() async {
     if (emailController.text.trim().isEmpty ||
         passwordController.text.trim().isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(
           content: Text('Please enter email and password'),
           backgroundColor: Colors.red,
         ),
       );
       return;
     }

     setState(() => isLoading = true);

     try {
       // Firebase Auth login
       await FirebaseAuth.instance.signInWithEmailAndPassword(
         email: emailController.text.trim(),
         password: passwordController.text.trim(),
       );

       if (mounted) {
         setState(() => isLoading = false);

         // Show success animation
         setState(() => showSuccessAnimation = true);
         _animationController.forward();

         // Wait for animation to complete, then navigate
         await Future.delayed(const Duration(seconds: 1));
         
         // Navigate based on selected role
         Widget destination;
         if (selectedRole == "Admin") {
            destination = AdminDashboard();
         } else if (selectedRole == "Homeowner") {
            destination = HomeownerDashboard();
         } else {
            destination = const StudentDashboard();
         }
         
         Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => destination));
       }
     } on FirebaseAuthException catch (e) {
       setState(() => isLoading = false);
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text(e.message ?? 'Login failed')),
       );
     }
  }

  // --- UI Widget Builders ---
  Widget _buildRoleSegmentedControl() {
    final List<String> roles = ["Admin", "Homeowner", "Student"];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: roles.map((role) {
          final isSelected = selectedRole == role;
          return Expanded(
            child: GestureDetector(
              onTap: isLoading ? null : () {
                setState(() {
                  selectedRole = role;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? primaryColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    role,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    bool isPassword = false,
  }) {
    return TextField(
      controller: controller,
      enabled: !isLoading,
      obscureText: isPassword && !isPasswordVisible,
      style: const TextStyle(color: Colors.black87),
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: TextStyle(color: primaryColor.withOpacity(0.8)),
        hintStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Icon(icon, color: primaryColor),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none, // Make it look cleaner, use fillColor for separation
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: secondaryColor, width: 2),
        ),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                  color: primaryColor,
                ),
                onPressed: isLoading ? null : () {
                  setState(() {
                    isPasswordVisible = !isPasswordVisible;
                  });
                },
              )
            : null,
      ),
      keyboardType: isPassword ? TextInputType.text : TextInputType.emailAddress,
    );
  }

  Widget _buildLogoSection() {
    return Column(
      children: [
        Container(
          height: 120,
          width: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: primaryColor.withOpacity(0.1),
            border: Border.all(color: primaryColor, width: 3),
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/images/logo.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  Icons.house_siding_rounded, // Use a more relevant icon for rental house
                  size: 70,
                  color: primaryColor,
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'SMART RENTAL HOUSE APP',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: primaryColor,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50, // Lighter, subtle background
      body: SafeArea(
        child: Stack(
          children: [
            // --- MAIN SCROLLABLE CONTENT ---
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),
                  
                  // 1. Logo and Title Section
                  _buildLogoSection(),
                  const SizedBox(height: 40),
                  
                  // 2. Welcome Text
                  const Text(
                    'Welcome Back!',
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Log in to find the perfect rental or manage your listings.',
                    textAlign: TextAlign.left,
                    style: TextStyle(color: Colors.black54, fontSize: 16),
                  ),
                  const SizedBox(height: 40),

                  // 3. Role Toggle (Improved UI)
                  _buildRoleSegmentedControl(),
                  const SizedBox(height: 30),

                  // 4. Input Fields
                  _buildTextField(
                    controller: emailController,
                    labelText: 'Email Address',
                    icon: Icons.alternate_email,
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: passwordController,
                    labelText: 'Password',
                    icon: Icons.lock_open,
                    isPassword: true,
                  ),
                  const SizedBox(height: 10),
                  
                  // Forgot Password (Optional, but good UX)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        // Implement Forgot Password logic
                      },
                      child: Text(
                        'Forgot Password?',
                        style: TextStyle(color: primaryColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 5. Login Button
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                      onPressed: isLoading ? null : _handleLogin,
                      child: isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            )
                          : Text(
                              'Login as $selectedRole',
                              style: const TextStyle(
                                  fontSize: 18, 
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // 6. Register Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don't have an account? ", style: TextStyle(fontSize: 16)),
                      GestureDetector(
                        onTap: () {
                          if (selectedRole == "Homeowner") {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const HomeownerRegisterScreen()),
                            );
                          } else if (selectedRole == "Student") {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const RegisterScreen()),
                            );
                          } else {
                            // Optionally handle Admin registration or show a message
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Admin accounts must be created internally.')),
                            );
                          }
                        },
                        child: Text(
                          'Register Here',
                          style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 60), // Extra space for better scrolling
                ],
              ),
            ),
            
            // --- SUCCESS ANIMATION OVERLAY (KEPT FUNCTIONAL) ---
            if (showSuccessAnimation)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.5), // Semi-transparent overlay
                  child: Center(
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Container(
                        height: 150,
                        width: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check_circle_outline,
                          size: 90,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}