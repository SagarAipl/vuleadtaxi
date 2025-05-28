import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vuleadtaxi/SkillSelectionScreen.dart';

class DocumentUploadScreen extends StatefulWidget {
  final String documentName;

  const DocumentUploadScreen({
    Key? key,
    required this.documentName,
  }) : super(key: key);

  @override
  State<DocumentUploadScreen> createState() => _DocumentUploadScreenState();
}

class _DocumentUploadScreenState extends State<DocumentUploadScreen> {
  final _referenceController = TextEditingController();
  DateTime? _issueDate;
  DateTime? _validityDate;
  List<File> _selectedImages = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _showProgress = false;
  double _uploadProgress = 0.0;

  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final List<XFile>? images = await _picker.pickMultiImage();

    if (images != null && images.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(images.map((image) => File(image.path)).toList());
      });
    }
  }

  Future<void> _captureImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);

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

  void _previewImage(int index) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                _selectedImages[index],
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Close'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _removeImage(index);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, bool isIssueDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isIssueDate
          ? _issueDate ?? DateTime.now()
          : _validityDate ?? DateTime.now().add(const Duration(days: 365)),
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

  bool _validateForm() {
    if (_referenceController.text.isEmpty) {
      setState(() => _errorMessage = 'Please enter document reference number');
      return false;
    }

    if (_issueDate == null) {
      setState(() => _errorMessage = 'Please select issue date');
      return false;
    }

    if (_validityDate == null) {
      setState(() => _errorMessage = 'Please select validity date');
      return false;
    }

    if (_selectedImages.isEmpty) {
      setState(() => _errorMessage = 'Please select at least one image');
      return false;
    }

    if (_issueDate!.isAfter(_validityDate!)) {
      setState(() => _errorMessage = 'Issue date cannot be after validity date');
      return false;
    }

    setState(() => _errorMessage = null);
    return true;
  }

  Future<void> _uploadDocument() async {
    if (!_validateForm()) return;

    setState(() {
      _isLoading = true;
      _showProgress = true;
      _uploadProgress = 0.0;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final uId = prefs.getInt('U_Id');
      final docId = prefs.getInt('Doc_ID');

      if (uId == null || docId == null) {
        setState(() {
          _errorMessage = 'User ID or Document ID not found';
          _isLoading = false;
          _showProgress = false;
        });
        return;
      }

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://vnumdemo.caxis.ca/public/api/driver-documents'),
      );

      // Add fields
      request.fields['Driv_Doc_Seq'] = '1';
      request.fields['Doc_ID'] = docId.toString();
      request.fields['Doc_Ref'] = _referenceController.text;
      request.fields['Doc_Issue_Date'] = DateFormat('yyyy-MM-dd HH:mm:ss').format(_issueDate!);
      request.fields['Doc_Valid_To'] = DateFormat('yyyy-MM-dd HH:mm:ss').format(_validityDate!);
      request.fields['U_Id'] = uId.toString();

      // Add images
      for (var i = 0; i < _selectedImages.length; i++) {
        final file = _selectedImages[i];
        request.files.add(await http.MultipartFile.fromPath(
          'Doc_Image[]',
          file.path,
          filename: 'image_$i.jpg',
        ));
        setState(() {
          _uploadProgress = (i + 1) / _selectedImages.length * 0.5;
        });
      }

      final streamedResponse = await request.send();
      final responseString = await streamedResponse.stream.bytesToString();
      final responseJson = jsonDecode(responseString); // Parse JSON response

      setState(() {
        _uploadProgress = 1.0;
      });

      if (streamedResponse.statusCode == 200 || streamedResponse.statusCode == 201) {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SkillSelectionScreen(),
            ),
          );
        }
      } else {
        setState(() {
          // Try to get error message from API response
          String error = responseJson['message'] ??
              responseJson['error'] ??
              'Upload failed: ${streamedResponse.statusCode}';
          _errorMessage = error;
          _isLoading = false;
          _showProgress = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error uploading document: ${e.toString()}';
        _isLoading = false;
        _showProgress = false;
      });
    }
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
          'Upload ${widget.documentName}',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: const Color(0xFF444444),
                  title: const Text('Document Requirements', style: TextStyle(color: Colors.white)),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoItem(Icons.description, 'Valid reference number required'),
                      _buildInfoItem(Icons.calendar_today, 'Issue date must be in the past'),
                      _buildInfoItem(Icons.event, 'Validity date must be in the future'),
                      _buildInfoItem(Icons.image, 'Images must be clear and legible'),
                      _buildInfoItem(Icons.warning, 'All fields are mandatory'),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Understood', style: TextStyle(color: Color(0xFFE89D43))),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_showProgress) ...[
                CircularProgressIndicator(
                  value: _uploadProgress,
                  color: const Color(0xFFE89D43),
                ),
                const SizedBox(height: 20),
                Text(
                  'Uploading document... ${(_uploadProgress * 100).toInt()}%',
                  style: const TextStyle(color: Colors.white),
                ),
              ] else ...[
                const CircularProgressIndicator(
                  color: Color(0xFFE89D43),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Processing...',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ],
          ),
        )
            : SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE89D43).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.file_present,
                        color: Color(0xFFE89D43),
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Upload ${widget.documentName}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Please provide all required information',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),

                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red, size: 20),
                          onPressed: () => setState(() => _errorMessage = null),
                        ),
                      ],
                    ),
                  ),

                // Reference Number
                _buildSectionTitle('Reference Number'),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _referenceController,
                  hintText: 'Enter document reference number',
                  icon: Icons.numbers,
                  keyboardType: TextInputType.text,
                ),
                const SizedBox(height: 24),

                // Date Selection
                _buildSectionTitle('Document Dates'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildDateField(
                        label: 'Issue Date',
                        value: _issueDate != null
                            ? DateFormat('dd/MM/yyyy').format(_issueDate!)
                            : 'Select Date',
                        onTap: () => _selectDate(context, true),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildDateField(
                        label: 'Valid Until',
                        value: _validityDate != null
                            ? DateFormat('dd/MM/yyyy').format(_validityDate!)
                            : 'Select Date',
                        onTap: () => _selectDate(context, false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Image Upload
                _buildSectionTitle('Document Images'),
                const SizedBox(height: 8),
                _buildImageSection(),
                const SizedBox(height: 40),

                // Upload Button
                _buildUploadButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFE89D43), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: const Color(0xFFE89D43),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
          prefixIcon: Icon(icon, color: const Color(0xFFE89D43)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 20),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today, color: const Color(0xFFE89D43), size: 20),
                const SizedBox(width: 10),
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

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image Preview Grid
        if (_selectedImages.isNotEmpty) ...[
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
              return GestureDetector(
                onTap: () => _previewImage(index),
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(
                          image: FileImage(_selectedImages[index]),
                          fit: BoxFit.cover,
                        ),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 5,
                      right: 5,
                      child: GestureDetector(
                        onTap: () => _removeImage(index),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
        ],

        // Add Image Buttons
        Row(
          children: [
            Expanded(
              child: _buildImageUploadButton(
                icon: Icons.image,
                label: 'Gallery',
                onTap: _pickImages,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildImageUploadButton(
                icon: Icons.camera_alt,
                label: 'Camera',
                onTap: _captureImage,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildImageUploadButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 32,
              color: const Color(0xFFE89D43),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadButton() {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFFE89D43), Color(0xFFBF7B30)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE89D43).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _uploadDocument,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_upload, color: Colors.white),
            const SizedBox(width: 10),
            const Text(
              'Upload Document',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}