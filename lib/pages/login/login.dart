import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  bool isLoading = false;
  bool isLoginMode = true;

  // Animation controller for the initial load sequence
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    emailController.dispose();
    passwordController.dispose();
    nameController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void _showSnack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }

  Future<void> loginUser() async {
    if (emailController.text.trim().isEmpty ||
        passwordController.text.trim().isEmpty) {
      _showSnack(
        'Please enter your credentials',
        Colors.redAccent,
      );

      return;
    }

    if (!isLoginMode) {
      if (nameController.text.trim().isEmpty) {
        _showSnack(
          'Please enter your name',
          Colors.redAccent,
        );

        return;
      }

      if (passwordController.text != confirmPasswordController.text) {
        _showSnack(
          'Passwords do not match',
          Colors.redAccent,
        );

        return;
      }
    }

    setState(() => isLoading = true);

    try {
      if (isLoginMode) {
        // LOGIN USER
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );

        _showSnack(
          'Login Successful',
          Colors.green,
        );

        if (!mounted) return;

        Navigator.pushReplacementNamed(
          context,
          '/dashboard',
        );
      } else {
        // CREATE USER
        UserCredential userCredential =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );

        print(userCredential.user?.uid);
        print(userCredential.user?.email);

        _showSnack(
          'Account Created Successfully',
          Colors.green,
        );

        setState(() {
          isLoginMode = true;
        });
      }
    } on FirebaseAuthException catch (e) {
      _showSnack(
        e.message ?? 'Authentication Error',
        Colors.red,
      );

      print(e.code);
    } catch (e) {
      _showSnack(
        e.toString(),
        Colors.red,
      );

      print(e.toString());
    }

    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // Subtle gradient background
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE0F7FA), Color(0xFFF4F6F9), Colors.white],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 30.0),
                  child: Column(
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 40),
                      _buildLoginForm(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Hero(
          tag: 'logo',
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.cyan.withOpacity(0.2),
                  blurRadius: 30,
                  spreadRadius: 5,
                )
              ],
            ),
            child: const CircleAvatar(
              radius: 55,
              backgroundImage: AssetImage('images/baby.png'),
            ),
          ),
        ),
        const SizedBox(height: 25),
        Text(
          isLoginMode ? 'Welcome Back' : 'Create Account',
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: Color(0xFF263238),
            letterSpacing: -0.5,
          ),
        ),
        Text(
          isLoginMode
              ? 'Gently monitoring your little one'
              : 'Join us to monitor your baby',
          style: TextStyle(color: Colors.blueGrey, fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildLoginForm() {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        children: [
          if (!isLoginMode)
            _buildTextField(
              controller: nameController,
              label: 'Full Name',
              icon: Icons.person_outline_rounded,
            ),
          if (!isLoginMode) const SizedBox(height: 15),
          _buildTextField(
            controller: emailController,
            label: 'Email Address',
            icon: Icons.alternate_email_rounded,
            type: TextInputType.emailAddress,
          ),
          const SizedBox(height: 15),
          _buildTextField(
            controller: passwordController,
            label: 'Password',
            icon: Icons.lock_outline_rounded,
            isPassword: true,
          ),
          if (!isLoginMode) const SizedBox(height: 15),
          if (!isLoginMode)
            _buildTextField(
              controller: confirmPasswordController,
              label: 'Confirm Password',
              icon: Icons.lock_outline_rounded,
              isPassword: true,
            ),
          const SizedBox(height: 30),
          _buildLoginButton(),
          const SizedBox(height: 20),
          _buildToggleModeText(),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    TextInputType type = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 22, color: Colors.cyan.shade700),
        filled: true,
        fillColor: Colors.grey.shade50,
        labelStyle: const TextStyle(color: Colors.blueGrey, fontSize: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.cyan, width: 2),
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: isLoading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: CircularProgressIndicator(color: Colors.cyan),
            )
          : SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: loginUser,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyan.shade600,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: Text(
                  isLoginMode ? 'SIGN IN' : 'SIGN UP',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1),
                ),
              ),
            ),
    );
  }

  Widget _buildToggleModeText() {
    return GestureDetector(
      onTap: () {
        setState(() {
          isLoginMode = !isLoginMode;
          // Clear fields when switching modes
          nameController.clear();
          confirmPasswordController.clear();
          emailController.clear();
          passwordController.clear();
        });
      },
      child: Text(
        isLoginMode
            ? "Don't have an account? Sign Up"
            : "Already have an account? Sign In",
        style: TextStyle(
          color: Colors.cyan.shade600,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
