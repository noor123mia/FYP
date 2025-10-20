import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'
    as firebase_auth; // Alias for Firebase Auth
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart'
    as supabase; // Alias for Supabase
import 'package:flutter_application_2/services/supabase_config.dart';

class ApplicationFormScreen extends StatefulWidget {
  final String jobId;
  final String jobTitle;
  final String companyName;
  final VoidCallback onApplicationSubmitted;

  const ApplicationFormScreen({
    Key? key,
    required this.jobId,
    required this.jobTitle,
    required this.companyName,
    required this.onApplicationSubmitted,
  }) : super(key: key);

  @override
  _ApplicationFormScreenState createState() => _ApplicationFormScreenState();
}

class _ApplicationFormScreenState extends State<ApplicationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final supabase.SupabaseClient _supabase = supabase.Supabase.instance.client;

  bool _isLoading = false;
  bool _isSubmitting = false;

  // Form fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  // Education fields
  List<Map<String, dynamic>> _educations = [
    {
      'institution': '',
      'degree': '',
      'fieldOfStudy': '',
      'startYear': '',
      'endYear': ''
    }
  ];

  // Experience fields
  List<Map<String, dynamic>> _experiences = [
    {
      'company': '',
      'position': '',
      'startDate': '',
      'endDate': '',
      'description': ''
    }
  ];

  // Skills
  final TextEditingController _technicalSkillsController =
      TextEditingController();
  final TextEditingController _softSkillsController = TextEditingController();
  final TextEditingController _languagesController = TextEditingController();

  // Resume
  File? _resumeFile;
  String? _resumeFileName;
  String? _resumeUrl;

  // Profile picture
  File? _profilePicFile;
  String? _profilePicUrl;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final firebase_auth.User? user = _auth.currentUser;
      if (user != null) {
        // Set email from current user
        _emailController.text = user.email ?? '';

        // Check if user profile exists
        final profileDoc = await _firestore
            .collection('JobSeekersProfiles')
            .doc(user.uid)
            .get();

        if (profileDoc.exists) {
          final profileData = profileDoc.data() as Map<String, dynamic>;

          // Fill form fields with existing data
          _nameController.text = profileData['name'] ?? '';
          _phoneController.text = profileData['phone'] ?? '';
          _addressController.text = profileData['location'] ?? '';

          // Education
          if (profileData['educations'] != null &&
              (profileData['educations'] as List).isNotEmpty) {
            _educations =
                List<Map<String, dynamic>>.from(profileData['educations']);
          }

          // Experience
          if (profileData['workExperiences'] != null &&
              (profileData['workExperiences'] as List).isNotEmpty) {
            _experiences =
                List<Map<String, dynamic>>.from(profileData['workExperiences']);
          }

          // Skills
          _technicalSkillsController.text =
              (profileData['technicalSkills'] as List?)?.join(', ') ?? '';
          _softSkillsController.text =
              (profileData['softSkills'] as List?)?.join(', ') ?? '';
          _languagesController.text =
              (profileData['languages'] as List?)?.join(', ') ?? '';

          // URLs
          _resumeUrl = profileData['resumeUrl'];
          _profilePicUrl = profileData['profilePicUrl'];

          if (_resumeUrl != null && _resumeUrl!.isNotEmpty) {
            _resumeFileName = _resumeUrl!.split('/').last;
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading profile data: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text(
          "Job Application",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        backgroundColor: Color(0xFF1E3A8A),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Color(0xFF1E3A8A)))
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Job Banner
                  Container(
                    padding: EdgeInsets.all(16),
                    color: Color(0xFFE0E7FF),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Color(0xFF1E3A8A),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              widget.companyName.substring(0, 1),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.jobTitle,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Color(0xFF1E3A8A),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                widget.companyName,
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Application Form
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader("Personal Information"),
                          SizedBox(height: 12),

                          // Profile picture
                          Center(
                            child: Column(
                              children: [
                                InkWell(
                                  onTap: _pickProfilePic,
                                  child: Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      color: Color(0xFFE0E7FF),
                                      shape: BoxShape.circle,
                                      image: _profilePicFile != null
                                          ? DecorationImage(
                                              image:
                                                  FileImage(_profilePicFile!),
                                              fit: BoxFit.cover,
                                            )
                                          : _profilePicUrl != null
                                              ? DecorationImage(
                                                  image: NetworkImage(
                                                      _profilePicUrl!),
                                                  fit: BoxFit.cover,
                                                )
                                              : null,
                                    ),
                                    child: _profilePicFile == null &&
                                            _profilePicUrl == null
                                        ? Icon(
                                            Icons.person,
                                            size: 50,
                                            color: Color(0xFF1E3A8A),
                                          )
                                        : null,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  "Upload Profile Picture",
                                  style: TextStyle(
                                    color: Color(0xFF1E3A8A),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 20),

                          // Name
                          _buildTextField(
                            controller: _nameController,
                            label: "Full Name",
                            hint: "Enter your full name",
                            icon: Icons.person_outline,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your name';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16),

                          // Email
                          _buildTextField(
                            controller: _emailController,
                            label: "Email",
                            hint: "Enter your email",
                            icon: Icons.email_outlined,
                            readOnly: true,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your email';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16),

                          // Phone
                          _buildTextField(
                            controller: _phoneController,
                            label: "Phone Number",
                            hint: "Enter your phone number",
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your phone number';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16),

                          // Address
                          _buildTextField(
                            controller: _addressController,
                            label: "Address",
                            hint: "Enter your address",
                            icon: Icons.location_on_outlined,
                            maxLines: 2,
                          ),
                          SizedBox(height: 24),

                          // Education Section
                          _buildSectionHeader("Education"),
                          SizedBox(height: 12),

                          ..._educations.asMap().entries.map((entry) {
                            final index = entry.key;
                            final education = entry.value;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (index > 0) Divider(height: 32),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "Education ${index + 1}",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 16,
                                      ),
                                    ),
                                    if (_educations.length > 1)
                                      IconButton(
                                        icon: Icon(Icons.delete_outline,
                                            color: Colors.red),
                                        onPressed: () {
                                          setState(() {
                                            _educations.removeAt(index);
                                          });
                                        },
                                      ),
                                  ],
                                ),
                                SizedBox(height: 12),
                                _buildTextField(
                                  label: "Institution",
                                  hint: "Enter school/university name",
                                  icon: Icons.school_outlined,
                                  initialValue: education['institution'],
                                  onChanged: (value) {
                                    _educations[index]['institution'] = value;
                                  },
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter institution name';
                                    }
                                    return null;
                                  },
                                ),
                                SizedBox(height: 12),
                                _buildTextField(
                                  label: "Degree",
                                  hint: "e.g. Bachelor's, Master's",
                                  icon: Icons.school_outlined,
                                  initialValue: education['degree'],
                                  onChanged: (value) {
                                    _educations[index]['degree'] = value;
                                  },
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter degree';
                                    }
                                    return null;
                                  },
                                ),
                                SizedBox(height: 12),
                                _buildTextField(
                                  label: "Field of Study",
                                  hint: "e.g. Computer Science",
                                  icon: Icons.subject_outlined,
                                  initialValue: education['fieldOfStudy'],
                                  onChanged: (value) {
                                    _educations[index]['fieldOfStudy'] = value;
                                  },
                                ),
                                SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildTextField(
                                        label: "Start Year",
                                        hint: "YYYY",
                                        keyboardType: TextInputType.number,
                                        initialValue: education['startYear'],
                                        onChanged: (value) {
                                          _educations[index]['startYear'] =
                                              value;
                                        },
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Required';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                    SizedBox(width: 16),
                                    Expanded(
                                      child: _buildTextField(
                                        label: "End Year (or Expected)",
                                        hint: "YYYY",
                                        keyboardType: TextInputType.number,
                                        initialValue: education['endYear'],
                                        onChanged: (value) {
                                          _educations[index]['endYear'] = value;
                                        },
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Required';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          }).toList(),

                          SizedBox(height: 12),
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _educations.add({
                                  'institution': '',
                                  'degree': '',
                                  'fieldOfStudy': '',
                                  'startYear': '',
                                  'endYear': ''
                                });
                              });
                            },
                            icon: Icon(Icons.add_circle_outline,
                                color: Color(0xFF1E3A8A)),
                            label: Text(
                              "Add Another Education",
                              style: TextStyle(color: Color(0xFF1E3A8A)),
                            ),
                          ),
                          SizedBox(height: 24),

                          // Experience Section
                          _buildSectionHeader("Work Experience"),
                          SizedBox(height: 12),

                          ..._experiences.asMap().entries.map((entry) {
                            final index = entry.key;
                            final experience = entry.value;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (index > 0) Divider(height: 32),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "Experience ${index + 1}",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 16,
                                      ),
                                    ),
                                    if (_experiences.length > 1)
                                      IconButton(
                                        icon: Icon(Icons.delete_outline,
                                            color: Colors.red),
                                        onPressed: () {
                                          setState(() {
                                            _experiences.removeAt(index);
                                          });
                                        },
                                      ),
                                  ],
                                ),
                                SizedBox(height: 12),
                                _buildTextField(
                                  label: "Company",
                                  hint: "Enter company name",
                                  icon: Icons.business_outlined,
                                  initialValue: experience['company'],
                                  onChanged: (value) {
                                    _experiences[index]['company'] = value;
                                  },
                                ),
                                SizedBox(height: 12),
                                _buildTextField(
                                  label: "Position",
                                  hint: "Enter job title",
                                  icon: Icons.work_outline,
                                  initialValue: experience['position'],
                                  onChanged: (value) {
                                    _experiences[index]['position'] = value;
                                  },
                                ),
                                SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildTextField(
                                        label: "Start Date",
                                        hint: "MM/YYYY",
                                        initialValue: experience['startDate'],
                                        onChanged: (value) {
                                          _experiences[index]['startDate'] =
                                              value;
                                        },
                                      ),
                                    ),
                                    SizedBox(width: 16),
                                    Expanded(
                                      child: _buildTextField(
                                        label: "End Date (or 'Present')",
                                        hint: "MM/YYYY",
                                        initialValue: experience['endDate'],
                                        onChanged: (value) {
                                          _experiences[index]['endDate'] =
                                              value;
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 12),
                                _buildTextField(
                                  label: "Description",
                                  hint:
                                      "Brief description of your responsibilities",
                                  maxLines: 3,
                                  initialValue: experience['description'],
                                  onChanged: (value) {
                                    _experiences[index]['description'] = value;
                                  },
                                ),
                              ],
                            );
                          }).toList(),

                          SizedBox(height: 12),
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _experiences.add({
                                  'company': '',
                                  'position': '',
                                  'startDate': '',
                                  'endDate': '',
                                  'description': ''
                                });
                              });
                            },
                            icon: Icon(Icons.add_circle_outline,
                                color: Color(0xFF1E3A8A)),
                            label: Text(
                              "Add Another Experience",
                              style: TextStyle(color: Color(0xFF1E3A8A)),
                            ),
                          ),
                          SizedBox(height: 24),

                          // Skills Section
                          _buildSectionHeader("Skills & Qualifications"),
                          SizedBox(height: 12),

                          _buildTextField(
                            controller: _technicalSkillsController,
                            label: "Technical Skills",
                            hint:
                                "E.g. JavaScript, React, Flutter (comma separated)",
                            icon: Icons.code_outlined,
                            maxLines: 2,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter at least one technical skill';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16),

                          _buildTextField(
                            controller: _softSkillsController,
                            label: "Soft Skills",
                            hint:
                                "E.g. Communication, Teamwork (comma separated)",
                            icon: Icons.people_outline,
                            maxLines: 2,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter at least one soft skill';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16),

                          _buildTextField(
                            controller: _languagesController,
                            label: "Languages",
                            hint: "E.g. English, Spanish (comma separated)",
                            icon: Icons.language_outlined,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter at least one language';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 24),

                          // Resume Upload
                          _buildSectionHeader("Resume / CV"),
                          SizedBox(height: 12),

                          GestureDetector(
                            onTap: _pickResumeFile,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  vertical: 16, horizontal: 12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.white,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Color(0xFFE0E7FF),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.file_upload_outlined,
                                      color: Color(0xFF1E3A8A),
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Upload Resume/CV",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF1E3A8A),
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          _resumeFileName ??
                                              _resumeUrl?.split('/').last ??
                                              "PDF, DOCX, or RTF format",
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[600],
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.arrow_forward_ios,
                                      size: 16, color: Colors.grey),
                                ],
                              ),
                            ),
                          ),
                          if (_resumeFile == null && _resumeUrl == null)
                            Padding(
                              padding:
                                  const EdgeInsets.only(top: 8.0, left: 16.0),
                              child: Text(
                                "* Resume is required",
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                            ),

                          SizedBox(height: 32),

                          // Submit Button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed:
                                  _isSubmitting ? null : _submitApplication,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF1E3A8A),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 0,
                              ),
                              child: _isSubmitting
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Text(
                                          "Submitting...",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Text(
                                      "Submit Application",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                            ),
                          ),
                          SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // Helper method to build section headers
  Widget _buildSectionHeader(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3A8A),
          ),
        ),
        SizedBox(height: 8),
        Container(
          width: 50,
          height: 3,
          decoration: BoxDecoration(
            color: Color(0xFF1E3A8A),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }

  // Helper method to build text fields
  Widget _buildTextField({
    TextEditingController? controller,
    String? initialValue,
    required String label,
    required String hint,
    IconData? icon,
    bool readOnly = false,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: controller,
          initialValue: initialValue,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey),
            prefixIcon: icon != null ? Icon(icon, color: Colors.grey) : null,
            filled: true,
            fillColor: Colors.white,
            contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Color(0xFF1E3A8A), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.red, width: 1),
            ),
          ),
          readOnly: readOnly,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          onChanged: onChanged,
        ),
      ],
    );
  }

  // Method to pick profile picture
  Future<void> _pickProfilePic() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedImage = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (pickedImage != null) {
        setState(() {
          _profilePicFile = File(pickedImage.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  // Method to pick resume file
  Future<void> _pickResumeFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'rtf'],
      );

      if (result != null) {
        setState(() {
          _resumeFile = File(result.files.single.path!);
          _resumeFileName = result.files.single.name;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking file: $e')),
      );
    }
  }

  // Method to upload files to Supabase
  Future<Map<String, String>> _uploadFilesToSupabase() async {
    final Map<String, String> fileUrls = {};

    // Upload resume if new file selected
    if (_resumeFile != null) {
      _resumeUrl = await _uploadToSupabase(_resumeFile!, 'resumes', _resumeUrl);
      if (_resumeUrl != null) {
        fileUrls['resumeUrl'] = _resumeUrl!;
      }
    } else if (_resumeUrl != null) {
      fileUrls['resumeUrl'] = _resumeUrl!;
    }

    // Upload profile pic if new file selected
    if (_profilePicFile != null) {
      _profilePicUrl = await _uploadToSupabase(
          _profilePicFile!, 'profile_pics', _profilePicUrl);
      if (_profilePicUrl != null) {
        fileUrls['profilePicUrl'] = _profilePicUrl!;
      }
    } else if (_profilePicUrl != null) {
      fileUrls['profilePicUrl'] = _profilePicUrl!;
    }

    return fileUrls;
  }

  // Method to upload a single file to Supabase
  Future<String?> _uploadToSupabase(
    File file,
    String folder, // e.g., 'resumes' or 'profile_pics'
    String? oldFileUrl,
  ) async {
    try {
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
      final fullPath = '$folder/$fileName';

      // Delete old file if exists
      if (oldFileUrl != null && oldFileUrl.isNotEmpty) {
        try {
          final oldPath = oldFileUrl
              .split('/storage/v1/object/public/smartrecruitfiles/')
              .last;
          await _supabase.storage.from('smartrecruitfiles').remove([oldPath]);
        } catch (e) {
          debugPrint('Failed to delete old file: $e');
        }
      }

      // Upload new file
      await _supabase.storage.from('smartrecruitfiles').upload(fullPath, file,
          fileOptions: const supabase.FileOptions(upsert: true));
      return _supabase.storage.from('smartrecruitfiles').getPublicUrl(fullPath);
    } catch (e) {
      debugPrint('Upload failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading file: $e')),
      );
      return null;
    }
  }

  // Method to submit application
  Future<void> _submitApplication() async {
    // Validate the form
    if (!_formKey.currentState!.validate()) {
      // Scroll to show validation errors
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fix the errors in the form')),
      );
      return;
    }

    // Check if resume is uploaded or already exists
    if (_resumeFile == null && _resumeUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please upload your resume')),
      );
      return;
    }

    try {
      setState(() {
        _isSubmitting = true;
      });

      final firebase_auth.User? user = _auth.currentUser;
      if (user == null) {
        throw Exception('No authenticated user found');
      }

      // Upload files if needed using Supabase
      final Map<String, String> fileUrls = await _uploadFilesToSupabase();

      // Prepare application data
      final applicationData = {
        'candidateId': user.uid,
        'jobId': widget.jobId,
        'jobTitle': widget.jobTitle,
        'companyName': widget.companyName,
        'appliedAt': Timestamp.now(),
        'status': 'Pending', // Initial status

        // Personal info
        'applicantName': _nameController.text,
        'applicantEmail': _emailController.text,
        'applicantPhone': _phoneController.text,
        'location': _addressController.text,

        // Education
        'educations': _educations,

        // Experience
        'workExperiences': _experiences,

        // Skills
        'technicalSkills': _technicalSkillsController.text
            .split(',')
            .map((skill) => skill.trim())
            .where((skill) => skill.isNotEmpty)
            .toList(),
        'softSkills': _softSkillsController.text
            .split(',')
            .map((skill) => skill.trim())
            .where((skill) => skill.isNotEmpty)
            .toList(),
        'languages': _languagesController.text
            .split(',')
            .map((language) => language.trim())
            .where((language) => language.isNotEmpty)
            .toList(),

        // URLs (from Supabase)
        'applicantResumeUrl': fileUrls['resumeUrl'] ?? _resumeUrl ?? '',
        'applicantProfileUrl':
            fileUrls['profilePicUrl'] ?? _profilePicUrl ?? '',
      };

      // Save application to Firestore
      await _firestore.collection('AppliedCandidates').add(applicationData);

      // Also update the user's profile
      await _updateUserProfile(applicationData, user.uid);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Application submitted successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Call the callback
      widget.onApplicationSubmitted();

      // Navigate back
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting application: $e')),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  // Method to update user profile in Firestore
  Future<void> _updateUserProfile(
      Map<String, dynamic> applicationData, String userId) async {
    try {
      // Only update the profile, not the application-specific data
      final profileData = {
        'name': applicationData['name'],
        'phone': applicationData['phone'],
        'location': applicationData['location'],
        'educations': applicationData['educations'],
        'workExperiences': applicationData['workExperiences'],
        'technicalSkills': applicationData['technicalSkills'],
        'softSkills': applicationData['softSkills'],
        'languages': applicationData['languages'],
        'resumeUrl': applicationData['resumeUrl'],
        'profilePicUrl': applicationData['profilePicUrl'],
        'lastUpdated': Timestamp.now(),
      };

      await _firestore.collection('JobSeekersProfiles').doc(userId).set(
            profileData,
            SetOptions(merge: true),
          );
    } catch (e) {
      debugPrint('Error updating profile: $e');
      // Continue with application submission even if profile update fails
    }
  }

  @override
  void dispose() {
    // Dispose of controllers
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _technicalSkillsController.dispose();
    _softSkillsController.dispose();
    _languagesController.dispose();
    super.dispose();
  }
}
