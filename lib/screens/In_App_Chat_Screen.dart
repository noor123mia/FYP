// lib/screens/chat_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatScreen extends StatefulWidget {
  final String peerId;
  final String peerName; // we still accept it, but we'll refresh from DB

  const ChatScreen({
    Key? key,
    required this.peerId,
    required this.peerName,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _auth = FirebaseAuth.instance;
  final _textCtrl = TextEditingController();
  late final String _chatId;

  @override
  void initState() {
    super.initState();
    final myId = _auth.currentUser!.uid;
    _chatId = (myId.compareTo(widget.peerId) < 0)
        ? '${myId}_${widget.peerId}'
        : '${widget.peerId}_${myId}';
    _ensureChatDoc(); // also refreshes userA/userB names
  }

  // ---------- Name resolution helpers ----------
  Future<String> _nameFor(String uid) async {
    // 1) users/{uid}.name (preferred)
    try {
      final u =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final d = u.data();
      if (d != null) {
        final n = (d['name'] as String?)?.trim();
        if (n != null && n.isNotEmpty) return n;
        final e = (d['email'] as String?)?.trim();
        if (e != null && e.isNotEmpty) return e;
      }
    } catch (_) {}

    // 2) JobSeekersProfiles/{uid}.name (common for candidates)
    try {
      final p = await FirebaseFirestore.instance
          .collection('JobSeekersProfiles')
          .doc(uid)
          .get();
      final pd = p.data();
      final pn = (pd?['name'] as String?)?.trim();
      if (pn != null && pn.isNotEmpty) return pn;
    } catch (_) {}

    // 3) Auth displayName/email for current user
    final me = _auth.currentUser;
    if (me != null && me.uid == uid) {
      return me.displayName ?? me.email ?? 'User';
    }

    // 4) Generic fallback
    return 'User';
  }

  Future<void> _ensureChatDoc() async {
    final ref = FirebaseFirestore.instance.collection('chats').doc(_chatId);
    final myId = _auth.currentUser!.uid;

    // Resolve both names robustly (no emails shown if name exists)
    final meName = await _nameFor(myId);
    final peerName = await _nameFor(widget.peerId);

    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'participants': [myId, widget.peerId],
        'updatedAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'userA': {'id': myId, 'name': meName},
        'userB': {'id': widget.peerId, 'name': peerName},
      });
    } else {
      // Keep names fresh (merge) on every open
      await ref.set({
        'participants': FieldValue.arrayUnion([myId, widget.peerId]),
        'userA': {'id': myId, 'name': meName},
        'userB': {'id': widget.peerId, 'name': peerName},
      }, SetOptions(merge: true));
    }
  }

  // ---------- Send ----------
  Future<void> _sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final myId = _auth.currentUser!.uid;
    final msgRef = FirebaseFirestore.instance
        .collection('chats')
        .doc(_chatId)
        .collection('messages')
        .doc();

    await msgRef.set({
      'id': msgRef.id,
      'chatId': _chatId,
      'text': trimmed,
      'senderId': myId,
      'receiverId': widget.peerId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await FirebaseFirestore.instance.collection('chats').doc(_chatId).set({
      'lastMessage': trimmed,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    _textCtrl.clear();
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.peerName)),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(_chatId)
                  .collection('messages')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (_, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data!.docs;
                return ListView.builder(
                  reverse: true,
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    final isMe = data['senderId'] == _auth.currentUser!.uid;
                    return Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            vertical: 4, horizontal: 8),
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 14),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.blue[200] : Colors.grey[300],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text((data['text'] ?? '') as String),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Type a message',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(12),
                    ),
                    onSubmitted: _sendMessage,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () => _sendMessage(_textCtrl.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}