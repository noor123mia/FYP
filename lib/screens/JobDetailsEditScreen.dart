import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// Enhanced theme definition with more vibrant colors
final appTheme = ThemeData(
  primaryColor: Color(0xFF1E3A8A), // Rich navy blue
  primaryColorLight: Color(0xFF3151A6),
  secondaryHeaderColor: Color(0xFF0D9488), // Teal accent
  scaffoldBackgroundColor: Color(0xFFF9FAFB),
  fontFamily: 'Poppins',
  textTheme: TextTheme(
    headlineLarge: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.bold,
      color: Color(0xFF1F2937),
    ),
    headlineMedium: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: Color(0xFF1F2937),
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: Color(0xFF1F2937),
    ),
    titleMedium: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: Color(0xFF1F2937),
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      color: Color(0xFF1F2937),
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      color: Color(0xFF6B7280),
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: Color(0xFF1E3A8A),
      foregroundColor: Colors.white,
      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
    ),
  ),
  cardTheme: CardTheme(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    elevation: 2,
    color: Colors.white,
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: Color(0xFF1E3A8A),
    elevation: 0,
    centerTitle: false,
    iconTheme: IconThemeData(color: Colors.white),
    toolbarTextStyle: TextStyle(
      color: Colors.white,
      fontSize: 20,
      fontWeight: FontWeight.bold,
    ),
    titleTextStyle: TextStyle(
      color: Colors.white,
      fontSize: 20,
      fontWeight: FontWeight.bold,
    ),
  ),
  colorScheme: ColorScheme.light(
    primary: Color(0xFF1E3A8A),
    secondary: Color(0xFF0D9488),
    surface: Colors.white,
    background: Color(0xFFF9FAFB),
    error: Color(0xFFEF4444),
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    tertiary: Color(0xFF6366F1), // Indigo
    tertiaryContainer: Color(0xFFEEF2FF), // Light indigo
    secondaryContainer: Color(0xFFDCFCE7), // Light teal
    primaryContainer: Color(0xFFDBEAFE), // Light blue
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Color(0xFFE5E7EB), width: 1),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Color(0xFFE5E7EB), width: 1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Color(0xFF1E3A8A), width: 2),
    ),
    contentPadding: EdgeInsets.all(16),
    labelStyle: TextStyle(color: Color(0xFF4B5563)),
    hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
  ),
);

class JobDetailsEditScreen extends StatefulWidget {
  final String jobId;
  final bool isViewMode;

  const JobDetailsEditScreen(
      {Key? key, required this.jobId, this.isViewMode = false})
      : super(key: key);

  @override
  _JobDetailsEditScreenState createState() => _JobDetailsEditScreenState();
}

class _JobDetailsEditScreenState extends State<JobDetailsEditScreen> {
  bool isEditing = false;
  Map<String, TextEditingController> controllers = {};
  Map<String, dynamic> jobDetails = {};
  bool isLoading = true;
  String? errorMessage;

  // Field categories for better organization
  final List<String> basicInfoFields = [
    'title',
    'company_name',
    'location',
    'job_type',
    'last_date_to_apply'
  ];
  final List<String> descriptionFields = [
    'position_summary',
    'responsibilities',
    'required_skills',
    'preferred_skills',
    'technical_skills',
    'what_we_offer'
  ];

  // Field labels for better display
  final Map<String, String> fieldLabels = {
    'title': 'JOB TITLE',
    'company_name': 'COMPANY NAME',
    'location': 'LOCATION',
    'job_type': 'JOB TYPE',
    'position_summary': 'POSITION SUMMARY',
    'responsibilities': 'RESPONSIBILITIES',
    'required_skills': 'REQUIRED SKILLS',
    'preferred_skills': 'PREFERRED SKILLS',
    'technical_skills': 'TECHNICAL SKILLS',
    'what_we_offer': 'WHAT WE OFFER',
    'last_date_to_apply': 'LAST DATE TO APPLY',
  };

  // Field icons for visual appeal
  final Map<String, IconData> fieldIcons = {
    'title': Icons.work_outline,
    'company_name': Icons.business,
    'location': Icons.location_on_outlined,
    'job_type': Icons.category_outlined,
    'position_summary': Icons.description_outlined,
    'responsibilities': Icons.assignment_outlined,
    'required_skills': Icons.check_circle_outline,
    'preferred_skills': Icons.star_outline,
    'technical_skills': Icons.code,
    'what_we_offer': Icons.card_giftcard,
    'last_date_to_apply': Icons.calendar_today,
  };

  @override
  void initState() {
    super.initState();
    isEditing = !widget.isViewMode;
    _fetchJobDetails();
  }

  Future<void> _fetchJobDetails() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      print("Fetching job details for Job ID: ${widget.jobId}");

      DocumentSnapshot jobDoc = await FirebaseFirestore.instance
          .collection('JobsInDraft')
          .doc(widget.jobId)
          .get();

      if (jobDoc.exists) {
        Map<String, dynamic> jobData = jobDoc.data() as Map<String, dynamic>;
        print("Job Data Retrieved: $jobData");

        // Handle description data for both formats
        Map<String, dynamic> descriptionData = {};
        if (jobData['description'] is String) {
          try {
            final decoded = jsonDecode(jobData['description']);
            if (decoded is Map<String, dynamic>) {
              // Second format: description contains nested description
              descriptionData = decoded['description'] ?? decoded;
            }
          } catch (e) {
            print("Error decoding JSON description: $e");
            descriptionData = {};
          }
        } else if (jobData['description'] is Map<String, dynamic>) {
          // First format: description is already a map
          descriptionData = jobData['description'];
        }

        setState(() {
          jobDetails = jobData;
          controllers = {
            'title': TextEditingController(text: jobData['title'] ?? ''),
            'company_name':
                TextEditingController(text: jobData['company_name'] ?? ''),
            'location': TextEditingController(text: jobData['location'] ?? ''),
            'job_type': TextEditingController(text: jobData['job_type'] ?? ''),
            'position_summary': TextEditingController(
                text: descriptionData['position_summary'] ?? ''),
            'responsibilities': TextEditingController(
                text: (descriptionData['responsibilities'] ?? []).join("\n")),
            'required_skills': TextEditingController(
                text: (descriptionData['required_skills'] ?? []).join("\n")),
            'preferred_skills': TextEditingController(
                text: (descriptionData['preferred_skills'] ?? []).join("\n")),
            'technical_skills': TextEditingController(
                text: _formatTechnicalSkills(
                    descriptionData['technical_skills'])),
            'what_we_offer': TextEditingController(
                text: (descriptionData['what_we_offer'] ?? []).join("\n")),
            'last_date_to_apply': TextEditingController(
              text: jobData['last_date_to_apply'] is Timestamp
                  ? DateFormat('dd/MM/yyyy')
                      .format(jobData['last_date_to_apply'].toDate())
                  : jobData['last_date_to_apply'] ?? '',
            ),
          };
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
          errorMessage = "Job not found";
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Job not found"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = "Error loading job details";
      });
      print("Error fetching job details: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error loading job details: $e"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  String _formatTechnicalSkills(Map<String, dynamic>? technicalSkills) {
    if (technicalSkills == null) return "";
    return technicalSkills.entries
        .map((entry) => "${entry.key}: ${entry.value.join(', ')}")
        .join("\n");
  }

  void _selectDate(BuildContext context) async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: appTheme.primaryColor,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: appTheme.primaryColor,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      setState(() {
        controllers['last_date_to_apply']!.text =
            DateFormat('dd/MM/yyyy').format(pickedDate);
      });
    }
  }

  void _saveChanges() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Center(
            child: Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(appTheme.primaryColor),
                    ),
                    SizedBox(height: 16),
                    Text(
                      "Saving changes...",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );

      // First, verify document exists
      DocumentSnapshot docCheck = await FirebaseFirestore.instance
          .collection('JobsInDraft')
          .doc(widget.jobId)
          .get();

      if (!docCheck.exists) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 16),
                Text("Job no longer exists in database"),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        return;
      }

      // Parse technical skills properly
      Map<String, dynamic> technicalSkillsMap = {};
      try {
        String technicalSkillsText =
            controllers['technical_skills']!.text.trim();
        if (technicalSkillsText.isNotEmpty) {
          List<String> skillGroups = technicalSkillsText.split('\n');
          for (String group in skillGroups) {
            if (group.contains(':')) {
              List<String> parts = group.split(':');
              String category = parts[0].trim();
              if (parts.length > 1) {
                String skillsText = parts[1].trim();
                List<String> skills =
                    skillsText.split(',').map((e) => e.trim()).toList();
                technicalSkillsMap[category] = skills;
              }
            }
          }
        }
      } catch (e) {
        print("Error parsing technical skills: $e");
        technicalSkillsMap = jobDetails['description'] is Map<String, dynamic>
            ? jobDetails['description']['technical_skills'] ?? {}
            : {};
      }

      // Prepare the updated description map
      Map<String, dynamic> updatedDescription = {
        "position_summary": controllers['position_summary']!.text.trim(),
        "responsibilities": controllers['responsibilities']!
            .text
            .split("\n")
            .where((line) => line.trim().isNotEmpty)
            .map((e) => e.trim())
            .toList(),
        "required_skills": controllers['required_skills']!
            .text
            .split("\n")
            .where((line) => line.trim().isNotEmpty)
            .map((e) => e.trim())
            .toList(),
        "preferred_skills": controllers['preferred_skills']!
            .text
            .split("\n")
            .where((line) => line.trim().isNotEmpty)
            .map((e) => e.trim())
            .toList(),
        "technical_skills": technicalSkillsMap,
        "what_we_offer": controllers['what_we_offer']!
            .text
            .split("\n")
            .where((line) => line.trim().isNotEmpty)
            .map((e) => e.trim())
            .toList(),
      };

      // Determine the description format based on original job data
      dynamic descriptionToSave = updatedDescription;
      if (jobDetails['description'] is String) {
        // Second format: save as JSON string with nested structure
        descriptionToSave = jsonEncode({
          'job_title': controllers['title']!.text.trim(),
          'description': updatedDescription,
        });
      }

      // Update the job document in the JobsInDraft collection
      await FirebaseFirestore.instance
          .collection('JobsInDraft')
          .doc(widget.jobId)
          .update({
        'title': controllers['title']!.text.trim(),
        'company_name': controllers['company_name']!.text.trim(),
        'location': controllers['location']!.text.trim(),
        'job_type': controllers['job_type']!.text.trim(),
        'description': descriptionToSave,
        'last_date_to_apply': controllers['last_date_to_apply']!.text.isNotEmpty
            ? Timestamp.fromDate(DateFormat('dd/MM/yyyy')
                .parse(controllers['last_date_to_apply']!.text))
            : null,
        'updated_at': Timestamp.now(),
      });

      // Close loading dialog
      Navigator.of(context).pop();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 16),
              Text("Job updated successfully in drafts"),
            ],
          ),
          backgroundColor: Color(0xFF10B981), // Vibrant green
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: Duration(seconds: 3),
        ),
      );

      // Set editing mode to false after successful save
      setState(() => isEditing = false);
    } catch (e) {
      // Close loading dialog
      Navigator.of(context).pop();

      print("Error saving changes: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 16),
              Expanded(child: Text("Error saving changes: $e")),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  // Helper method to build a section header
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
              color: appTheme.colorScheme.secondary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: appTheme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to build a text field with consistent styling
  Widget _buildTextField(String fieldKey) {
    final bool isMultiLine = descriptionFields.contains(fieldKey);
    final IconData icon = fieldIcons[fieldKey] ?? Icons.edit;
    final String label =
        fieldLabels[fieldKey] ?? fieldKey.replaceAll('_', ' ').toUpperCase();

    // Different background colors for different field categories
    Color? fillColor;
    if (fieldKey == 'position_summary') {
      fillColor = appTheme.colorScheme.primaryContainer.withOpacity(0.3);
    } else if (fieldKey.contains('skills')) {
      fillColor = appTheme.colorScheme.tertiaryContainer.withOpacity(0.3);
    } else if (fieldKey == 'what_we_offer') {
      fillColor = appTheme.colorScheme.secondaryContainer.withOpacity(0.3);
    } else if (fieldKey == 'responsibilities') {
      fillColor = Color(0xFFFEF3C7).withOpacity(0.5); // Light amber
    }

    return Card(
      elevation: 0,
      color: Colors.transparent,
      margin: EdgeInsets.symmetric(vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: fillColor ?? Colors.white,
          boxShadow: [
            if (isEditing)
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
          ],
        ),
        child: TextField(
          controller: controllers[fieldKey],
          enabled: isEditing,
          maxLines: isMultiLine ? null : 1,
          minLines: isMultiLine ? 3 : 1,
          decoration: InputDecoration(
            labelText: label,
            hintText: 'Enter ${label.toLowerCase()}',
            prefixIcon: Icon(icon,
                color: isEditing ? appTheme.primaryColor : Colors.grey),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isEditing ? appTheme.primaryColor : Colors.grey.shade300,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: appTheme.primaryColor, width: 2),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.transparent),
            ),
            filled: true,
            fillColor: isEditing ? Colors.white : Colors.grey.shade50,
            suffixIcon: fieldKey == 'last_date_to_apply' && isEditing
                ? IconButton(
                    icon: Icon(
                      Icons.calendar_today,
                      color: appTheme.colorScheme.secondary,
                    ),
                    onPressed: () => _selectDate(context),
                  )
                : null,
            helperText: isMultiLine ? 'Enter each item on a new line' : null,
            helperStyle: TextStyle(fontStyle: FontStyle.italic),
          ),
          style: TextStyle(
            fontSize: 16,
            color: isEditing ? Colors.black87 : Colors.black54,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: appTheme,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            isEditing ? 'Edit Job Details' : 'Job Details',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          elevation: 0,
          actions: [
            if (!isEditing)
              Container(
                margin: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: Icon(Icons.edit, color: Colors.white),
                  tooltip: 'Edit Job Details',
                  onPressed: () => setState(() => isEditing = true),
                ),
              ),
            if (isEditing)
              Container(
                margin: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: Icon(Icons.save, color: Colors.white),
                  tooltip: 'Save Changes',
                  onPressed: _saveChanges,
                ),
              ),
          ],
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  appTheme.primaryColor,
                  appTheme.colorScheme.tertiary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        body: isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(appTheme.primaryColor),
                    ),
                    SizedBox(height: 24),
                    Text(
                      "Loading job details...",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              )
            : errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red.shade400,
                        ),
                        SizedBox(height: 16),
                        Text(
                          errorMessage!,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade700,
                          ),
                        ),
                        SizedBox(height: 24),
                        ElevatedButton.icon(
                          icon: Icon(Icons.refresh),
                          label: Text("Try Again"),
                          onPressed: _fetchJobDetails,
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          appTheme.scaffoldBackgroundColor,
                          Colors.white,
                        ],
                      ),
                    ),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Status banner
                          Container(
                            margin: EdgeInsets.only(bottom: 16, top: 8),
                            padding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  appTheme.colorScheme.primary.withOpacity(0.1),
                                  appTheme.colorScheme.tertiary
                                      .withOpacity(0.1),
                                ],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: appTheme.colorScheme.primary
                                    .withOpacity(0.2),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: appTheme.colorScheme.primary,
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    isEditing
                                        ? "You're currently editing this job in draft mode"
                                        : "Viewing job draft details in read-only mode",
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: appTheme.colorScheme.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Basic Information Section
                          _buildSectionHeader("Basic Information"),
                          ...basicInfoFields.map(_buildTextField).toList(),

                          // Job Description Section
                          _buildSectionHeader("Job Description"),
                          ...descriptionFields.map(_buildTextField).toList(),

                          // Action buttons at bottom
                          SizedBox(height: 24),
                          if (isEditing)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                OutlinedButton.icon(
                                  icon: Icon(Icons.cancel),
                                  label: Text("Cancel"),
                                  onPressed: () =>
                                      setState(() => isEditing = false),
                                  style: OutlinedButton.styleFrom(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 32, vertical: 16),
                                    side: BorderSide(
                                        color: appTheme.colorScheme.primary),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                                ElevatedButton.icon(
                                  icon: Icon(Icons.save),
                                  label: Text("Save Draft"),
                                  onPressed: _saveChanges,
                                  style: ElevatedButton.styleFrom(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 32, vertical: 16),
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
        bottomNavigationBar: !isLoading && errorMessage == null
            ? Container(
                height: isEditing ? 0 : 60,
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: isEditing
                    ? null
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            icon: Icon(Icons.edit),
                            label: Text("Edit Job Draft"),
                            onPressed: () => setState(() => isEditing = true),
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 32, vertical: 12),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
              )
            : null,
      ),
    );
  }
}
