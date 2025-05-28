import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vuleadtaxi/LoginScreen.dart';
import 'package:vuleadtaxi/constants.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  bool _isEditing = false;
  bool _hasError = false;
  String _errorMessage = '';
  Map<String, dynamic> _userData = {};
  double _rating = 4.4;
  int _totalTrips = 156;

  File? _selectedImage;
  String? _base64Image;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  String? _selectedGender;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('u_id');

      if (userId == null) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'User ID not found. Please login again.';
        });
        return;
      }

      final response = await http.get(
        Uri.parse('https://vnumdemo.caxis.ca/public/api/users/$userId'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        setState(() {
          _userData = responseData;
          _isLoading = false;
          _nameController.text = _userData['U_Name']?.toString() ?? '';
          _emailController.text = _userData['U_Email']?.toString() ?? '';
          _mobileController.text = _userData['U_Mobile']?.toString() ?? '';
          _dobController.text = _userData['U_DOB']?.toString() ?? '';
          _selectedGender = _userData['U_Gender']?.toString() == 'M'
              ? 'M'
              : _userData['U_Gender']?.toString() == 'F'
              ? 'F'
              : null;
        });

        await prefs.setInt('u_id', int.parse(_userData['U_Id'].toString()));
        await prefs.setString('u_name', _userData['U_Name']?.toString() ?? '');
        await prefs.setString('u_email', _userData['U_Email']?.toString() ?? '');
        await prefs.setString('u_mobile', _userData['U_Mobile']?.toString() ?? '');
        await prefs.setString('u_gender', _userData['U_Gender']?.toString() ?? '');
        await prefs.setString('u_dob', _userData['U_DOB']?.toString() ?? '');
        await prefs.setString('u_image', _userData['U_Image']?.toString() ?? '');
        await prefs.setString('unique_code', _userData['unique_code']?.toString() ?? '');
        await prefs.setInt('role_id', int.parse(_userData['Role_Id'].toString()));
        await prefs.setInt('city_id', int.parse(_userData['City_Id'].toString()));
      } else {
        throw Exception('Failed to load user data: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _pickImage() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppConstants.backgroundColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(
            'Select Image Source',
            style: GoogleFonts.poppins(
              color: AppConstants.textColor,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.camera_alt, color: AppConstants.accentColor),
                title: Text('Camera', style: GoogleFonts.poppins(fontSize: 14, color: AppConstants.textColor)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromSource(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library, color: AppConstants.accentColor),
                title: Text('Gallery', style: GoogleFonts.poppins(fontSize: 14, color: AppConstants.textColor)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromSource(ImageSource.gallery);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  color: AppConstants.skipButtonColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickImageFromSource(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });

      final bytes = await _selectedImage!.readAsBytes();
      setState(() {
        _base64Image = base64Encode(bytes);
      });
    }
  }

  Future<void> _updateUserData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('u_id');

      if (userId == null) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'User ID not found. Please login again.';
        });
        return;
      }

      final updatedData = {
        'U_Name': _nameController.text,
        'U_Email': _emailController.text,
        'U_Mobile': _mobileController.text,
        'U_DOB': _dobController.text,
        'U_Gender': _selectedGender ?? '',
        if (_base64Image != null) 'U_Image': _base64Image,
      };

      final response = await http.put(
        Uri.parse('https://vnumdemo.caxis.ca/public/api/users/$userId'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(updatedData),
      );

      if (response.statusCode == 200) {
        await _fetchUserData();
        setState(() {
          _isEditing = false;
          _selectedImage = null;
          _base64Image = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Profile updated successfully!',
              style: GoogleFonts.poppins(color: AppConstants.textColor),
            ),
            backgroundColor: AppConstants.accentColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      } else {
        throw Exception('Failed to update user data: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to update profile: $_errorMessage',
            style: GoogleFonts.poppins(color: AppConstants.textColor),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  Future<void> _logout() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppConstants.backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Logout',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: AppConstants.textColor,
          ),
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: GoogleFonts.poppins(fontSize: 14, color: AppConstants.subtitleColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                color: AppConstants.skipButtonColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              'Logout',
              style: GoogleFonts.poppins(
                color: AppConstants.textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getGenderDisplay(String? gender) {
    return gender == 'M' ? 'Male' : gender == 'F' ? 'Female' : 'N/A';
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Profile',
          style: TextStyle(
            color: AppConstants.textColor,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        backgroundColor: AppConstants.backgroundColor,
        elevation: 0,
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: AppConstants.subtitleColor.withOpacity(0.2),
            height: 1,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _isEditing = !_isEditing;
              });
            },
            icon: Icon(
              _isEditing ? Icons.cancel : Icons.edit,
              color: AppConstants.accentColor,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppConstants.accentColor))
          : _hasError
          ? _buildErrorView()
          : SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(
              height: 10,
            ),
            _buildProfileHeader(),
            const SizedBox(height: 16),
            if (!_isEditing) ...[
              _buildContactInfo(),
              const SizedBox(height: 16),
              _buildMenuOptions(),
            ] else ...[
              _buildEditProfileForm(),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(
              'Error Loading Profile',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppConstants.textColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppConstants.subtitleColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchUserData,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.accentColor,
                foregroundColor: AppConstants.textColor,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                textStyle: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              child: Text('Try Again', style: TextStyle(color: AppConstants.textColor)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    final userName = _userData['U_Name']?.toString() ?? 'Driver Name';
    final userEmail = _userData['U_Email']?.toString() ?? 'driver@example.com';
    final userImageUrl = _userData['U_Image']?.toString();
    final cityName = _userData['city'] is Map
        ? _userData['city']['City_Name']?.toString() ?? 'Unknown City'
        : 'Unknown City';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppConstants.backgroundColor.withOpacity(0.9),
        border: Border.all(color: AppConstants.subtitleColor.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 48,
            backgroundColor: AppConstants.accentColor,
            backgroundImage: _selectedImage != null
                ? FileImage(_selectedImage!)
                : _base64Image != null
                ? MemoryImage(base64Decode(_base64Image!))
                : userImageUrl != null && userImageUrl.isNotEmpty
                ? NetworkImage(userImageUrl)
                : null,
            child: _selectedImage == null &&
                _base64Image == null &&
                (userImageUrl == null || userImageUrl.isEmpty)
                ? Text(
              userName.isNotEmpty ? userName[0].toUpperCase() : 'D',
              style: GoogleFonts.poppins(
                fontSize: 32,
                color: AppConstants.textColor,
                fontWeight: FontWeight.w700,
              ),
            )
                : null,
          ),
          const SizedBox(height: 12),
          Text(
            userName,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppConstants.textColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            userEmail,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppConstants.subtitleColor,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppConstants.accentColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              cityName,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppConstants.accentColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.star, color: AppConstants.accentColor, size: 20),
              const SizedBox(width: 6),
              Text(
                _rating.toStringAsFixed(1),
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppConstants.textColor,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                '$_totalTrips Trips',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppConstants.subtitleColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditProfileForm() {
    final userImageUrl = _userData['U_Image']?.toString();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppConstants.backgroundColor.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppConstants.subtitleColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Edit Profile',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppConstants.textColor,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: AppConstants.accentColor,
                  backgroundImage: _selectedImage != null
                      ? FileImage(_selectedImage!)
                      : _base64Image != null
                      ? MemoryImage(base64Decode(_base64Image!))
                      : userImageUrl != null && userImageUrl.isNotEmpty
                      ? NetworkImage(userImageUrl)
                      : null,
                  child: _selectedImage == null &&
                      _base64Image == null &&
                      (userImageUrl == null || userImageUrl.isEmpty)
                      ? Text(
                    _nameController.text.isNotEmpty
                        ? _nameController.text[0].toUpperCase()
                        : 'D',
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      color: AppConstants.textColor,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppConstants.accentColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.camera_alt,
                        color: AppConstants.textColor,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildTextField('Full Name', _nameController, Icons.person),
          const SizedBox(height: 12),
          _buildTextField('Email', _emailController, Icons.email),
          const SizedBox(height: 12),
          _buildTextField('Mobile Number', _mobileController, Icons.phone),
          const SizedBox(height: 12),
          _buildTextField('Date of Birth', _dobController, Icons.calendar_today, hint: 'YYYY-MM-DD'),
          const SizedBox(height: 12),
          _buildGenderDropdown(),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _updateUserData,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.accentColor,
              foregroundColor: AppConstants.textColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              minimumSize: const Size(double.infinity, 0),
              textStyle: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            child: Text('Save Changes', style: TextStyle(color: AppConstants.textColor)),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: AppConstants.subtitleColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: AppConstants.backgroundColor.withOpacity(0.8),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppConstants.subtitleColor.withOpacity(0.3)),
          ),
          child: TextField(
            controller: controller,
            style: GoogleFonts.poppins(fontSize: 14, color: AppConstants.textColor),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.poppins(color: AppConstants.subtitleColor),
              prefixIcon: Icon(icon, color: AppConstants.accentColor, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGenderDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gender',
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: AppConstants.subtitleColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: AppConstants.backgroundColor.withOpacity(0.8),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppConstants.subtitleColor.withOpacity(0.3)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonFormField<String>(
            value: _selectedGender,
            decoration: InputDecoration(
              border: InputBorder.none,
              prefixIcon: Icon(Icons.person_outline, color: AppConstants.accentColor, size: 20),
            ),
            dropdownColor: AppConstants.backgroundColor,
            style: GoogleFonts.poppins(fontSize: 14, color: AppConstants.textColor),
            items: [
              DropdownMenuItem(
                value: 'M',
                child: Text('Male', style: GoogleFonts.poppins(color: AppConstants.textColor)),
              ),
              DropdownMenuItem(
                value: 'F',
                child: Text('Female', style: GoogleFonts.poppins(color: AppConstants.textColor)),
              ),
            ],
            onChanged: (value) {
              setState(() {
                _selectedGender = value;
              });
            },
            hint: Text(
              'Select Gender',
              style: GoogleFonts.poppins(color: AppConstants.subtitleColor),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContactInfo() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppConstants.backgroundColor.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppConstants.subtitleColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contact Information',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppConstants.textColor,
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.email, 'Email', _userData['U_Email']?.toString() ?? 'N/A'),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.phone, 'Mobile', _userData['U_Mobile']?.toString() ?? 'N/A'),
          const SizedBox(height: 12),
          _buildInfoRow(
            Icons.person_outline,
            'Gender',
            _getGenderDisplay(_userData['U_Gender']?.toString()),
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            Icons.calendar_today,
            'Date of Birth',
            _userData['U_DOB']?.toString() ?? 'N/A',
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            Icons.code,
            'Car Franchise Code',
            _userData['unique_code']?.toString() ?? 'N/A',
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            Icons.location_city,
            'City',
            _userData['city'] is Map ? _userData['city']['City_Name']?.toString() ?? 'N/A' : 'N/A',
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            Icons.date_range,
            'Joined',
            _formatDate(_userData['created_at']?.toString()),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppConstants.accentColor, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppConstants.subtitleColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppConstants.textColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMenuOptions() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppConstants.backgroundColor.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppConstants.subtitleColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          _buildMenuOption(Icons.history, 'Trip History', () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Trip history feature coming soon!',
                  style: GoogleFonts.poppins(color: AppConstants.textColor),
                ),
                backgroundColor: AppConstants.accentColor,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            );
          }),
          _buildMenuOption(Icons.settings, 'Settings', () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Settings feature coming soon!',
                  style: GoogleFonts.poppins(color: AppConstants.textColor),
                ),
                backgroundColor: AppConstants.accentColor,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            );
          }),
          _buildMenuOption(Icons.help, 'Help & Support', () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Help & support feature coming soon!',
                  style: GoogleFonts.poppins(color: AppConstants.textColor),
                ),
                backgroundColor: AppConstants.accentColor,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            );
          }),
          _buildMenuOption(Icons.info, 'About', _showAboutDialog),
          _buildMenuOption(Icons.logout, 'Logout', _logout, isDestructive: true),
        ],
      ),
    );
  }

  Widget _buildMenuOption(IconData icon, String title, VoidCallback onTap, {bool isDestructive = false}) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? Colors.red : AppConstants.accentColor,
        size: 20,
      ),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          color: isDestructive ? Colors.red : AppConstants.textColor,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: isDestructive ? Colors.red : AppConstants.subtitleColor,
        size: 20,
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2), // Reduced vertical padding
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppConstants.backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'About Vulead Taxi',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: AppConstants.textColor,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vulead Taxi Driver App',
              style: GoogleFonts.poppins(fontSize: 14, color: AppConstants.textColor),
            ),
            const SizedBox(height: 6),
            Text(
              'Version: 1.0.0',
              style: GoogleFonts.poppins(fontSize: 12, color: AppConstants.subtitleColor),
            ),
            const SizedBox(height: 6),
            Text(
              '© 2025 Vulead Technologies',
              style: GoogleFonts.poppins(fontSize: 12, color: AppConstants.subtitleColor),
            ),
            const SizedBox(height: 12),
            Text(
              'Your trusted partner for ride-sharing services.',
              style: GoogleFonts.poppins(fontSize: 12, color: AppConstants.subtitleColor),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: GoogleFonts.poppins(
                color: AppConstants.accentColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}