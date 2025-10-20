import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;

class AIInterviewQuestionsScreen extends StatefulWidget {
  @override
  _AIInterviewQuestionsScreenState createState() =>
      _AIInterviewQuestionsScreenState();
}

class _AIInterviewQuestionsScreenState extends State<AIInterviewQuestionsScreen>
    with TickerProviderStateMixin {
  Map<String, dynamic>? selectedJob;
  String? selectedJobId;
  List<InterviewQuestion> generatedQuestions = [];
  bool isGenerating = false;
  bool isJobsLoading = true;
  String selectedCategory = 'All';
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  // Professional Color Scheme
  static const Color _primaryBlue = Color(0xFF0066FF);
  static const Color _primaryDark = Color(0xFF003D99);
  static const Color _surfaceColor = Color(0xFFFAFBFC);
  static const Color _cardColor = Color(0xFFFFFFFF);
  static const Color _textPrimary = Color(0xFF1A1D29);
  static const Color _textSecondary = Color(0xFF6B7385);
  static const Color _textTertiary = Color(0xFF9CA3B2);
  static const Color _borderColor = Color(0xFFE5E8EC);
  static const Color _accentGreen = Color(0xFF00C851);
  static const Color _accentOrange = Color(0xFFFF8A00);
  static const Color _accentRed = Color(0xFFFF4757);

  // TogetherAI API configuration
  final String apiUrl = "https://api.together.xyz/v1/chat/completions";
  final String apiKey = "tgp_v1_FS-KODkfQrqoo1I6REkwf6X3ew1zYrDuW6kOzqhTKyA";

  final List<String> questionCategories = [
    'All',
    'Technical',
    'Behavioral',
    'Cultural Fit',
    'Leadership',
    'Problem Solving'
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _animationController.forward();
    setState(() {
      isJobsLoading = false;
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _generateQuestionsWithAI() async {
    if (selectedJob == null) {
      _showErrorDialog("Please select a job posting first.");
      return;
    }

    setState(() {
      isGenerating = true;
      generatedQuestions.clear();
    });

    try {
      final prompt = _createPrompt();
      final response = await _callTogetherAPI(prompt, retries: 3);

      if (response != null) {
        final questions = _parseQuestionsFromResponse(response);
        if (questions.isEmpty) {
          _showErrorDialog(
              "No valid questions could be generated. Please try again.");
        } else {
          setState(() {
            generatedQuestions = questions;
          });
          _showSuccessMessage();
        }
      } else {
        _showErrorDialog(
            "Failed to generate questions. Please check your network and try again.");
      }
    } catch (e) {
      _showErrorDialog("An error occurred: $e. Please try again later.");
    } finally {
      setState(() {
        isGenerating = false;
      });
    }
  }

  String _createPrompt() {
    final job = selectedJob!;
    return """
Generate 12 comprehensive interview questions for the following job position. 
Include a mix of Technical (4), Behavioral (3), Cultural Fit (2), Leadership (2), and Problem Solving (1) questions.

Job Details:
- Title: ${job['title'] ?? 'Not specified'}
- Company: ${job['company_name'] ?? 'Not specified'}
- Location: ${job['location'] ?? 'Not specified'}
- Job Type: ${job['job_type'] ?? 'Not specified'}
- Contract Type: ${job['contract_type'] ?? 'Not specified'}
- Salary Range: ${job['salary_range'] ?? 'Not specified'}
- Job Description: ${job['job_description'] ?? 'Not specified'}
- Required Skills: ${job['required_skills'] ?? 'Not specified'}
- Experience Required: ${job['experience_required'] ?? 'Not specified'}

Base all questions directly on the job description (which includes responsibilities), required skills, and experience. Ensure each question assesses specific aspects from the job details, such as key responsibilities, technical skills mentioned, or behavioral traits implied by the role.

Please format each question as:
CATEGORY: [Technical/Behavioral/Cultural Fit/Leadership/Problem Solving]
DIFFICULTY: [Easy/Medium/Hard]
QUESTION: [The actual question]
PURPOSE: [Why this question is important for this role]
FOLLOW_UP: [2-3 follow-up questions separated by newlines]

Generate questions that are:
1. Role-specific and relevant to the job requirements, responsibilities, and skills
2. Progressive in difficulty within each category
3. Practical and realistic for actual interviews
4. Focused on assessing the candidate's fit for this specific position

Ensure the response is in plain text, with each question block separated by '---'.
""";
  }

  Future<String?> _callTogetherAPI(String prompt, {int retries = 3}) async {
    for (int attempt = 1; attempt <= retries; attempt++) {
      try {
        final response = await http.post(
          Uri.parse(apiUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: json.encode({
            'model': 'meta-llama/Llama-3.3-70B-Instruct-Turbo-Free',
            'messages': [
              {'role': 'user', 'content': prompt}
            ],
            'max_tokens': 2048,
            'temperature': 0.7,
            'top_p': 0.9,
            'repetition_penalty': 1.1,
            'stop': ['</s>'],
          }),
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['choices'] != null && data['choices'].isNotEmpty) {
            return data['choices'][0]['message']['content']?.toString();
          } else {
            print('API Error: Invalid response structure - $data');
            if (attempt == retries) return null;
            await Future.delayed(Duration(seconds: attempt));
          }
        } else {
          print('API Error: ${response.statusCode} - ${response.body}');
          if (attempt == retries) return null;
          await Future.delayed(Duration(seconds: attempt));
        }
      } catch (e) {
        print('Network Error (Attempt $attempt/$retries): $e');
        if (attempt == retries) return null;
        await Future.delayed(Duration(seconds: attempt));
      }
    }
    return null;
  }

  List<InterviewQuestion> _parseQuestionsFromResponse(String response) {
    List<InterviewQuestion> questions = [];

    try {
      final questionBlocks = response
          .split(RegExp(r'---+\n*'))
          .where((block) => block.trim().isNotEmpty)
          .toList();

      for (int i = 0; i < questionBlocks.length && i < 12; i++) {
        final block = questionBlocks[i].trim();
        if (block.isEmpty) continue;

        String category = _extractField(block, 'CATEGORY:') ?? 'General';
        String difficulty = _extractField(block, 'DIFFICULTY:') ?? 'Medium';
        String question = _extractField(block, 'QUESTION:') ?? '';
        String purpose = _extractField(block, 'PURPOSE:') ??
            'Assesses candidate qualifications';
        String followUpText = _extractField(block, 'FOLLOW_UP:') ?? '';

        List<String> followUpQuestions = followUpText.isNotEmpty
            ? followUpText
                .split('\n')
                .where((q) => q.trim().isNotEmpty)
                .map((q) => q.replaceAll(RegExp(r'^\d+\.\s*'), '').trim())
                .toList()
            : [];

        if (question.isNotEmpty) {
          questions.add(InterviewQuestion(
            id: 'q_$i',
            question: question,
            category: category,
            difficulty: difficulty,
            followUpQuestions: followUpQuestions,
            purpose: purpose,
          ));
        }
      }
    } catch (e) {
      print('Parsing Error: $e');
      _showErrorDialog(
          'Failed to parse questions. The response format may be incorrect.');
    }

    return questions;
  }

  String? _extractField(String block, String field) {
    try {
      final lines = block.split('\n');
      bool foundField = false;
      StringBuffer valueBuffer = StringBuffer();
      bool inValue = false;

      for (String line in lines) {
        line = line.trim();
        if (line.toUpperCase().startsWith(field.toUpperCase())) {
          final value = line.substring(field.length).trim();
          if (value.isNotEmpty) {
            valueBuffer.write(value);
            valueBuffer.write('\n');
          }
          foundField = true;
          inValue = true;
          continue;
        }

        if (foundField && inValue) {
          bool isNextField = false;
          for (String nextField in [
            'CATEGORY:',
            'DIFFICULTY:',
            'QUESTION:',
            'PURPOSE:',
            'FOLLOW_UP:'
          ]) {
            if (line.toUpperCase().startsWith(nextField.toUpperCase())) {
              isNextField = true;
              break;
            }
          }
          if (isNextField || line.isEmpty) {
            break;
          } else {
            valueBuffer.write(line);
            valueBuffer.write('\n');
          }
        }
      }

      String? result = valueBuffer.toString().trim();
      if (result.isEmpty) {
        print('No value found for field: $field');
        return null;
      }
      return result;
    } catch (e) {
      print('Field extraction error for $field: $e');
      return null;
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _accentRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(32),
              ),
              child: Icon(Icons.error_outline, color: _accentRed, size: 32),
            ),
            SizedBox(height: 20),
            Text('Oops!',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _textPrimary)),
            SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: _textSecondary)),
          ],
        ),
        actions: [
          Row(
            children: [
              if (message.contains('try again'))
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _generateQuestionsWithAI();
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Try Again',
                        style: TextStyle(
                            color: _primaryBlue, fontWeight: FontWeight.w600)),
                  ),
                ),
              if (message.contains('try again')) SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryBlue,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child:
                      Text('OK', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSuccessMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Text('Questions generated successfully!',
                style: TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
        backgroundColor: _accentGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.all(16),
      ),
    );
  }

  List<InterviewQuestion> get filteredQuestions {
    if (selectedCategory == 'All') {
      return generatedQuestions;
    }
    return generatedQuestions
        .where((q) => q.category == selectedCategory)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    String recruiterId = FirebaseAuth.instance.currentUser!.uid;

    return Theme(
      data: ThemeData(
        fontFamily: 'SF Pro Display',
        primaryColor: _primaryBlue,
        scaffoldBackgroundColor: _surfaceColor,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.dark,
          iconTheme: IconThemeData(color: _textPrimary),
          titleTextStyle: TextStyle(
            color: _textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
          ),
        ),
      ),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text('AI Interview Assistant'),
          centerTitle: false,
          actions: [
            IconButton(
              icon: Icon(Icons.more_vert),
              onPressed: () {},
            ),
          ],
        ),
        body: Stack(
          children: [
            // Background gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _primaryBlue.withOpacity(0.02),
                    _surfaceColor,
                  ],
                  stops: [0.0, 0.3],
                ),
              ),
            ),
            FadeTransition(
              opacity: _fadeAnimation,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: SizedBox(height: 100)),
                  SliverToBoxAdapter(child: _buildHeaderSection()),
                  SliverToBoxAdapter(child: SizedBox(height: 32)),
                  SliverToBoxAdapter(child: _buildJobSelection(recruiterId)),
                  if (selectedJob != null) ...[
                    SliverToBoxAdapter(child: SizedBox(height: 24)),
                    SliverToBoxAdapter(child: _buildSelectedJobInfo()),
                    SliverToBoxAdapter(child: SizedBox(height: 24)),
                    SliverToBoxAdapter(child: _buildGenerateButton()),
                    if (generatedQuestions.isNotEmpty) ...[
                      SliverToBoxAdapter(child: SizedBox(height: 32)),
                      SliverToBoxAdapter(child: _buildQuestionsHeader()),
                      SliverToBoxAdapter(child: SizedBox(height: 16)),
                      SliverToBoxAdapter(child: _buildCategoryFilter()),
                      SliverToBoxAdapter(child: SizedBox(height: 24)),
                      _buildQuestionsSliver(),
                    ],
                  ],
                  SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
            if (isGenerating) _buildGeneratingOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_primaryBlue, _primaryDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: _primaryBlue.withOpacity(0.2),
              blurRadius: 24,
              offset: Offset(0, 12),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.star_rounded, color: Colors.white, size: 28),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Smart Interview Prep',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -0.5,
                      height: 1.3,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'AI-crafted questions for your job role.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.85),
                      height: 1.4,
                      letterSpacing: -0.1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobSelection(String recruiterId) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Job Posting',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Choose a job posting to generate targeted interview questions',
            style: TextStyle(
              fontSize: 16,
              color: _textSecondary,
              letterSpacing: -0.2,
            ),
          ),
          SizedBox(height: 20),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('JobsPosted')
                .where('recruiterId', isEqualTo: recruiterId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildLoadingState();
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _buildEmptyState();
              }

              return Column(
                children: snapshot.data!.docs.map((doc) {
                  var job = doc.data() as Map<String, dynamic>;
                  var jobId = doc.id;
                  return _buildJobCard(job, jobId, selectedJobId == jobId);
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      padding: EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              // child: Icon(_primaryBlue, size: 24),
            ),
          ),
          SizedBox(height: 20),
          Text(
            'Loading job postings...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _textTertiary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(40),
            ),
            child:
                Icon(Icons.work_off_outlined, size: 40, color: _textTertiary),
          ),
          SizedBox(height: 24),
          Text(
            'No Job Postings Available',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _textPrimary,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Create job postings first to generate\ntailored interview questions',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: _textSecondary,
              height: 1.4,
            ),
          ),
          SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildJobCard(
      Map<String, dynamic> job, String jobId, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          if (selectedJobId == jobId) {
            selectedJob = null;
            selectedJobId = null;
          } else {
            selectedJob = job;
            selectedJobId = jobId;
          }
          generatedQuestions.clear();
        });
        HapticFeedback.mediumImpact();
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        margin: EdgeInsets.only(bottom: 16),
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isSelected ? _primaryBlue.withOpacity(0.05) : _cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? _primaryBlue : _borderColor,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? _primaryBlue.withOpacity(0.1)
                  : Colors.black.withOpacity(0.04),
              blurRadius: isSelected ? 24 : 16,
              offset: Offset(0, isSelected ? 12 : 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _primaryBlue.withOpacity(0.15)
                        : _textTertiary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.work_outline,
                    color: isSelected ? _primaryBlue : _textTertiary,
                    size: 24,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job['title'] ?? 'No Title',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _textPrimary,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Text(
                        job['company_name'] ?? 'Unknown Company',
                        style: TextStyle(
                          fontSize: 14,
                          color: _textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _primaryBlue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.check, color: Colors.white, size: 16),
                  ),
              ],
            ),
            SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _buildInfoChip(Icons.location_on_outlined,
                    job['location'] ?? 'Remote', Colors.blue),
                _buildInfoChip(Icons.schedule, job['job_type'] ?? 'Full-time',
                    Colors.green),
                if (job['salary_range'] != null &&
                    job['salary_range'].isNotEmpty)
                  _buildInfoChip(Icons.payments_outlined, job['salary_range'],
                      Colors.orange),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedJobInfo() {
    if (selectedJob == null) return SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _accentGreen.withOpacity(0.1),
              _accentGreen.withOpacity(0.05)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _accentGreen.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _accentGreen.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.check_circle_outline,
                  color: _accentGreen, size: 24),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selected Position',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _accentGreen,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    selectedJob!['title'] ?? 'No Title',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenerateButton() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: isGenerating ? null : _generateQuestionsWithAI,
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryBlue,
            foregroundColor: Colors.white,
            disabledBackgroundColor: _textTertiary.withOpacity(0.1),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
            shadowColor: Colors.transparent,
          ),
          child: AnimatedSwitcher(
            duration: Duration(milliseconds: 300),
            child: isGenerating
                ? Row(
                    key: ValueKey('generating'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      SizedBox(width: 16),
                      Text(
                        'Generating Questions...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  )
                : Row(
                    key: ValueKey('generate'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.auto_awesome, size: 20),
                      SizedBox(width: 12),
                      Text(
                        'Generate Interview Questions',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildGeneratingOverlay() {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      color: Colors.black.withOpacity(0.6),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
        child: Center(
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 40),
            padding: EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 32,
                  offset: Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_primaryBlue, _primaryDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(40),
                      boxShadow: [
                        BoxShadow(
                          color: _primaryBlue.withOpacity(0.3),
                          blurRadius: 24,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child:
                        Icon(Icons.psychology, color: Colors.white, size: 40),
                  ),
                ),
                SizedBox(height: 24),
                Text(
                  'Generating Questions',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'AI is analyzing your job posting to create\ntailored interview questions',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: _textSecondary,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 24),
                LinearProgressIndicator(
                  backgroundColor: _borderColor,
                  valueColor: AlwaysStoppedAnimation<Color>(_primaryBlue),
                  minHeight: 4,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionsHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Generated Questions',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '${filteredQuestions.length} intelligent questions ready',
                  style: TextStyle(
                    fontSize: 16,
                    color: _textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_accentGreen, _accentGreen.withOpacity(0.8)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 16),
                SizedBox(width: 6),
                Text(
                  '${generatedQuestions.length}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Container(
      height: 50,
      child: ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: questionCategories.length,
        itemBuilder: (context, index) {
          final category = questionCategories[index];
          final isSelected = selectedCategory == category;
          final count = category == 'All'
              ? generatedQuestions.length
              : generatedQuestions.where((q) => q.category == category).length;

          return GestureDetector(
            onTap: () {
              setState(() {
                selectedCategory = category;
              });
              HapticFeedback.lightImpact();
            },
            child: AnimatedContainer(
              duration: Duration(milliseconds: 300),
              margin: EdgeInsets.only(right: 12),
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? _primaryBlue : _cardColor,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: isSelected ? _primaryBlue : _borderColor,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isSelected
                        ? _primaryBlue.withOpacity(0.2)
                        : Colors.black.withOpacity(0.04),
                    blurRadius: isSelected ? 12 : 8,
                    offset: Offset(0, isSelected ? 6 : 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    category,
                    style: TextStyle(
                      color: isSelected ? Colors.white : _textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (count > 0) ...[
                    SizedBox(width: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withOpacity(0.2)
                            : _primaryBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        count.toString(),
                        style: TextStyle(
                          color: isSelected ? Colors.white : _primaryBlue,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuestionsSliver() {
    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            return AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                final slideAnimation = Tween<Offset>(
                  begin: Offset(0, 0.5),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: _animationController,
                  curve: Interval(
                    (index * 0.1).clamp(0.0, 1.0),
                    1.0,
                    curve: Curves.easeOutCubic,
                  ),
                ));

                return SlideTransition(
                  position: slideAnimation,
                  child: FadeTransition(
                    opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                      CurvedAnimation(
                        parent: _animationController,
                        curve: Interval(
                          (index * 0.1).clamp(0.0, 1.0),
                          1.0,
                        ),
                      ),
                    ),
                    child:
                        _buildQuestionCard(filteredQuestions[index], index + 1),
                  ),
                );
              },
            );
          },
          childCount: filteredQuestions.length,
        ),
      ),
    );
  }

  Widget _buildQuestionCard(InterviewQuestion question, int questionNumber) {
    return Container(
      margin: EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_primaryBlue, _primaryDark],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Q$questionNumber',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    _buildCategoryBadge(question.category),
                    SizedBox(width: 8),
                    _buildDifficultyBadge(question.difficulty),
                    Spacer(),
                    IconButton(
                      icon: Icon(Icons.content_copy_outlined,
                          color: _textTertiary, size: 20),
                      onPressed: () {
                        Clipboard.setData(
                            ClipboardData(text: question.question));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                Icon(Icons.check,
                                    color: Colors.white, size: 16),
                                SizedBox(width: 8),
                                Text('Copied to clipboard!'),
                              ],
                            ),
                            backgroundColor: _accentGreen,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            margin: EdgeInsets.all(16),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                SizedBox(height: 20),
                Text(
                  question.question,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: _textPrimary,
                    height: 1.4,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _primaryBlue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _primaryBlue.withOpacity(0.1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.lightbulb_outline,
                              color: _primaryBlue, size: 16),
                          SizedBox(width: 8),
                          Text(
                            'Purpose',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _primaryBlue,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        question.purpose,
                        style: TextStyle(
                          fontSize: 14,
                          color: _textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (question.followUpQuestions.isNotEmpty)
            Theme(
              data:
                  Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.symmetric(horizontal: 24),
                childrenPadding: EdgeInsets.fromLTRB(24, 0, 24, 24),
                title: Row(
                  children: [
                    Icon(Icons.quiz_outlined, color: _textSecondary, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Follow-up Questions (${question.followUpQuestions.length})',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _textSecondary,
                      ),
                    ),
                  ],
                ),
                children:
                    question.followUpQuestions.asMap().entries.map((entry) {
                  final index = entry.key;
                  final followUp = entry.value;
                  return Container(
                    margin: EdgeInsets.only(
                        bottom: index < question.followUpQuestions.length - 1
                            ? 12
                            : 0),
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _borderColor),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          margin: EdgeInsets.only(top: 6),
                          decoration: BoxDecoration(
                            color: _primaryBlue,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            followUp,
                            style: TextStyle(
                              fontSize: 14,
                              color: _textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryBadge(String category) {
    Color color;
    switch (category.toLowerCase()) {
      case 'technical':
        color = Colors.blue;
        break;
      case 'behavioral':
        color = Colors.purple;
        break;
      case 'cultural fit':
        color = Colors.orange;
        break;
      case 'leadership':
        color = Colors.red;
        break;
      case 'problem solving':
        color = Colors.green;
        break;
      default:
        color = _textTertiary;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        category,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildDifficultyBadge(String difficulty) {
    Color color = _getDifficultyColor(difficulty);
    IconData icon;

    switch (difficulty.toLowerCase()) {
      case 'easy':
        icon = Icons.keyboard_arrow_up;
        break;
      case 'medium':
        icon = Icons.keyboard_double_arrow_up;
        break;
      case 'hard':
        icon = Icons.keyboard_double_arrow_up;
        break;
      default:
        icon = Icons.help_outline;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          SizedBox(width: 4),
          Text(
            difficulty,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return _accentGreen;
      case 'medium':
        return _accentOrange;
      case 'hard':
        return _accentRed;
      default:
        return _textTertiary;
    }
  }
}

class InterviewQuestion {
  final String id;
  final String question;
  final String category;
  final String difficulty;
  final List<String> followUpQuestions;
  final String purpose;

  InterviewQuestion({
    required this.id,
    required this.question,
    required this.category,
    required this.difficulty,
    required this.followUpQuestions,
    required this.purpose,
  });
}
