// lib/screens/InterviewManagementScreen.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
// import 'InterviewScheduleScreen.dart';

class InterviewManagementScreen extends StatefulWidget {
  const InterviewManagementScreen({Key? key}) : super(key: key);

  @override
  State<InterviewManagementScreen> createState() =>
      _InterviewManagementScreenState();
}

class _InterviewManagementScreenState extends State<InterviewManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _fs = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  bool _loading = true;
  String? _error;

  String? _recruiterId;
  String? _recruiterName = '';

  List<Map<String, String>> _accepted = [];
  List<Map<String, dynamic>> _scheduledInterviews = [];

  final _formKey = GlobalKey<FormState>();
  final _positionCtrl = TextEditingController();
  final _startTimeCtrl = TextEditingController(text: '10:00 AM');
  final _durationCtrl = TextEditingController(text: '45');
  final _meetingLinkCtrl = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  String? _selectedCandidateId;
  String? _selectedInterviewType;
  String? _selectedPlatform;
  String? _selectedJobId;
  String? _selectedJobTitle;
  bool _autoGenerateLink = true;
  bool _addToCalendar = true;

  final List<String> _interviewTypes = const [
    'Technical',
    'HR',
    'Cultural Fit',
    'System Design',
    'Coding Challenge',
  ];

  /// First item is our free fallback that can be truly auto-generated (Jitsi).
  final List<String> _platforms = const [
    'Smart Recruit Meet', // Jitsi (free) – shareable link without backend
    'Google Meet', // opens meet.google.com/new
    'Zoom', // opens app/web "start meeting"
    'Microsoft Teams', // opens app/web "start meeting"
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _positionCtrl.dispose();
    _startTimeCtrl.dispose();
    _durationCtrl.dispose();
    _meetingLinkCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _error = 'Not logged in.';
          _loading = false;
        });
        return;
      }

      _recruiterId = user.uid;

      // recruiter name
      String name = user.displayName ?? '';
      if (name.isEmpty) {
        final u = await _fs.collection('Users').doc(_recruiterId).get();
        final d = u.data();
        name = (d?['name'] ??
                d?['fullName'] ??
                d?['displayName'] ??
                user.email ??
                'Recruiter')
            .toString();
      }
      _recruiterName = name;

      await _loadAcceptedCandidates();
      await _loadScheduledInterviews();

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _error = 'Failed to load: $e';
        _loading = false;
      });
    }
  }

  Future<void> _loadAcceptedCandidates() async {
    final jobsSnap = await _fs
        .collection('JobsPosted')
        .where('recruiterId', isEqualTo: _recruiterId)
        .get();

    if (jobsSnap.docs.isEmpty) {
      setState(() => _accepted = []);
      return;
    }

    final jobIds = <String>[];
    final jobTitles = <String, String>{};
    for (final d in jobsSnap.docs) {
      jobIds.add(d.id);
      jobTitles[d.id] = (d.data()['title'] ?? 'Job').toString();
    }

    final List<Map<String, String>> temp = [];
    for (int i = 0; i < jobIds.length; i += 10) {
      final chunk =
          jobIds.sublist(i, (i + 10 > jobIds.length) ? jobIds.length : i + 10);
      final appsSnap = await _fs
          .collection('AppliedCandidates')
          .where('status', isEqualTo: 'accepted')
          .where('jobId', whereIn: chunk)
          .get();

      for (final app in appsSnap.docs) {
        final data = app.data();
        final candidateId = (data['candidateId'] ?? '').toString();
        final jobId = (data['jobId'] ?? '').toString();
        if (candidateId.isEmpty || jobId.isEmpty) continue;

        String candidateName =
            (data['name'] ?? data['applicantName'] ?? '').toString();

        if (candidateName.isEmpty) {
          final prof =
              await _fs.collection('JobSeekersProfiles').doc(candidateId).get();
          final p = prof.data();
          candidateName = (p?['name'] ??
                  p?['fullName'] ??
                  p?['displayName'] ??
                  'Unnamed Candidate')
              .toString();
        }

        temp.add({
          'applicationId': app.id,
          'candidateId': candidateId,
          'candidateName': candidateName,
          'jobId': jobId,
          'jobTitle': jobTitles[jobId] ?? 'Job',
        });
      }
    }

    temp.sort((a, b) =>
        (a['candidateName'] ?? '').compareTo(b['candidateName'] ?? ''));

    setState(() => _accepted = temp);
  }

  Future<void> _loadScheduledInterviews() async {
    try {
      final querySnapshot = await _fs
          .collection('ScheduledInterviews')
          .where('recruiterId', isEqualTo: _recruiterId)
          .orderBy('date')
          .orderBy('time')
          .get();

      final interviews = querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'candidateName': data['candidateName'] ?? 'Candidate',
          'position': data['position'] ?? 'Position',
          'interviewType': data['interviewType'] ?? 'Interview',
          'interviewer': data['interviewer'] ?? 'Interviewer',
          'date': data['date'] ?? '',
          'time': data['time'] ?? '',
          'duration': data['duration']?.toString() ?? '0',
          'platform': data['platform'] ?? 'Platform',
          'meetingLink': data['meetingLink'] ?? '',
          'status': data['status'] ?? 'Scheduled',
        };
      }).toList();

      setState(() => _scheduledInterviews = interviews);
    } catch (_) {}
  }

  // =========================
  //  MEETING LINK HELPERS
  // =========================

  // real auto-link only for Jitsi (no backend)
  String _generateJitsiLink({
    required String recruiterId,
    required String candidateId,
    required DateTime start,
  }) {
    final raw =
        '$recruiterId|$candidateId|${start.toUtc().millisecondsSinceEpoch}';
    final slug = base64UrlEncode(utf8.encode(raw))
        .replaceAll('=', '')
        .replaceAll('-', '')
        .replaceAll('_', '')
        .toLowerCase()
        .substring(0, 12);
    return 'https://meet.jit.si/smartrecruit-$slug';
  }

  /// Optional helper (not required by the new opener but kept for clarity)
  (String app, String web) _platformStartUrls(String platform) {
    switch (platform) {
      case 'Google Meet':
        return ('https://meet.google.com/new', 'https://meet.google.com/new');
      case 'Zoom':
        return ('zoomus://zoom.us/start', 'https://zoom.us/start/videomeeting');
      case 'Microsoft Teams':
        return (
          'msteams://teams.microsoft.com/l/meeting/new',
          'https://teams.live.com/start'
        );
      default:
        return ('', '');
    }
  }

  /// OPENER with Google Meet `intent://` fix + robust fallbacks
  Future<void> _openPlatformStart(String platform, String? savedLink) async {
    String _sanitizeMeetIntent(String url) {
      // Example: intent://meet.app.goo.gl/?link=https://meet.google.com/new&apn=...
      if (url.startsWith('intent://')) {
        final idx = url.indexOf('link=');
        if (idx != -1) {
          final enc = url.substring(idx + 5);
          final cut =
              enc.contains('&') ? enc.substring(0, enc.indexOf('&')) : enc;
          try {
            return Uri.decodeFull(cut);
          } catch (_) {
            return cut;
          }
        }
      }
      return url;
    }

    Future<bool> _tryLaunch(
      String url, {
      LaunchMode mode = LaunchMode.externalApplication,
    }) async {
      try {
        final uri = Uri.parse(url);
        return await launchUrl(uri, mode: mode);
      } catch (_) {
        return false;
      }
    }

    // 1) If we have a concrete link already (Jitsi or pasted), open it first
    String link = (savedLink ?? '').trim();
    if (link.startsWith('intent://')) {
      link = _sanitizeMeetIntent(link);
    }
    if (link.startsWith('http')) {
      if (await _tryLaunch(link)) return;
    }

    // 2) Resolve platform → we use multiple fallbacks for Google Meet
    (String app, List<String> webList) urls(String p) {
      switch (p) {
        case 'Google Meet':
          return (
            '',
            <String>[
              'https://meet.google.com/new?pli=1',
              'https://meet.google.com/?hs=197',
              'https://meet.google.com/'
            ]
          );
        case 'Zoom':
          return (
            'zoomus://zoom.us/start',
            <String>['https://zoom.us/start/videomeeting']
          );
        case 'Microsoft Teams':
          return (
            'msteams://teams.microsoft.com/l/meeting/new',
            <String>['https://teams.live.com/start']
          );
        default:
          return ('', <String>[]);
      }
    }

    final (app, webList) = urls(platform);

    // 3) Google Meet → external browser/app first; then in-app as last resort
    if (platform == 'Google Meet') {
      for (final u in webList) {
        if (await _tryLaunch(u, mode: LaunchMode.externalApplication)) return;
      }
      for (final u in webList) {
        if (await _tryLaunch(u, mode: LaunchMode.inAppWebView)) return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot open Google Meet')),
        );
      }
      return;
    }

    // 4) Others: app deep-link → web fallback
    if (app.isNotEmpty) {
      if (await _tryLaunch(app)) return;
    }
    for (final u in webList) {
      if (await _tryLaunch(u)) return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot open $platform')),
      );
    }
  }

  // =========================
  //     SCHEDULE INTERVIEW
  // =========================
  Future<void> _scheduleInterview() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      setState(() => _loading = true);

      final selectedCandidate = _accepted.firstWhere(
        (e) => e['candidateId'] == _selectedCandidateId,
        orElse: () => {},
      );

      // Decide what to save in meetingLink
      String link = _meetingLinkCtrl.text.trim();
      final chosenPlatform = _selectedPlatform ?? 'Smart Recruit Meet';

      if (_autoGenerateLink) {
        if (chosenPlatform == 'Smart Recruit Meet') {
          // Truly auto-generated, shareable link (Jitsi)
          link = _generateJitsiLink(
            recruiterId: _recruiterId ?? 'rec',
            candidateId: _selectedCandidateId ?? 'cand',
            start: _selectedDate,
          );
        } else {
          // For Meet/Zoom/Teams we save their start page so "Join Now" opens it.
          final (_, web) = _platformStartUrls(chosenPlatform);
          link = web;
        }
      }

      await _fs.collection('ScheduledInterviews').add({
        'candidateId': _selectedCandidateId,
        'candidateName': selectedCandidate['candidateName'] ?? 'Candidate',
        'jobId': _selectedJobId,
        'position': _selectedJobTitle,
        'interviewType': _selectedInterviewType,
        'interviewer': _recruiterName,
        'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
        'time': _startTimeCtrl.text,
        'duration': int.tryParse(_durationCtrl.text) ?? 45,
        'platform': chosenPlatform,
        'meetingLink': link, // Jitsi real link OR platform "start" url
        'autoGenerated': _autoGenerateLink,
        'status': 'Scheduled',
        'recruiterId': _recruiterId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (selectedCandidate['applicationId'] != null) {
        await _fs
            .collection('AppliedCandidates')
            .doc(selectedCandidate['applicationId']!)
            .update({'status': 'interview_scheduled'});
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Interview scheduled'),
            backgroundColor: Colors.green,
          ),
        );
      }

      await _loadAcceptedCandidates();
      await _loadScheduledInterviews();
      _tabController.animateTo(1);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to schedule: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _refreshData() async {
    setState(() => _loading = true);
    await _loadData();
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Interview Management'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Schedule Interview'),
            Tab(text: 'Scheduled Interviews'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_error != null)
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _refreshData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildScheduleInterviewTab(context),
                    _buildScheduledInterviewsTab(),
                  ],
                ),
    );
  }

  Widget _buildScheduleInterviewTab(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            // ---------- Candidate ----------
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _BlockTitle('Candidate Information'),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Candidate',
                        prefixIcon: Icon(Icons.person, color: Colors.blue[800]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      value: _selectedCandidateId,
                      items: _accepted.map((c) {
                        final label = '${c['candidateName']}';
                        return DropdownMenuItem(
                          value: c['candidateId'],
                          child: Text(label, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Select a candidate'
                          : null,
                      onChanged: (val) {
                        setState(() {
                          _selectedCandidateId = val;
                          final match = _accepted.firstWhere(
                            (e) => e['candidateId'] == val,
                            orElse: () => {},
                          );
                          _selectedJobId = match['jobId'];
                          _selectedJobTitle = match['jobTitle'];
                          _positionCtrl.text = _selectedJobTitle ?? '';
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _positionCtrl,
                      decoration: InputDecoration(
                        labelText: 'Position',
                        prefixIcon: Icon(Icons.work, color: Colors.blue[800]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      readOnly: true,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ---------- Interview details ----------
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _BlockTitle('Interview Details'),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Interview Type',
                        prefixIcon:
                            Icon(Icons.category, color: Colors.blue[800]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      value: _selectedInterviewType,
                      items: _interviewTypes
                          .map(
                              (t) => DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Select type' : null,
                      onChanged: (v) =>
                          setState(() => _selectedInterviewType = v),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Interviewer',
                        prefixIcon: Icon(Icons.people, color: Colors.blue[800]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      controller:
                          TextEditingController(text: _recruiterName ?? ''),
                      readOnly: true,
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 120)),
                        );
                        if (picked != null)
                          setState(() => _selectedDate = picked);
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Interview Date',
                          prefixIcon: Icon(Icons.calendar_today,
                              color: Colors.blue[800]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        child: Text(DateFormat('EEEE, MMM d, yyyy')
                            .format(_selectedDate)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _startTimeCtrl,
                            decoration: InputDecoration(
                              labelText: 'Start Time',
                              prefixIcon: Icon(Icons.access_time,
                                  color: Colors.blue[800]),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            validator: (v) =>
                                (v == null || v.isEmpty) ? 'Enter time' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _durationCtrl,
                            decoration: InputDecoration(
                              labelText: 'Duration (min)',
                              prefixIcon:
                                  Icon(Icons.timer, color: Colors.blue[800]),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            validator: (v) => (v == null || v.isEmpty)
                                ? 'Enter minutes'
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ---------- Meeting platform ----------
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _BlockTitle('Meeting Platform'),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Platform',
                        prefixIcon:
                            Icon(Icons.video_call, color: Colors.blue[800]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      value: _selectedPlatform,
                      items: _platforms
                          .map(
                              (p) => DropdownMenuItem(value: p, child: Text(p)))
                          .toList(),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Select platform' : null,
                      onChanged: (v) => setState(() => _selectedPlatform = v),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _meetingLinkCtrl,
                      decoration: InputDecoration(
                        labelText: 'Meeting Link (optional)',
                        helperText: 'Leave empty or enable Auto-generate',
                        prefixIcon: Icon(Icons.link, color: Colors.blue[800]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Auto-generate meeting link'),
                      value: _autoGenerateLink,
                      onChanged: (v) => setState(() => _autoGenerateLink = v),
                      activeColor: Colors.blue[800],
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Add to calendar'),
                      value: _addToCalendar,
                      onChanged: (v) => setState(() => _addToCalendar = v),
                      activeColor: Colors.blue[800],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            _accepted.isEmpty ? null : _scheduleInterview,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[800],
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Schedule Interview',
                            style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (_accepted.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: _InfoChip(
                  icon: Icons.info_outline,
                  text:
                      'No accepted candidates found for your jobs. Update status to Accepted first.',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduledInterviewsTab() {
    if (_scheduledInterviews.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('No interviews scheduled yet',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600])),
            const SizedBox(height: 8),
            Text('Schedule an interview to see it here',
                style: TextStyle(fontSize: 14, color: Colors.grey[500])),
            const SizedBox(height: 16),
            ElevatedButton(
                onPressed: _loadScheduledInterviews,
                child: const Text('Refresh')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadScheduledInterviews,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _scheduledInterviews.length,
        itemBuilder: (context, index) {
          final interview = _scheduledInterviews[index];
          return _buildInterviewCard(interview);
        },
      ),
    );
  }

  Widget _buildInterviewCard(Map<String, dynamic> interview) {
    final status = (interview['status'] ?? 'Scheduled').toString();
    final meetingLink = (interview['meetingLink'] ?? '').toString();

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.blue[50], shape: BoxShape.circle),
                  child:
                      Icon(Icons.videocam, color: Colors.blue[800], size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(interview['candidateName'] ?? 'Candidate',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(
                        '${interview['position']} • ${interview['interviewType']} Interview',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: status == 'Scheduled'
                        ? Colors.blue[50]
                        : Colors.green[50],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: status == 'Scheduled'
                          ? Colors.blue[800]
                          : Colors.green[800],
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.send),
                    label: const Text('Send Invite'),
                    onPressed: status == 'Scheduled'
                        ? () => _sendInvite(interview)
                        : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue[800],
                      side: BorderSide(color: Colors.blue[800]!),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.video_call),
                    label: const Text('Join Meeting'),
                    onPressed: meetingLink.isNotEmpty
                        ? () => _openPlatformStart(
                              interview['platform'] ?? 'Smart Recruit Meet',
                              interview['meetingLink'] ?? '',
                            )
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[800],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendInvite(Map<String, dynamic> interview) async {
    final interviewId = interview['id'] as String?;
    final candidateId = (interview['candidateId'] ?? '').toString();
    if (interviewId == null || candidateId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing candidateId or interviewId.')),
      );
      return;
    }
    try {
      // Merge all interview details and mark invited
      final updateData = Map<String, dynamic>.from(interview);
      updateData['status'] = 'Invited';
      updateData['sentToCandidateAt'] = FieldValue.serverTimestamp();
      updateData['updatedAt'] = FieldValue.serverTimestamp();
      await _fs
          .collection('ScheduledInterviews')
          .doc(interviewId)
          .set(updateData, SetOptions(merge: true));

      // Optionally send a chat summary (if you want same as InterviewScheduleScreen)
      // await _sendChatSummaryToCandidate(candidateId, updateData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invite sent to candidate.')),
      );
      await _loadScheduledInterviews();
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send invite: $e')),
      );
    }
  }
}

// ---------- little helpers ----------
class _BlockTitle extends StatelessWidget {
  final String text;
  const _BlockTitle(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
          fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue[800]),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoChip({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.orange),
        const SizedBox(width: 8),
        Expanded(
            child: Text(text, style: const TextStyle(color: Colors.orange))),
      ],
    );
  }
}
