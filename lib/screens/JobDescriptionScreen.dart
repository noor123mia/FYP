import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

final appTheme = ThemeData(
  primaryColor: Color(0xFF1E3A8A),
  primaryColorLight: Color(0xFF3151A6),
  secondaryHeaderColor: Color(0xFF0D9488),
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
  ),
);

class JobDescriptionScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Theme(
      data: appTheme,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Job Description Builder'),
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFEEF2FF),
                Color(0xFFF9FAFB),
              ],
            ),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(17.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Create a Job Description',
                    style: appTheme.textTheme.headlineLarge,
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Choose an option to create your job description',
                    style: appTheme.textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 40),
                  _buildOptionCard(
                    context,
                    'Use a Template',
                    'Use our pre-defined job templates to create a job description quickly.',
                    Icons.description,
                    Color(0xFF1E3A8A),
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => JobTemplateScreen(),
                        ),
                      );
                    },
                  ),
                  SizedBox(height: 24),
                  _buildOptionCard(
                    context,
                    'Build Using AI',
                    'Create a custom job description by AI Optimization',
                    Icons.edit_document,
                    Color(0xFF0D9488),
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => JobAIScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionCard(
    BuildContext context,
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Color(0xFFF1F5F9),
              ],
            ),
          ),
          padding: const EdgeInsets.all(18.0),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 55,
                ),
              ),
              SizedBox(height: 16),
              Text(
                title,
                style: appTheme.textTheme.titleLarge?.copyWith(color: color),
              ),
              SizedBox(height: 8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: appTheme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Template Selection Screen
class JobTemplateScreen extends StatefulWidget {
  @override
  _JobDescriptionScreenState createState() => _JobDescriptionScreenState();
}

class _JobDescriptionScreenState extends State<JobTemplateScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController companyNameController = TextEditingController();
  final TextEditingController departmentController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final TextEditingController jobTypeController = TextEditingController();
  final TextEditingController contractTypeController = TextEditingController();
  final TextEditingController salaryRangeController = TextEditingController();
  final TextEditingController lastDateController = TextEditingController();

  String? selectedJobTitle;
  Map<String, dynamic>? jobDescription;
  bool isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  List<String> jobTitles = [
    "Software Engineer",
    "Product Manager",
    "Data Scientist"
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void fetchJobDescription(String title) async {
    setState(() {
      isLoading = true;
      jobDescription = null;
    });

    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('job_descriptions')
          .where('title', isEqualTo: title)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        setState(() {
          jobDescription =
              querySnapshot.docs.first.data() as Map<String, dynamic>;
          _animationController.reset();
          _animationController.forward();
        });
      } else {
        setState(() {
          jobDescription = null;
        });
      }
    } catch (e) {
      print("Error fetching job description: $e");
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> selectLastDate(BuildContext context) async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Color(0xFF1E3A8A),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      setState(() {
        lastDateController.text =
            "${pickedDate.day}/${pickedDate.month}/${pickedDate.year}";
      });
    }
  }

  void saveJobDetails() {
    if (companyNameController.text.isEmpty ||
        departmentController.text.isEmpty ||
        locationController.text.isEmpty ||
        jobTypeController.text.isEmpty ||
        contractTypeController.text.isEmpty ||
        salaryRangeController.text.isEmpty ||
        lastDateController.text.isEmpty ||
        selectedJobTitle == null ||
        jobDescription == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 10),
              Text("All fields must be filled"),
            ],
          ),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }
    String recruiterId = FirebaseAuth.instance.currentUser!.uid;

    Map<String, dynamic> jobDetails = {
      "company_name": companyNameController.text,
      "department": departmentController.text,
      "location": locationController.text,
      "job_type": jobTypeController.text,
      "contract_type": contractTypeController.text,
      "salary_range": salaryRangeController.text,
      "last_date_to_apply": lastDateController.text,
      "title": selectedJobTitle,
      "description": jobDescription,
      "recruiterId": recruiterId,
    };

    FirebaseFirestore.instance.collection("JobsInDraft").add(jobDetails);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 10),
            Text("Job saved successfully"),
          ],
        ),
        backgroundColor: Color(0xFF0D9488),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: appTheme,
      child: Scaffold(
        appBar: AppBar(
          title: Text("Use Pre-defined Templates"),
          elevation: 0,
          centerTitle: true,
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFEEF2FF),
                Color(0xFFF9FAFB),
              ],
            ),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16.0),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header section
                    Center(
                      child: Text(
                        "Job Details",
                        style: appTheme.textTheme.headlineMedium?.copyWith(
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                    ),
                    Divider(height: 30, thickness: 1),
                    SizedBox(height: 10),

                    // Company info section
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Color(0xFF1E3A8A).withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.business,
                            color: Color(0xFF1E3A8A),
                          ),
                          SizedBox(width: 10),
                          Text(
                            "Company Information",
                            style: appTheme.textTheme.titleMedium?.copyWith(
                              color: Color(0xFF1E3A8A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),
                    buildTextField(
                        "Company Name", companyNameController, Icons.business),
                    SizedBox(height: 10),
                    buildTextField(
                        "Department", departmentController, Icons.category),
                    SizedBox(height: 10),
                    buildTextField(
                        "Location", locationController, Icons.location_on),
                    SizedBox(height: 20),

                    // Job details section
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Color(0xFF0D9488).withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.work,
                            color: Color(0xFF0D9488),
                          ),
                          SizedBox(width: 10),
                          Text(
                            "Job Information",
                            style: appTheme.textTheme.titleMedium?.copyWith(
                              color: Color(0xFF0D9488),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white,
                            Color(0xFFF1F5F9),
                          ],
                        ),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButtonFormField<String>(
                          value: selectedJobTitle,
                          decoration: InputDecoration(
                            hintText: "Select a Job Title",
                            border: InputBorder.none,
                            prefixIcon:
                                Icon(Icons.work, color: Color(0xFF1E3A8A)),
                          ),
                          items: jobTitles
                              .map((title) => DropdownMenuItem(
                                  value: title, child: Text(title)))
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedJobTitle = value;
                            });
                            if (value != null) {
                              fetchJobDescription(value);
                            }
                          },
                          icon: Icon(Icons.arrow_drop_down,
                              color: Color(0xFF1E3A8A)),
                        ),
                      ),
                    ),
                    SizedBox(height: 10),
                    buildTextField(
                        "Job Type", jobTypeController, Icons.assignment),
                    SizedBox(height: 10),
                    buildTextField("Contract Type", contractTypeController,
                        Icons.description),
                    SizedBox(height: 10),
                    buildTextField("Salary Range", salaryRangeController,
                        Icons.attach_money),
                    SizedBox(height: 10),

                    // Last date picker field
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white,
                            Color(0xFFF1F5F9),
                          ],
                        ),
                      ),
                      child: TextField(
                        controller: lastDateController,
                        decoration: InputDecoration(
                          labelText: "Last Date to Apply",
                          prefixIcon: Icon(Icons.calendar_today,
                              color: Color(0xFF1E3A8A)),
                          suffixIcon: IconButton(
                            icon: Icon(Icons.date_range,
                                color: Color(0xFF1E3A8A)),
                            onPressed: () => selectLastDate(context),
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                        ),
                        readOnly: true,
                      ),
                    ),
                    SizedBox(height: 20),

                    // Job Description Content
                    if (isLoading)
                      Center(
                        child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Color(0xFF1E3A8A)),
                        ),
                      )
                    else if (jobDescription != null)
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFFEEF2FF),
                                Color(0xFFF9FAFB),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                spreadRadius: 1,
                                blurRadius: 5,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.symmetric(
                                    vertical: 12, horizontal: 16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(0xFF1E3A8A),
                                      Color(0xFF3151A6),
                                    ],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  "Job Description Preview",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              SizedBox(height: 16),
                              buildDescriptionSection(
                                "Position Summary",
                                jobDescription!["position_summary"],
                                Icons.info_outline,
                                Color(0xFF1E3A8A),
                              ),
                              buildDescriptionSection(
                                "Responsibilities",
                                jobDescription!["responsibilities"],
                                Icons.assignment_turned_in,
                                Color(0xFF0D9488),
                              ),
                              buildDescriptionSection(
                                "Required Skills",
                                jobDescription!["required_skills"],
                                Icons.check_circle_outline,
                                Color(0xFF047857),
                              ),
                              buildDescriptionSection(
                                "Technical Skills",
                                jobDescription!["technical_skills"],
                                Icons.computer,
                                Color(0xFF4F46E5),
                              ),
                              buildDescriptionSection(
                                "Preferred Skills",
                                jobDescription!["preferred_skills"],
                                Icons.star_outline,
                                Color(0xFFB91C1C),
                              ),
                              buildDescriptionSection(
                                "What We Offer",
                                jobDescription!["what_we_offer"],
                                Icons.card_giftcard,
                                Color(0xFFD97706),
                              ),
                            ],
                          ),
                        ),
                      ),
                    SizedBox(height: 24),

                    // Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ElevatedButton.icon(
                          icon: Icon(Icons.arrow_back),
                          label: Text("Back"),
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade200,
                            foregroundColor: Colors.black87,
                            padding: EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        ElevatedButton.icon(
                          icon: Icon(Icons.save),
                          label: Text("Save Job"),
                          onPressed: saveJobDetails,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF1E3A8A),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
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
          ),
        ),
      ),
    );
  }

  Widget buildTextField(
      String label, TextEditingController controller, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Color(0xFFF1F5F9),
          ],
        ),
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Color(0xFF6B7280)),
          prefixIcon: Icon(icon, color: Color(0xFF1E3A8A)),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  Widget buildDescriptionSection(
      String title, dynamic content, IconData icon, Color color) {
    if (content == null) return SizedBox.shrink();

    return Container(
      margin: EdgeInsets.symmetric(vertical: 12.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: color),
                SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: content is List
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: content.map<Widget>((item) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.check, size: 12, color: color),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                item,
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.5,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  )
                : Text(
                    content.toString(),
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Color(0xFF1F2937),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
/*
class JobAIScreen extends StatefulWidget {
  @override
  _JobAIScreenState createState() => _JobAIScreenState();
}

class _JobAIScreenState extends State<JobAIScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController companyNameController = TextEditingController();
  final TextEditingController departmentController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final TextEditingController jobTypeController = TextEditingController();
  final TextEditingController contractTypeController = TextEditingController();
  final TextEditingController salaryRangeController = TextEditingController();
  final TextEditingController lastDateController = TextEditingController();
  final TextEditingController aiGeneratedDescriptionController =
      TextEditingController();

  String? selectedJobTitle;
  bool isLoading = false;
  bool isDescriptionGenerated = false;

  // Backend API URL
  //final String backendApiUrl = dotenv.env['AI_JOB_D'] ?? '';
  final String backendApiUrl = "http://localhost:8000";

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  List<String> jobTitles = [
    "Software Engineer",
    "Product Manager",
    "UX Designer",
    "Data Scientist",
    "Marketing Specialist"
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 600),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _slideAnimation =
        Tween<Offset>(begin: Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutQuint),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> generateJobDescription() async {
    if (selectedJobTitle == null ||
        companyNameController.text.isEmpty ||
        departmentController.text.isEmpty ||
        locationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(width: 10),
              Text("Please fill required fields"),
            ],
          ),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
      aiGeneratedDescriptionController.clear();
    });

    try {
      // Prepare data to send to backend
      Map<String, dynamic> jobData = {
        "job_title": selectedJobTitle,
        "company_name": companyNameController.text,
        "department": departmentController.text,
        "location": locationController.text,
        "job_type": jobTypeController.text,
        "contract_type": contractTypeController.text,
        "salary_range": salaryRangeController.text,
        "last_date": lastDateController.text,
      };

      // Call backend API
      var response = await http.post(
        Uri.parse(backendApiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(jobData),
      );

      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(response.body);
        String generatedDescription = jsonResponse["description"];

        setState(() {
          aiGeneratedDescriptionController.text = generatedDescription;
          isDescriptionGenerated = true;
          _animationController.reset();
          _animationController.forward();
        });
      } else {
        throw Exception("Failed to generate job description: ${response.body}");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    setState(() {
      isLoading = false;
    });
  }

  void saveJobDetails() async {
    if (companyNameController.text.isEmpty ||
        departmentController.text.isEmpty ||
        locationController.text.isEmpty ||
        jobTypeController.text.isEmpty ||
        contractTypeController.text.isEmpty ||
        salaryRangeController.text.isEmpty ||
        lastDateController.text.isEmpty ||
        selectedJobTitle == null ||
        aiGeneratedDescriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 10),
              Text("All fields must be filled"),
            ],
          ),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }
    String recruiterId = FirebaseAuth.instance.currentUser!.uid;
    Map<String, dynamic> jobDetails = {
      "company_name": companyNameController.text,
      "department": departmentController.text,
      "location": locationController.text,
      "job_type": jobTypeController.text,
      "contract_type": contractTypeController.text,
      "salary_range": salaryRangeController.text,
      "last_date_to_apply": lastDateController.text,
      "title": selectedJobTitle,
      "description": aiGeneratedDescriptionController.text,
      "recruiterId": recruiterId,
    };

    setState(() {
      isLoading = true;
    });

    try {
      // Check if the job exists in Firestore before adding/updating
      var jobQuery = await FirebaseFirestore.instance
          .collection("JobsInDraft")
          .where("title", isEqualTo: selectedJobTitle)
          .where("company_name", isEqualTo: companyNameController.text)
          .get();

      if (jobQuery.docs.isNotEmpty) {
        // Update existing job
        String jobId = jobQuery.docs.first.id;
        await FirebaseFirestore.instance
            .collection("JobsInDraft")
            .doc(jobId)
            .update(jobDetails);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 10),
                Text("Job updated successfully"),
              ],
            ),
            backgroundColor: Color(0xFF0D9488),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } else {
        // Save as a new job
        await FirebaseFirestore.instance
            .collection("JobsInDraft")
            .add(jobDetails);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 10),
                Text("Job saved successfully"),
              ],
            ),
            backgroundColor: Color(0xFF0D9488),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error saving job: $e"),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> selectDate(BuildContext context) async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Color(0xFF1E3A8A),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Color(0xFF1E3A8A),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      setState(() {
        lastDateController.text =
            "${pickedDate.day}/${pickedDate.month}/${pickedDate.year}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: appTheme,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            "AI Job Creator",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
          ),
          backgroundColor: Color(0xFF1E3A8A),
          elevation: 0,
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(Icons.lightbulb_outline),
              onPressed: () {
                // Show tips or help dialog
              },
            ),
          ],
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFE6EFFE), Color(0xFFF9FAFB)],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // AI Header Banner with updated colors
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF1E3A8A), Color(0xFF3151A6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFF1E3A8A).withOpacity(0.2),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.smart_toy,
                              color: Colors.white, size: 32),
                        ),
                        SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "AI-Powered Job Description",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              SizedBox(height: 5),
                              Text(
                                "Fill in details and let AI craft the perfect job description",
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 25),

                  // Main content card with updated styling
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Color(0xFF1E3A8A).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.work_outline,
                                    color: Color(0xFF1E3A8A), size: 24),
                              ),
                              SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Job Details",
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1F2937),
                                    ),
                                  ),
                                  Text(
                                    "Fill in the required information",
                                    style: TextStyle(
                                      color: Color(0xFF6B7280),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Divider(height: 25, color: Color(0xFFE5E7EB)),

                          // Two column layout for smaller fields
                          Wrap(
                            spacing: 15,
                            runSpacing: 15,
                            children: [
                              Container(
                                width: MediaQuery.of(context).size.width > 600
                                    ? (MediaQuery.of(context).size.width -
                                            100) /
                                        2
                                    : MediaQuery.of(context).size.width - 55,
                                child: buildTextField(
                                  "Company Name",
                                  companyNameController,
                                  Icons.business,
                                  required: true,
                                ),
                              ),
                              Container(
                                width: MediaQuery.of(context).size.width > 600
                                    ? (MediaQuery.of(context).size.width -
                                            100) /
                                        2
                                    : MediaQuery.of(context).size.width - 55,
                                child: buildTextField(
                                  "Department",
                                  departmentController,
                                  Icons.category,
                                  required: true,
                                ),
                              ),
                              Container(
                                width: MediaQuery.of(context).size.width > 600
                                    ? (MediaQuery.of(context).size.width -
                                            100) /
                                        2
                                    : MediaQuery.of(context).size.width - 55,
                                child: buildTextField(
                                  "Location",
                                  locationController,
                                  Icons.location_on,
                                  required: true,
                                ),
                              ),
                              Container(
                                width: MediaQuery.of(context).size.width > 600
                                    ? (MediaQuery.of(context).size.width -
                                            100) /
                                        2
                                    : MediaQuery.of(context).size.width - 55,
                                child: buildTextField(
                                  "Job Type",
                                  jobTypeController,
                                  Icons.work,
                                ),
                              ),
                              Container(
                                width: MediaQuery.of(context).size.width > 600
                                    ? (MediaQuery.of(context).size.width -
                                            100) /
                                        2
                                    : MediaQuery.of(context).size.width - 55,
                                child: buildTextField(
                                  "Contract Type",
                                  contractTypeController,
                                  Icons.description,
                                ),
                              ),
                              Container(
                                width: MediaQuery.of(context).size.width > 600
                                    ? (MediaQuery.of(context).size.width -
                                            100) /
                                        2
                                    : MediaQuery.of(context).size.width - 55,
                                child: buildTextField(
                                  "Salary Range",
                                  salaryRangeController,
                                  Icons.monetization_on,
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: 15),

                          // Date picker field
                          GestureDetector(
                            onTap: () => selectDate(context),
                            child: AbsorbPointer(
                              child: buildTextField(
                                "Last Date to Apply",
                                lastDateController,
                                Icons.calendar_today,
                                suffix: Icon(Icons.arrow_drop_down,
                                    color: Color(0xFF1E3A8A)),
                              ),
                            ),
                          ),

                          SizedBox(height: 15),

                          // Job title dropdown with updated styling
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.white,
                              border: Border.all(color: Color(0xFFE5E7EB)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 5,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButtonFormField<String>(
                                value: selectedJobTitle,
                                decoration: InputDecoration(
                                  prefixIcon: Icon(Icons.work_outline,
                                      color: Color(0xFF1E3A8A)),
                                  labelText: "Select Job Title",
                                  labelStyle:
                                      TextStyle(color: Color(0xFF6B7280)),
                                  border: InputBorder.none,
                                ),
                                items: jobTitles
                                    .map((title) => DropdownMenuItem(
                                        value: title, child: Text(title)))
                                    .toList(),
                                onChanged: (value) {
                                  setState(() {
                                    selectedJobTitle = value;
                                  });
                                },
                                icon: Icon(Icons.arrow_drop_down,
                                    color: Color(0xFF1E3A8A)),
                                isExpanded: true,
                              ),
                            ),
                          ),

                          SizedBox(height: 25),

                          // AI Generation button with updated styling
                          Center(
                            child: isLoading
                                ? CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Color(0xFF1E3A8A)),
                                  )
                                : Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(30),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Color(0xFF1E3A8A)
                                              .withOpacity(0.3),
                                          blurRadius: 10,
                                          offset: Offset(0, 4),
                                          spreadRadius: -2,
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton.icon(
                                      icon: Icon(Icons.auto_awesome),
                                      label: Text("Generate with AI"),
                                      onPressed: generateJobDescription,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Color(0xFF1E3A8A),
                                        foregroundColor: Colors.white,
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 24, vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(30),
                                        ),
                                        elevation: 0,
                                      ),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 20),

                  // AI Generated Description Card with updated styling
                  if (isDescriptionGenerated)
                    SlideTransition(
                      position: _slideAnimation,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color:
                                            Color(0xFF0D9488).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(Icons.description,
                                          color: Color(0xFF0D9488), size: 24),
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      "AI-Generated Description",
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1F2937),
                                      ),
                                    ),
                                  ],
                                ),
                                Divider(height: 25, color: Color(0xFFE5E7EB)),
                                Container(
                                  padding: EdgeInsets.all(15),
                                  decoration: BoxDecoration(
                                    color: Color(0xFFF9FAFB),
                                    borderRadius: BorderRadius.circular(12),
                                    border:
                                        Border.all(color: Color(0xFFE5E7EB)),
                                  ),
                                  child: TextField(
                                    controller:
                                        aiGeneratedDescriptionController,
                                    maxLines: 15,
                                    decoration: InputDecoration(
                                      hintText:
                                          "AI will generate the job description here...",
                                      border: InputBorder.none,
                                      hintStyle:
                                          TextStyle(color: Color(0xFF9CA3AF)),
                                    ),
                                    style: TextStyle(
                                      fontSize: 14,
                                      height: 1.5,
                                      color: Color(0xFF1F2937),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  SizedBox(height: 25),

                  // Action buttons with updated styling
                  isDescriptionGenerated
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            ElevatedButton.icon(
                              icon: Icon(Icons.arrow_back),
                              label: Text("Back"),
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Color(0xFF1F2937),
                                padding: EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                elevation: 0,
                                side: BorderSide(color: Color(0xFFE5E7EB)),
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0xFF0D9488).withOpacity(0.3),
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                    spreadRadius: -2,
                                  ),
                                ],
                              ),
                              child: ElevatedButton.icon(
                                icon: Icon(Icons.save),
                                label: Text("Save Job"),
                                onPressed: saveJobDetails,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF0D9488),
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ],
                        )
                      : Center(
                          child: ElevatedButton.icon(
                            icon: Icon(Icons.arrow_back),
                            label: Text("Back"),
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Color(0xFF1F2937),
                              padding: EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              elevation: 0,
                              side: BorderSide(color: Color(0xFFE5E7EB)),
                            ),
                          ),
                        ),

                  SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildTextField(
      String label, TextEditingController controller, IconData icon,
      {bool required = false, Widget? suffix}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        border: Border.all(color: Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: required ? "$label *" : label,
          labelStyle: TextStyle(color: Color(0xFF6B7280)),
          prefixIcon: Icon(icon, color: Color(0xFF1E3A8A)),
          suffixIcon: suffix,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        ),
        style: TextStyle(color: Color(0xFF1F2937)),
      ),
    );
  }
}
*/

class JobAIScreen extends StatefulWidget {
  @override
  _JobAIScreenState createState() => _JobAIScreenState();
}

class _JobAIScreenState extends State<JobAIScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController companyNameController = TextEditingController();
  final TextEditingController departmentController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final TextEditingController jobTypeController = TextEditingController();
  final TextEditingController contractTypeController = TextEditingController();
  final TextEditingController salaryRangeController = TextEditingController();
  final TextEditingController lastDateController = TextEditingController();
  final TextEditingController jobTitleController = TextEditingController();
  final TextEditingController aiGeneratedDescriptionController =
      TextEditingController();

  bool isLoading = false;
  bool isDescriptionGenerated = false;
  final String togetherAIKey =
      "tgp_v1_FS-KODkfQrqoo1I6REkwf6X3ew1zYrDuW6kOzqhTKyA";

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 600),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _slideAnimation =
        Tween<Offset>(begin: Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutQuint),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    companyNameController.dispose();
    departmentController.dispose();
    locationController.dispose();
    jobTypeController.dispose();
    contractTypeController.dispose();
    salaryRangeController.dispose();
    lastDateController.dispose();
    jobTitleController.dispose();
    aiGeneratedDescriptionController.dispose();
    super.dispose();
  }

  Future<void> generateJobDescription() async {
    if (jobTitleController.text.trim().isEmpty ||
        companyNameController.text.trim().isEmpty ||
        departmentController.text.trim().isEmpty ||
        locationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(width: 10),
              Text("Please fill required fields"),
            ],
          ),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
      aiGeneratedDescriptionController.clear();
    });

    String prompt = """
Generate a professional job description for the role of ${jobTitleController.text.trim()} in valid JSON format.

Generate the JSON object directly with the following keys at the top level of the object, without any additional wrapper like "description":

{
  "position_summary": "A detailed summary of the position...",
  "responsibilities": [
    "Key responsibility 1",
    "Key responsibility 2",
    "Key responsibility 3",
    "Key responsibility 4"
  ],
  "required_skills": [
    "Required skill 1",
    "Required skill 2",
    "Required skill 3"
  ],
  "preferred_skills": [
    "Preferred skill 1",
    "Preferred skill 2"
  ],
  "technical_skills": {
    "Programming Languages": ["Language 1", "Language 2"],
    "Frontend": ["Tech 1", "Tech 2"],
    "Backend": ["Tech 1", "Tech 2"],
    "Databases": ["DB 1", "DB 2"]
  },
  "what_we_offer": [
    "Benefit 1",
    "Benefit 2",
    "Benefit 3"
  ]
}

Please ensure:
- Output directly the nested map with these exact keys, no outer "description" or other wrappers.
- Do not escape or stringify the JSON.
- Include relevant, realistic content for a ${jobTitleController.text.trim()} role.
- The output must be valid, indented, and directly parsable JSON.
""";

    try {
      final String apiUrl = "https://api.together.xyz/v1/chat/completions";

      var response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          "Authorization": "Bearer $togetherAIKey",
          "Content-Type": "application/json"
        },
        body: jsonEncode({
          "model": "meta-llama/Llama-3.3-70B-Instruct-Turbo-Free",
          "messages": [
            {
              "role": "system",
              "content":
                  "You are an expert job description writer. Always output well-formatted, structured JSON for job descriptions with proper indentation and spacing. Output the JSON directly without any wrappers."
            },
            {"role": "user", "content": prompt}
          ],
          "max_tokens": 1000,
          "temperature": 0.7
        }),
      );

      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(response.body);
        String generatedContent =
            jsonResponse["choices"][0]["message"]["content"];

        // Extract just the JSON part
        RegExp jsonRegex = RegExp(r'{[\s\S]*}');
        Match? match = jsonRegex.firstMatch(generatedContent);

        if (match != null) {
          String jsonStr = match.group(0)!;
          var parsedJson = jsonDecode(jsonStr);
          var prettyJson = JsonEncoder.withIndent('  ').convert(parsedJson);

          setState(() {
            aiGeneratedDescriptionController.text = prettyJson;
            isDescriptionGenerated = true;
            _animationController.reset();
            _animationController.forward();
          });
        } else {
          setState(() {
            aiGeneratedDescriptionController.text = generatedContent;
            isDescriptionGenerated = true;
            _animationController.reset();
            _animationController.forward();
          });
        }
      } else {
        throw Exception("Failed to generate job description: ${response.body}");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    setState(() {
      isLoading = false;
    });
  }

  void saveJobDetails() async {
    if (jobTitleController.text.trim().isEmpty ||
        companyNameController.text.trim().isEmpty ||
        departmentController.text.trim().isEmpty ||
        locationController.text.trim().isEmpty ||
        jobTypeController.text.trim().isEmpty ||
        contractTypeController.text.trim().isEmpty ||
        salaryRangeController.text.trim().isEmpty ||
        lastDateController.text.trim().isEmpty ||
        aiGeneratedDescriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 10),
              Text("All fields must be filled"),
            ],
          ),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    // Parse the AI-generated JSON description
    Map<String, dynamic> descriptionContent;
    try {
      descriptionContent =
          jsonDecode(aiGeneratedDescriptionController.text.trim());
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 10),
              Text("Invalid JSON in description. Please regenerate."),
            ],
          ),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    // Handle possible extra "description" wrapper
    if (descriptionContent.containsKey('description')) {
      descriptionContent =
          descriptionContent['description'] as Map<String, dynamic>;
    }

    // Validate required fields in description
    if (!descriptionContent.containsKey('position_summary') ||
        !descriptionContent.containsKey('responsibilities') ||
        !descriptionContent.containsKey('required_skills') ||
        !descriptionContent.containsKey('preferred_skills') ||
        !descriptionContent.containsKey('technical_skills') ||
        !descriptionContent.containsKey('what_we_offer')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 10),
              Text(
                  "Generated description missing required fields. Please regenerate."),
            ],
          ),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    // Parse last_date_to_apply to Timestamp
    Timestamp? lastDateTimestamp;
    try {
      String dateStr = lastDateController.text.trim();
      List<String> parts = dateStr.split('/');
      if (parts.length != 3) {
        throw Exception("Invalid date format");
      }
      int day = int.parse(parts[0]);
      int month = int.parse(parts[1]);
      int year = int.parse(parts[2]);
      DateTime applyDate = DateTime(year, month, day);
      lastDateTimestamp = Timestamp.fromDate(applyDate);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 10),
              Text("Invalid date format. Please select a valid date."),
            ],
          ),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    String recruiterId = FirebaseAuth.instance.currentUser!.uid;
    Map<String, dynamic> jobDetails = {
      "company_name": companyNameController.text.trim(),
      "department": departmentController.text.trim(),
      "location": locationController.text.trim(),
      "job_type": jobTypeController.text.trim(),
      "contract_type": contractTypeController.text.trim(),
      "salary_range": salaryRangeController.text.trim(),
      "last_date_to_apply": lastDateTimestamp,
      "title": jobTitleController.text.trim(),
      "description": descriptionContent,
      "recruiterId": recruiterId,
      "posted_on": FieldValue.serverTimestamp(),
    };

    setState(() {
      isLoading = true;
    });

    try {
      var jobQuery = await FirebaseFirestore.instance
          .collection("JobsInDraft")
          .where("title", isEqualTo: jobTitleController.text.trim())
          .where("company_name", isEqualTo: companyNameController.text.trim())
          .get();

      if (jobQuery.docs.isNotEmpty) {
        String jobId = jobQuery.docs.first.id;
        await FirebaseFirestore.instance
            .collection("JobsInDraft")
            .doc(jobId)
            .update(jobDetails);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 10),
                Text("Job updated successfully"),
              ],
            ),
            backgroundColor: Color(0xFF0D9488),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } else {
        await FirebaseFirestore.instance
            .collection("JobsInDraft")
            .add(jobDetails);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 10),
                Text("Job saved successfully"),
              ],
            ),
            backgroundColor: Color(0xFF0D9488),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error saving job: $e"),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> selectDate(BuildContext context) async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Color(0xFF1E3A8A),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Color(0xFF1E3A8A),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      setState(() {
        lastDateController.text =
            "${pickedDate.day}/${pickedDate.month}/${pickedDate.year}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: appTheme,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            "AI Job Description Creator",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
          ),
          backgroundColor: Color(0xFF1E3A8A),
          elevation: 0,
          centerTitle: true,
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFE6EFFE), Color(0xFFF9FAFB)],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // AI Header Banner
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF1E3A8A), Color(0xFF3151A6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFF1E3A8A).withOpacity(0.2),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.smart_toy,
                              color: Colors.white, size: 32),
                        ),
                        SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "AI-Powered Job Description",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              SizedBox(height: 5),
                              Text(
                                "Fill in details and let AI craft the perfect job description",
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 25),

                  // Main content card
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Color(0xFF1E3A8A).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.work_outline,
                                    color: Color(0xFF1E3A8A), size: 24),
                              ),
                              SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Job Details",
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1F2937),
                                    ),
                                  ),
                                  Text(
                                    "Fill in the required information",
                                    style: TextStyle(
                                      color: Color(0xFF6B7280),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Divider(height: 25, color: Color(0xFFE5E7EB)),

                          // Two column layout for fields
                          Wrap(
                            spacing: 15,
                            runSpacing: 15,
                            children: [
                              Container(
                                width: MediaQuery.of(context).size.width > 600
                                    ? (MediaQuery.of(context).size.width -
                                            100) /
                                        2
                                    : MediaQuery.of(context).size.width - 55,
                                child: buildTextField(
                                  "Job Title",
                                  jobTitleController,
                                  Icons.work_outline,
                                  required: true,
                                ),
                              ),
                              Container(
                                width: MediaQuery.of(context).size.width > 600
                                    ? (MediaQuery.of(context).size.width -
                                            100) /
                                        2
                                    : MediaQuery.of(context).size.width - 55,
                                child: buildTextField(
                                  "Company Name",
                                  companyNameController,
                                  Icons.business,
                                  required: true,
                                ),
                              ),
                              Container(
                                width: MediaQuery.of(context).size.width > 600
                                    ? (MediaQuery.of(context).size.width -
                                            100) /
                                        2
                                    : MediaQuery.of(context).size.width - 55,
                                child: buildTextField(
                                  "Department",
                                  departmentController,
                                  Icons.category,
                                  required: true,
                                ),
                              ),
                              Container(
                                width: MediaQuery.of(context).size.width > 600
                                    ? (MediaQuery.of(context).size.width -
                                            100) /
                                        2
                                    : MediaQuery.of(context).size.width - 55,
                                child: buildTextField(
                                  "Location",
                                  locationController,
                                  Icons.location_on,
                                  required: true,
                                ),
                              ),
                              Container(
                                width: MediaQuery.of(context).size.width > 600
                                    ? (MediaQuery.of(context).size.width -
                                            100) /
                                        2
                                    : MediaQuery.of(context).size.width - 55,
                                child: buildTextField(
                                  "Job Type",
                                  jobTypeController,
                                  Icons.work,
                                ),
                              ),
                              Container(
                                width: MediaQuery.of(context).size.width > 600
                                    ? (MediaQuery.of(context).size.width -
                                            100) /
                                        2
                                    : MediaQuery.of(context).size.width - 55,
                                child: buildTextField(
                                  "Contract Type",
                                  contractTypeController,
                                  Icons.description,
                                ),
                              ),
                              Container(
                                width: MediaQuery.of(context).size.width > 600
                                    ? (MediaQuery.of(context).size.width -
                                            100) /
                                        2
                                    : MediaQuery.of(context).size.width - 55,
                                child: buildTextField(
                                  "Salary Range",
                                  salaryRangeController,
                                  Icons.monetization_on,
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: 15),

                          // Date picker field
                          GestureDetector(
                            onTap: () => selectDate(context),
                            child: AbsorbPointer(
                              child: buildTextField(
                                "Last Date to Apply",
                                lastDateController,
                                Icons.calendar_today,
                                suffix: Icon(Icons.arrow_drop_down,
                                    color: Color(0xFF1E3A8A)),
                              ),
                            ),
                          ),

                          SizedBox(height: 25),

                          // AI Generation button
                          Center(
                            child: isLoading
                                ? CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Color(0xFF1E3A8A)),
                                  )
                                : Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(30),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Color(0xFF1E3A8A)
                                              .withOpacity(0.3),
                                          blurRadius: 10,
                                          offset: Offset(0, 4),
                                          spreadRadius: -2,
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton.icon(
                                      icon: Icon(Icons.auto_awesome),
                                      label: Text("Generate with AI"),
                                      onPressed: generateJobDescription,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Color(0xFF1E3A8A),
                                        foregroundColor: Colors.white,
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 24, vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(30),
                                        ),
                                        elevation: 0,
                                      ),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 20),

                  // AI Generated Description Card
                  if (isDescriptionGenerated)
                    SlideTransition(
                      position: _slideAnimation,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color:
                                            Color(0xFF0D9488).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(Icons.description,
                                          color: Color(0xFF0D9488), size: 24),
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      "AI-Generated Description",
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1F2937),
                                      ),
                                    ),
                                  ],
                                ),
                                Divider(height: 25, color: Color(0xFFE5E7EB)),
                                Container(
                                  padding: EdgeInsets.all(15),
                                  decoration: BoxDecoration(
                                    color: Color(0xFFF9FAFB),
                                    borderRadius: BorderRadius.circular(12),
                                    border:
                                        Border.all(color: Color(0xFFE5E7EB)),
                                  ),
                                  child: TextField(
                                    controller:
                                        aiGeneratedDescriptionController,
                                    maxLines: 15,
                                    decoration: InputDecoration(
                                      hintText:
                                          "AI will generate the job description here...",
                                      border: InputBorder.none,
                                      hintStyle:
                                          TextStyle(color: Color(0xFF9CA3AF)),
                                    ),
                                    style: TextStyle(
                                      fontSize: 14,
                                      height: 1.5,
                                      color: Color(0xFF1F2937),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  SizedBox(height: 25),

                  // Action buttons
                  isDescriptionGenerated
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            ElevatedButton.icon(
                              icon: Icon(Icons.arrow_back),
                              label: Text("Back"),
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Color(0xFF1F2937),
                                padding: EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                elevation: 0,
                                side: BorderSide(color: Color(0xFFE5E7EB)),
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0xFF0D9488).withOpacity(0.3),
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                    spreadRadius: -2,
                                  ),
                                ],
                              ),
                              child: ElevatedButton.icon(
                                icon: Icon(Icons.save),
                                label: Text("Save Job"),
                                onPressed: saveJobDetails,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF0D9488),
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ],
                        )
                      : Center(
                          child: ElevatedButton.icon(
                            icon: Icon(Icons.arrow_back),
                            label: Text("Back"),
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Color(0xFF1F2937),
                              padding: EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              elevation: 0,
                              side: BorderSide(color: Color(0xFFE5E7EB)),
                            ),
                          ),
                        ),

                  SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildTextField(
      String label, TextEditingController controller, IconData icon,
      {bool required = false, Widget? suffix}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        border: Border.all(color: Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: required ? "$label *" : label,
          labelStyle: TextStyle(color: Color(0xFF6B7280)),
          prefixIcon: Icon(icon, color: Color(0xFF1E3A8A)),
          suffixIcon: suffix,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        ),
        style: TextStyle(color: Color(0xFF1F2937)),
      ),
    );
  }
}
