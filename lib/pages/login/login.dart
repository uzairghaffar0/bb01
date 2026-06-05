import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

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

  final TextEditingController babyNameController = TextEditingController();

  final TextEditingController confirmPasswordController =
      TextEditingController();

  bool isLoading = false;
  bool isLoginMode = true;

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

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();

    emailController.dispose();
    passwordController.dispose();
    nameController.dispose();
    babyNameController.dispose();
    confirmPasswordController.dispose();

    super.dispose();
  }

  void _showSnack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
      ),
    );
  }

  Future<void> _saveFcmToken(String userId) async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .set({'fcmToken': token}, SetOptions(merge: true));
      }
    } catch (e) {
      print('Failed to save FCM token: $e');
    }
  }

  Future<void> loginUser() async {
    if (emailController.text.trim().isEmpty ||
        passwordController.text.trim().isEmpty) {
      _showSnack('Please enter your credentials', Colors.redAccent);
      return;
    }

    if (!isLoginMode) {
      if (nameController.text.trim().isEmpty) {
        _showSnack('Please enter your name', Colors.redAccent);
        return;
      }
      if (babyNameController.text.trim().isEmpty) {
        _showSnack('Please enter baby name', Colors.redAccent);
        return;
      }
      if (passwordController.text != confirmPasswordController.text) {
        _showSnack('Passwords do not match', Colors.redAccent);
        return;
      }
    }

    setState(() { isLoading = true; });

    try {
      if (isLoginMode) {
        UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );

        await _saveFcmToken(userCredential.user!.uid);

        _showSnack('Login Successful', Colors.green);

        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/dashboard');
      } else {
        UserCredential userCredential =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );

        String? token;
        try {
          token = await FirebaseMessaging.instance.getToken();
        } catch (_) {}

        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .set({
          'name': nameController.text.trim(),
          'babyName': babyNameController.text.trim(),
          'email': emailController.text.trim(),
          'createdAt': Timestamp.now(),
          if (token != null) 'fcmToken': token,
        });

        _showSnack('Account Created Successfully', Colors.green);

        setState(() {
          isLoginMode = true;
          nameController.clear();
          babyNameController.clear();
          confirmPasswordController.clear();
        });
      }
    } on FirebaseAuthException catch (e) {
      _showSnack(e.message ?? 'Authentication Error', Colors.red);
    } catch (e) {
      _showSnack(e.toString(), Colors.red);
    } finally {
      if (mounted) {
        setState(() { isLoading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30.0,
                  ),
                  child: Column(
                    children: [
                      _buildHeader(context),
                      const SizedBox(height: 40),
                      _buildLoginForm(context),
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

  Widget _buildHeader(BuildContext context) {
    return Column(
      children: [
        Hero(
          tag: 'logo',
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).primaryColor.withOpacity(0.2),
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
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: Theme.of(context).colorScheme.onSurface,
            letterSpacing: -0.5,
          ),
        ),
        Text(
          isLoginMode
              ? 'Gently monitoring your little one'
              : 'Join us to monitor your baby',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withOpacity(0.9),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
            color: Theme.of(context).dividerColor.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        children: [
          if (!isLoginMode)
            _buildTextField(
              context: context,
              controller: nameController,
              label: 'Full Name',
              icon: Icons.person_outline_rounded,
            ),

          if (!isLoginMode) const SizedBox(height: 15),

          // BABY NAME FIELD
          if (!isLoginMode)
            _buildTextField(
              context: context,
              controller: babyNameController,
              label: 'Baby Name',
              icon: Icons.child_care,
            ),

          if (!isLoginMode) const SizedBox(height: 15),

          _buildTextField(
            context: context,
            controller: emailController,
            label: 'Email Address',
            icon: Icons.alternate_email_rounded,
            type: TextInputType.emailAddress,
          ),

          const SizedBox(height: 15),

          _buildTextField(
            context: context,
            controller: passwordController,
            label: 'Password',
            icon: Icons.lock_outline_rounded,
            isPassword: true,
          ),

          if (!isLoginMode) const SizedBox(height: 15),

          if (!isLoginMode)
            _buildTextField(
              context: context,
              controller: confirmPasswordController,
              label: 'Confirm Password',
              icon: Icons.lock_outline_rounded,
              isPassword: true,
            ),

          const SizedBox(height: 30),

          _buildLoginButton(context),

          const SizedBox(height: 20),

          _buildToggleModeText(context),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required BuildContext context,
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
        prefixIcon: Icon(
          icon,
          size: 22,
          color: Theme.of(context).primaryColor,
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        labelStyle: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(
            color: Theme.of(context).primaryColor,
            width: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildLoginButton(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: isLoading
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: CircularProgressIndicator(
                color: Theme.of(context).primaryColor,
              ),
            )
          : SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: loginUser,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: Text(
                  isLoginMode ? 'SIGN IN' : 'SIGN UP',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildToggleModeText(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          isLoginMode = !isLoginMode;

          nameController.clear();
          babyNameController.clear();
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
          color: Theme.of(context).primaryColor,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
