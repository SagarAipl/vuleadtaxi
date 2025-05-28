import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vuleadtaxi/RegistrationSuccessScreen.dart';

class SkillUploadScreen extends StatefulWidget {
  final String skillName;

  const SkillUploadScreen({
    Key? key,
    required this.skillName,
  }) : super(key: key);

  @override
  State<SkillUploadScreen> createState() => _SkillUploadScreenState();
}

class _SkillUploadScreenState extends State<SkillUploadScreen> {
  DateTime? _issueDate;
  DateTime? _validityDate;
  List<File> _selectedImages = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool? _hasCertificate;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImages() async {
    final List<XFile>? images = await _picker.pickMultiImage();

    if (images != null && images.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(images.map((image) => File(image.path)).toList());
      });
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _selectedImages.add(File(image.path));
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _selectDate(BuildContext context, bool isIssueDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isIssueDate ? _issueDate ?? DateTime.now() : _validityDate ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: isIssueDate ? DateTime(2000) : DateTime.now(),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFE89D43),
              onPrimary: Colors.white,
              surface: Color(0xFF444444),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF333333),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isIssueDate) {
          _issueDate = picked;
        } else {
          _validityDate = picked;
        }
      });
    }
  }

  Future<void> _uploadSkill() async {
    if (_hasCertificate == null) {
      setState(() {
        _errorMessage = 'Please select whether you have a certificate';
      });
      return;
    }

    if (_hasCertificate == true) {
      if (_issueDate == null) {
        setState(() {
          _errorMessage = 'Please select issue date';
        });
        return;
      }

      if (_validityDate == null) {
        setState(() {
          _errorMessage = 'Please select validity date';
        });
        return;
      }

      if (_selectedImages.isEmpty) {
        setState(() {
          _errorMessage = 'Please select at least one image';
        });
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final uId = prefs.getInt('U_Id');
      final skillId = prefs.getInt('Skill_ID');

      if (uId == null || skillId == null) {
        setState(() {
          _errorMessage = 'User ID or Skill ID not found';
          _isLoading = false;
        });
        return;
      }

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://vnumdemo.caxis.ca/public/api/driver-skills'),
      );

      request.fields['Driv_Skill_Seq'] = '1';
      request.fields['Skill_Id'] = skillId.toString();
      request.fields['U_Id'] = uId.toString();

      if (_hasCertificate == true) {
        request.fields['Cert_Issue_Date'] = DateFormat('yyyy-MM-dd HH:mm:ss').format(_issueDate!);
        request.fields['Cert_Valid_To'] = DateFormat('yyyy-MM-dd HH:mm:ss').format(_validityDate!);

        for (var i = 0; i < _selectedImages.length; i++) {
          final file = _selectedImages[i];
          final stream = http.ByteStream(file.openRead());
          final length = await file.length();

          final multipartFile = http.MultipartFile(
            'Cert_Image[]',
            stream,
            length,
            filename: 'skill_image_$i.jpg',
          );
          request.files.add(multipartFile);
        }
      }

      final response = await request.send();
      final responseString = await response.stream.bytesToString();

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => const RegistrationSuccessScreen(),
            ),
                (route) => false,
          );
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to upload skill: $responseString';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF333333),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Upload ${widget.skillName}',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFE89D43)))
            : SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Upload ${widget.skillName} Certificate',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please provide certificate details',
                  style: TextStyle(fontSize: 16, color: Colors.white70),
                ),
                const SizedBox(height: 30),

                const Text(
                  'Do you have a certificate?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<bool>(
                        title: const Text('Yes', style: TextStyle(color: Colors.white)),
                        value: true,
                        groupValue: _hasCertificate,
                        onChanged: (value) => setState(() => _hasCertificate = value),
                        activeColor: const Color(0xFFE89D43),
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<bool>(
                        title: const Text('No', style: TextStyle(color: Colors.white)),
                        value: false,
                        groupValue: _hasCertificate,
                        onChanged: (value) => setState(() => _hasCertificate = value),
                        activeColor: const Color(0xFFE89D43),
                      ),
                    ),
                  ],
                ),

                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(top: 20),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 20),

                if (_hasCertificate == true) ...[
                  _buildDateField(
                    label: 'Certificate Issue Date',
                    value: _issueDate != null
                        ? DateFormat('dd/MM/yyyy').format(_issueDate!)
                        : 'Select Date',
                    onTap: () => _selectDate(context, true),
                  ),
                  const SizedBox(height: 16),

                  _buildDateField(
                    label: 'Certificate Valid Until',
                    value: _validityDate != null
                        ? DateFormat('dd/MM/yyyy').format(_validityDate!)
                        : 'Select Date',
                    onTap: () => _selectDate(context, false),
                  ),
                  const SizedBox(height: 24),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Certificate Images',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_selectedImages.isNotEmpty)
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          itemCount: _selectedImages.length,
                          itemBuilder: (context, index) {
                            return Stack(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    image: DecorationImage(
                                      image: FileImage(_selectedImages[index]),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: GestureDetector(
                                    onTap: () => _removeImage(index),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close, size: 16, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: _pickImages,
                        child: Container(
                          width: double.infinity,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate,
                                  size: 40, color: Colors.white.withOpacity(0.7)),
                              const SizedBox(height: 8),
                              Text('Add Certificate Images',
                                  style: TextStyle(color: Colors.white.withOpacity(0.7))),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

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
                    onPressed: _uploadSkill,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE89D43),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Upload Certificate',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: const Color(0xFFE89D43)),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}