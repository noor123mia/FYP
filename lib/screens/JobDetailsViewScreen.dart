import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// Enhanced theme definition with more vibrant colors
final appTheme = ThemeData(
  primaryColor: Color(0xFF1E3A8A), // Rich navy blue
  scaffoldBackgroundColor: Color(0xFFF9FAFB),
  fontFamily: 'Poppins',
  textTheme: TextTheme(
    headlineLarge: TextStyle(
      fontSize: 28,
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
    tertiary: Color(0xFF6366F1), // Indigo
    tertiaryContainer: Color(0xFFEEF2FF), // Light indigo
    secondaryContainer: Color(0xFFDCFCE7), // Light teal
    primaryContainer: Color(0xFFDBEAFE), // Light blue
  ),
);

class JobDetailsViewScreen extends StatefulWidget {
  final String jobId;

  const JobDetailsViewScreen({Key? key, required this.jobId}) : super(key: key);

  @override
  _JobDetailsViewScreenState createState() => _JobDetailsViewScreenState();
}

class _JobDetailsViewScreenState extends State<JobDetailsViewScreen> {
  Map<String, dynamic> jobDetails = {};

  // Field categories for organization
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

  // Field labels for display
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
    _fetchJobDetails();
  }

  Future<void> _fetchJobDetails() async {
    DocumentSnapshot jobDoc = await FirebaseFirestore.instance
        .collection('JobsPosted')
        .doc(widget.jobId)
        .get();

    if (jobDoc.exists) {
      setState(() {
        jobDetails = jobDoc.data() as Map<String, dynamic>;
      });
    }
  }

  String _formatTechnicalSkills(Map<String, dynamic>? technicalSkills) {
    if (technicalSkills == null) return "";
    return technicalSkills.entries
        .map((entry) => "${entry.key}: ${entry.value.join(', ')}")
        .join("\n");
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

  // Helper method to build a display field with consistent styling
  Widget _buildDisplayField(String fieldKey) {
    final IconData icon = fieldIcons[fieldKey] ?? Icons.info;
    final String label =
        fieldLabels[fieldKey] ?? fieldKey.replaceAll('_', ' ').toUpperCase();

    String displayText = "";
    if (basicInfoFields.contains(fieldKey)) {
      if (fieldKey == 'last_date_to_apply' &&
          jobDetails[fieldKey] is Timestamp) {
        displayText =
            DateFormat('dd/MM/yyyy').format(jobDetails[fieldKey].toDate());
      } else {
        displayText = jobDetails[fieldKey]?.toString() ?? "";
      }
    } else {
      Map<String, dynamic> descriptionData = {};

      // Check if description is a JSON string (second format)
      if (jobDetails['description'] is String) {
        try {
          final decoded = jsonDecode(jobDetails['description']);
          if (decoded is Map<String, dynamic>) {
            descriptionData = decoded['description'] ?? decoded;
          }
        } catch (e) {
          descriptionData = jobDetails['description'] is Map<String, dynamic>
              ? jobDetails['description']
              : {};
        }
      } else if (jobDetails['description'] is Map<String, dynamic>) {
        // First format: description is already a map
        descriptionData = jobDetails['description'];
      }

      if (fieldKey == 'position_summary') {
        displayText = descriptionData[fieldKey]?.toString() ?? "";
      } else if (fieldKey == 'technical_skills') {
        displayText = _formatTechnicalSkills(descriptionData[fieldKey]);
      } else {
        displayText =
            (descriptionData[fieldKey] as List<dynamic>?)?.join("\n") ?? "";
      }
    }

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
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: fillColor ?? Colors.white,
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: appTheme.colorScheme.primary, size: 20),
                SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: appTheme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              displayText.isEmpty ? "Not specified" : displayText,
              style: TextStyle(
                fontSize: 16,
                color: Colors.black87,
                height: 1.5,
              ),
            ),
          ],
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
            'Job Details',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          elevation: 0,
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
        body: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Basic Information Section
              _buildSectionHeader("Basic Information"),
              ...basicInfoFields.map(_buildDisplayField).toList(),

              // Job Description Section
              _buildSectionHeader("Job Description"),
              ...descriptionFields.map(_buildDisplayField).toList(),
            ],
          ),
        ),
      ),
    );
  }
}
