import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vuleadtaxi/DriverRegisterScreen.dart';
import 'package:vuleadtaxi/HomeScreen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRememberedLogin();
  }

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  Future<void> _saveUserData(Map<String, dynamic> responseData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_data', jsonEncode(responseData));

    if (responseData.containsKey('user') && responseData['user'] is Map) {
      final userData = responseData['user'] as Map<String, dynamic>;
      await prefs.setInt('u_id', _parseInt(userData['U_Id']) ?? 0);
      await prefs.setString('u_name', _parseString(userData['U_Name']) ?? '');
      await prefs.setString('u_email', _parseString(userData['U_Email']) ?? '');
      await prefs.setString('u_mobile', _parseString(userData['U_Mobile']) ?? '');
      await prefs.setString('u_gender', _parseString(userData['U_Gender']) ?? '');
      await prefs.setString('u_dob', _parseString(userData['U_DOB']) ?? '');
      await prefs.setString('u_image', _parseString(userData['U_Image']) ?? '');
      await prefs.setString('unique_code', _parseString(userData['unique_code']) ?? '');
      await prefs.setInt('role_id', _parseInt(userData['Role_Id']) ?? 0);
      await prefs.setInt('city_id', _parseInt(userData['City_Id']) ?? 0);

      // Save location data if available
      if (userData['location'] != null) {
        await prefs.setString('user_lat', _parseString(userData['location']['lat']) ?? '');
        await prefs.setString('user_lng', _parseString(userData['location']['lng']) ?? '');
      }
    }

    // Save the authentication token
    await prefs.setString('auth_token', _parseString(responseData['token']) ?? '');
    await prefs.setString('role', _parseString(responseData['role']) ?? '');
    await prefs.setBool('is_logged_in', true);

    // IMPORTANT: Set driver as OFFLINE by default on login
    await prefs.setString('availability_status', 'offline');
    await prefs.setBool('is_driver_online', false);

    if (_rememberMe) {
      await prefs.setString('remembered_login', _loginController.text.trim());
    } else {
      await prefs.remove('remembered_login');
    }

    print('User logged in and set to OFFLINE by default');
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  String? _parseString(dynamic value) {
    if (value == null) return null;
    return value.toString();
  }

  bool _isEmail(String input) {
    return input.contains('@') && input.contains('.');
  }

  bool _isMobile(String input) {
    final mobileRegExp = RegExp(r'^[0-9]{10}$');
    return mobileRegExp.hasMatch(input);
  }

  Future<void> _login() async {
    final loginInput = _loginController.text.trim();

    if (loginInput.isEmpty || _passwordController.text.isEmpty) {
      _showErrorSnackBar('Please fill in all fields');
      return;
    }

    if (!_isEmail(loginInput) && !_isMobile(loginInput)) {
      _showErrorSnackBar('Please enter a valid email or 10-digit mobile number');
      return;
    }

    if (_passwordController.text.length < 6) {
      _showErrorSnackBar('Password must be at least 6 characters');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final payload = {
        "U_Email": _isEmail(loginInput) ? loginInput : "",
        "U_Password": _passwordController.text,
        "U_Mobile": _isMobile(loginInput) ? loginInput : ""
      };

      final response = await http.post(
        Uri.parse('https://vnumdemo.caxis.ca/public/api/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        await _saveUserData(responseData);


        // Navigate to home screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else {
        final errorData = jsonDecode(response.body);
        _showErrorDialog(_parseString(errorData['error']) ?? 'Invalid credentials');
      }
    } catch (e) {
      _showErrorSnackBar('Network error. Please check your connection.');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF444444),
        title: const Text('Login Failed', style: TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Color(0xFFE89D43))),
          ),
        ],
      ),
    );
  }

  Future<void> _loadRememberedLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberedLogin = prefs.getString('remembered_login');
    if (rememberedLogin != null) {
      _loginController.text = rememberedLogin;
      setState(() {
        _rememberMe = true;
      });
    }
  }

  void _navigateToRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DriverRegisterScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF333333),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 60),
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE89D43),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.car_rental,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Welcome Back',
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Text(
                          'Please sign in to continue',
                          style: TextStyle(fontSize: 16, color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 60),
                _buildTextField(
                  controller: _loginController,
                  hintText: 'Email or Mobile Number',
                  icon: Icons.person,
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: _passwordController,
                  hintText: 'Password',
                  icon: Icons.lock,
                  isPassword: true,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          height: 24,
                          width: 24,
                          child: Checkbox(
                            value: _rememberMe,
                            onChanged: (value) {
                              setState(() {
                                _rememberMe = value ?? false;
                              });
                            },
                            activeColor: const Color(0xFFE89D43),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('Remember me', style: TextStyle(color: Colors.white70, fontSize: 14)),
                      ],
                    ),
                    GestureDetector(
                      onTap: () {
                        _showErrorSnackBar('Forgot password feature coming soon!');
                      },
                      child: const Text(
                        'Forgot Password?',
                        style: TextStyle(color: Color(0xFFE89D43), fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                Container(
                  width: double.infinity,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE89D43).withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE89D43),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                      'Sign In',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Don\'t have an account?', style: TextStyle(color: Colors.white70)),
                      TextButton(
                        onPressed: _navigateToRegister,
                        child: const Text(
                          'Sign up',
                          style: TextStyle(color: Color(0xFFE89D43), fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool isPassword = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? _obscurePassword : false,
        style: const TextStyle(color: Colors.white),
        keyboardType: hintText == 'Email or Mobile Number'
            ? TextInputType.emailAddress
            : TextInputType.text,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
          prefixIcon: Icon(icon, color: const Color(0xFFE89D43)),
          suffixIcon: isPassword
              ? IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility_off : Icons.visibility,
              color: Colors.white70,
            ),
            onPressed: _togglePasswordVisibility,
          )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 20),
        ),
      ),
    );
  }
}