// lib/screens/InterviewScheduleScreen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class InterviewScheduleScreen extends StatefulWidget {
  const InterviewScheduleScreen({Key? key}) : super(key: key);

  @override
  State<InterviewScheduleScreen> createState() =>
      _InterviewScheduleScreenState();
}

class _InterviewScheduleScreenState extends State<InterviewScheduleScreen> {
  final _fs = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  User? get _me => _auth.currentUser;

  bool _loading = true;
  String? _error;
  bool _isRecruiter = false; // auto-detected
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (_me == null) {
      setState(() {
        _loading = false;
        _error = 'User not logged in';
      });
      return;
    }
    try {
      // Detect role (reads /users/{uid}.userType)
      final userDoc = await _fs.collection('users').doc(_me!.uid).get();
      final userType = (userDoc.data()?['userType'] as String?)?.toLowerCase();
      _isRecruiter = userType == 'recruiter';

      await _load();
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Failed to load role: $e';
      });
    }
  }

  Future<void> _load() async {
    if (_me == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      Query query = _fs.collection('ScheduledInterviews');

      if (_isRecruiter) {
        query = query.where('recruiterId', isEqualTo: _me!.uid);
      } else {
        query = query.where('candidateId', isEqualTo: _me!.uid);
      }

      // Try to get data without ordering first (as fallback)
      QuerySnapshot snap;
      try {
        // First attempt: with ordering (if index exists)
        query = query.orderBy('date').orderBy('time');
        snap = await query.get();
      } catch (e) {
        // Fallback: without ordering if index doesn't exist
        if (_isRecruiter) {
          query = _fs
              .collection('ScheduledInterviews')
              .where('recruiterId', isEqualTo: _me!.uid);
        } else {
          query = _fs
              .collection('ScheduledInterviews')
              .where('candidateId', isEqualTo: _me!.uid);
        }
        snap = await query.get();
      }

      final list = snap.docs.map((d) {
        final m = d.data() as Map<String, dynamic>;
        return {
          'id': d.id,
          'recruiterId': m['recruiterId'] ?? '',
          'recruiterName': m['recruiterName'] ?? 'Recruiter',
          'candidateId': m['candidateId'] ?? '',
          'candidateName': m['candidateName'] ?? 'Candidate',
          'position': m['position'] ?? 'Position',
          'interviewType': m['interviewType'] ?? 'Interview',
          'interviewer': m['interviewer'] ?? 'Interviewer',
          'date': m['date'], // allow String or Timestamp
          'time': m['time'] ?? '',
          'duration': (m['duration']?.toString() ?? '0'),
          'platform': m['platform'] ?? 'Platform',
          'meetingLink': m['meetingLink'] ?? '',
          'status': m['status'] ?? 'Scheduled',
          'sentToCandidateAt': m['sentToCandidateAt'],
          'updatedAt': m['updatedAt'],
        };
      }).toList();

      // Client-side safe sort (by date then time) regardless of data types
      list.sort((a, b) {
        final da = _parseDate(a['date']);
        final db = _parseDate(b['date']);
        final dateCompare = da.compareTo(db);
        if (dateCompare != 0) return dateCompare;

        // If same date, sort by time
        final timeA = (a['time'] ?? '').toString();
        final timeB = (b['time'] ?? '').toString();
        return timeA.compareTo(timeB);
      });

      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Failed to load interviews: $e';
      });
    }
  }

  // ---- Actions ----

  Future<void> _sendInvite(Map<String, dynamic> it) async {
    // Only recruiters can invite
    if (!_isRecruiter) return;

    final interviewId = it['id'] as String;
    final candidateId = (it['candidateId'] ?? '').toString();
    if (candidateId.isEmpty) {
      _toast('Missing candidateId on this interview.');
      return;
    }

    try {
      // Merge all interview details and mark invited
      final updateData = Map<String, dynamic>.from(it);
      updateData['status'] = 'Invited';
      updateData['sentToCandidateAt'] = FieldValue.serverTimestamp();
      updateData['updatedAt'] = FieldValue.serverTimestamp();
      await _fs
          .collection('ScheduledInterviews')
          .doc(interviewId)
          .set(updateData, SetOptions(merge: true));

      // Send a chat summary to candidate so they see details instantly
      await _sendChatSummary(
        peerId: candidateId,
        title: 'Interview Invite',
        it: updateData,
      );

      _toast('Invite sent to candidate.');
      await _load();
    } catch (e) {
      _toast('Failed to send invite: $e');
    }
  }

  Future<void> _join(Map<String, dynamic> it) async {
    final link = (it['meetingLink'] ?? '').toString().trim();

    if (link.isEmpty) {
      _toast('No meeting link available.');
      return;
    }

    String formattedLink = link;
    if (!formattedLink.startsWith('http://') &&
        !formattedLink.startsWith('https://')) {
      formattedLink = 'https://$formattedLink';
    }

    try {
      final uri = Uri.parse(formattedLink);

      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        _toast('Opening meeting...');
      } else {
        _toast('Cannot open meeting link. Please check the link.');
      }
    } catch (e) {
      _toast('Failed to open meeting: $e');
    }
  }

  // ---- Chat integration (uses your chats schema) ----

  Future<void> _sendChatSummary({
    required String peerId,
    required String title,
    required Map<String, dynamic> it,
  }) async {
    final myId = _me!.uid;
    final chatId =
        (myId.compareTo(peerId) < 0) ? '${myId}_$peerId' : '${peerId}_$myId';

    // Who am I (name)? Who is peer (name)?
    final myName = await _getUserName(myId);
    final peerName = await _getUserName(peerId);

    // Ensure chat exists (and keep names fresh)
    final chatRef = _fs.collection('chats').doc(chatId);
    await chatRef.set({
      'participants': FieldValue.arrayUnion([myId, peerId]),
      'userA': {'id': myId, 'name': myName},
      'userB': {'id': peerId, 'name': peerName},
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Compose message text
    final text = _formatInviteMessage(title, it);

    // Write message
    final msgRef = chatRef.collection('messages').doc();
    await msgRef.set({
      'id': msgRef.id,
      'chatId': chatId,
      'text': text,
      'senderId': myId,
      'receiverId': peerId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Update summary
    await chatRef.set({
      'lastMessage': text,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<String> _getUserName(String uid) async {
    try {
      final d = await _fs.collection('users').doc(uid).get();
      final n = (d.data()?['name'] as String?) ?? '';
      if (n.isNotEmpty) return n;
    } catch (_) {}
    // fallback to auth displayName or email
    if (_me != null && _me!.uid == uid) {
      return _me!.displayName ?? _me!.email ?? 'User';
    }
    // peer fallback
    return 'User';
  }

  String _formatInviteMessage(String title, Map<String, dynamic> it) {
    final dateStr = _prettyDate(it['date']);
    final timeStr = (it['time'] ?? '').toString();
    final dur = (it['duration'] ?? '').toString();
    final pos = (it['position'] ?? '').toString();
    final interviewer = (it['interviewer'] ?? '').toString();
    final platform = (it['platform'] ?? '').toString();
    final meeting = (it['meetingLink'] ?? '').toString();

    final b = StringBuffer()
      ..writeln('📩 $title')
      ..writeln('• Position: $pos')
      ..writeln('• Type: ${it['interviewType'] ?? ''}')
      ..writeln('• Interviewer: $interviewer')
      ..writeln('• Date: $dateStr')
      ..writeln('• Time: $timeStr (${dur}m)')
      ..writeln('• Platform: $platform');
    if (meeting.isNotEmpty) b.writeln('• Link: $meeting');
    return b.toString();
  }

  // ---- Helpers & UI ----

  DateTime _parseDate(dynamic v) {
    if (v == null) return DateTime.fromMillisecondsSinceEpoch(0);
    if (v is Timestamp) return v.toDate();
    if (v is String) {
      try {
        return DateTime.parse(v);
      } catch (_) {}
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _prettyDate(dynamic v) {
    final dt = _parseDate(v);
    return DateFormat('EEE, MMM d, yyyy').format(dt);
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _refresh() => _load();

  @override
  Widget build(BuildContext context) {
    final title = _isRecruiter ? 'Scheduled Interviews' : 'My Interviews';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
        ],
      ),
      backgroundColor: const Color(0xFFF3F4F6),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(_error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red)),
                  ),
                )
              : _items.isEmpty
                  ? _EmptyState(isRecruiter: _isRecruiter)
                  : RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _items.length,
                        itemBuilder: (_, i) => _InterviewCard(
                          data: _items[i],
                          isRecruiter: _isRecruiter,
                          onInvite: _sendInvite,
                          onJoin: _join,
                        ),
                      ),
                    ),
    );
  }
}

class _InterviewCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isRecruiter;
  final Future<void> Function(Map<String, dynamic>) onInvite;
  final Future<void> Function(Map<String, dynamic>) onJoin;

  const _InterviewCard({
    Key? key,
    required this.data,
    required this.isRecruiter,
    required this.onInvite,
    required this.onJoin,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final status = (data['status'] ?? 'Scheduled').toString();
    final statusColor = _statusColor(status);
    final meetingLink = (data['meetingLink'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(.25), width: 1.3),
        boxShadow: [
          BoxShadow(
              color: Colors.black12, blurRadius: 8, offset: const Offset(0, 3))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: name + status chip
            Row(
              children: [
                Expanded(
                  child: Text(
                    isRecruiter
                        ? (data['candidateName'] ?? 'Candidate')
                        : (data['recruiterName'] ?? 'Recruiter'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(.25)),
                  ),
                  child: Text(status,
                      style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Detail rows
            _InfoRow(
                icon: Icons.work_outline,
                label: 'Position',
                value: data['position'] ?? ''),
            _InfoRow(
                icon: Icons.forum_outlined,
                label: 'Type',
                value: data['interviewType'] ?? ''),
            _InfoRow(
                icon: Icons.person_outline,
                label: 'Interviewer',
                value: data['interviewer'] ?? ''),
            _InfoRow(
                icon: Icons.event_outlined,
                label: 'Date',
                value: _prettyDate(data['date'])),
            _InfoRow(
                icon: Icons.schedule_outlined,
                label: 'Time',
                value: '${data['time'] ?? ''} (${data['duration'] ?? ''}m)'),
            _InfoRow(
                icon: Icons.video_call_outlined,
                label: 'Platform',
                value: data['platform'] ?? ''),
            if (meetingLink.isNotEmpty)
              InkWell(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Opening: $meetingLink')));
                },
                child: _InfoRow(
                    icon: Icons.link,
                    label: 'Meeting',
                    value: meetingLink,
                    isLink: true),
              ),

            const SizedBox(height: 12),

            // Actions - UPDATED: Both recruiter and candidate can join interviews
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isRecruiter) ...[
                  // Recruiter can send invite AND join interview
                  TextButton.icon(
                    onPressed: () => onInvite(data),
                    icon: const Icon(Icons.send),
                    label: const Text('Send Invite'),
                  ),
                  const SizedBox(width: 8),
                  if (meetingLink.isNotEmpty &&
                      (status.toLowerCase() == 'scheduled' ||
                          status.toLowerCase() == 'invited' ||
                          status.toLowerCase() == 'confirmed'))
                    ElevatedButton.icon(
                      onPressed: () => onJoin(data),
                      icon: const Icon(Icons.video_call),
                      label: const Text('Join Interview'),
                    ),
                ] else ...[
                  // Candidate can only join if scheduled/invited
                  if (meetingLink.isNotEmpty &&
                      (status.toLowerCase() == 'scheduled' ||
                          status.toLowerCase() == 'invited' ||
                          status.toLowerCase() == 'confirmed'))
                    ElevatedButton.icon(
                      onPressed: () => onJoin(data),
                      icon: const Icon(Icons.video_call),
                      label: const Text('Join Interview'),
                    ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'scheduled':
        return Colors.blue;
      case 'invited':
        return Colors.indigo;
      case 'confirmed':
        return Colors.green;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'rescheduled':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  static String _prettyDate(dynamic v) {
    DateTime dt;
    if (v is Timestamp)
      dt = v.toDate();
    else if (v is String) {
      try {
        dt = DateTime.parse(v);
      } catch (_) {
        return v;
      }
    } else {
      return '';
    }
    return DateFormat('EEE, MMM d, yyyy').format(dt);
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isLink;
  const _InfoRow(
      {Key? key,
      required this.icon,
      required this.label,
      required this.value,
      this.isLink = false})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.black54),
          const SizedBox(width: 8),
          Text('$label: ', style: style?.copyWith(fontWeight: FontWeight.w600)),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: style?.copyWith(
                color: isLink ? Colors.indigo : Colors.black87,
                decoration:
                    isLink ? TextDecoration.underline : TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isRecruiter;
  const _EmptyState({Key? key, required this.isRecruiter}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final title =
        isRecruiter ? 'No interviews yet' : 'No interviews assigned to you';
    final sub = isRecruiter
        ? 'Create and invite candidates to appear here.'
        : 'When a recruiter invites you, it will show here.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey)),
            const SizedBox(height: 8),
            Text(sub,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
