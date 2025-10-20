// lib/screens/chat_list_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_2/screens/In_App_Chat_Screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({Key? key}) : super(key: key);

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _auth = FirebaseAuth.instance;
  final _fs = FirebaseFirestore.instance;

  Stream<QuerySnapshot<Map<String, dynamic>>> _threads(String myUid) {
    return _fs
        .collection('chats')
        .where('participants', arrayContains: myUid)
        .orderBy('updatedAt', descending: true)
        .snapshots();
  }

  Future<String> _nameFor(String uid) async {
    try {
      final u = await _fs.collection('users').doc(uid).get();
      final d = u.data();
      final n = (d?['name'] as String?)?.trim();
      if (n != null && n.isNotEmpty) return n;
      final e = (d?['email'] as String?)?.trim();
      if (e != null && e.isNotEmpty) return e;
    } catch (_) {}

    try {
      final p = await _fs.collection('JobSeekersProfiles').doc(uid).get();
      final pd = p.data();
      final pn = (pd?['name'] as String?)?.trim();
      if (pn != null && pn.isNotEmpty) return pn;
    } catch (_) {}

    final me = _auth.currentUser;
    if (me != null && me.uid == uid) {
      return me.displayName ?? me.email ?? 'User';
    }
    return 'User';
  }

  @override
  Widget build(BuildContext context) {
    final me = _auth.currentUser;
    if (me == null) {
      return const Scaffold(body: Center(child: Text('Please sign in first')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Chats')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _threads(me.uid),
        builder: (_, snap) {
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('No chats yet'));

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 0),
            itemBuilder: (_, i) {
              final d = docs[i].data();

              // Prefer userA/userB (populated by ChatScreen)
              final a = Map<String, dynamic>.from(d['userA'] ?? {});
              final b = Map<String, dynamic>.from(d['userB'] ?? {});
              String peerId = '';
              String displayName = '';

              if (a.isNotEmpty && b.isNotEmpty) {
                final isAme = a['id'] == me.uid;
                final peer = isAme ? b : a;
                peerId = (peer['id'] ?? '') as String;
                displayName = (peer['name'] ?? '') as String;
              } else {
                // Fallback from participants array, then resolve name
                final List parts = (d['participants'] ?? []) as List;
                peerId = (parts.firstWhere((p) => p != me.uid,
                    orElse: () => '')) as String;
              }

              return FutureBuilder<String>(
                future: displayName.isNotEmpty
                    ? Future.value(displayName)
                    : _nameFor(peerId),
                builder: (_, nameSnap) {
                  final name = nameSnap.data ?? 'User';
                  final last = (d['lastMessage'] as String?) ?? '';
                  final updated = (d['updatedAt'] as Timestamp?)?.toDate();

                  return ListTile(
                    leading: CircleAvatar(
                        child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?')),
                    title: Text(name, overflow: TextOverflow.ellipsis),
                    subtitle: Text(last,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: updated == null
                        ? null
                        : Text(_hhmm(updated),
                            style: Theme.of(context).textTheme.labelSmall),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ChatScreen(peerId: peerId, peerName: name),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  String _hhmm(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    final ap = d.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $ap';
  }
}
